import Foundation

/// A state-aware JSONC processor that handles comments, trailing commas,
/// and string context correctly. Never corrupts URLs or quoted content.
enum JSONCScanner {

    // MARK: - Strip Mode

    /// Strips JSONC extensions (// comments, /* */ block comments, trailing commas)
    /// to produce valid JSON suitable for JSONSerialization.
    /// Tracks string context so `"https://example.com"` is preserved.
    static func strip(_ text: String) -> String {
        var result: [Character] = []
        let chars = Array(text)
        let count = chars.count
        var i = 0
        var inString = false

        while i < count {
            let c = chars[i]

            // Handle string context
            if inString {
                result.append(c)
                if c == "\\" {
                    // Skip escaped character
                    i += 1
                    if i < count {
                        result.append(chars[i])
                    }
                } else if c == "\"" {
                    inString = false
                }
                i += 1
                continue
            }

            // Not in string
            if c == "\"" {
                inString = true
                result.append(c)
                i += 1
                continue
            }

            // Line comment
            if c == "/" && i + 1 < count && chars[i + 1] == "/" {
                // Skip until end of line
                i += 2
                while i < count && chars[i] != "\n" {
                    i += 1
                }
                continue
            }

            // Block comment
            if c == "/" && i + 1 < count && chars[i + 1] == "*" {
                i += 2
                while i + 1 < count {
                    if chars[i] == "*" && chars[i + 1] == "/" {
                        i += 2
                        break
                    }
                    i += 1
                }
                continue
            }

            result.append(c)
            i += 1
        }

        // Remove trailing commas before } or ]
        var cleaned = String(result)
        // Match comma followed by optional whitespace/newlines then } or ]
        if let regex = try? NSRegularExpression(pattern: ",\\s*([\\]\\}])", options: []) {
            cleaned = regex.stringByReplacingMatches(
                in: cleaned,
                range: NSRange(cleaned.startIndex..., in: cleaned),
                withTemplate: "$1"
            )
        }

        return cleaned
    }

    // MARK: - Find Value Range

    /// Finds the character range of a top-level key's value in raw JSONC text.
    /// Only matches keys at nesting depth 1 (inside the root object).
    /// Returns the range of the value (e.g., the "13" in `"editor.fontSize": 13`).
    static func findValueRange(forKey key: String, in text: String) -> Range<String.Index>? {
        let chars = Array(text.unicodeScalars)
        let count = chars.count
        var i = 0
        var depth = 0
        var inString = false
        var stringStart = -1

        while i < count {
            let c = chars[i]

            // Handle string context
            if inString {
                if c == "\\" {
                    i += 2
                    continue
                }
                if c == "\"" {
                    inString = false
                    // Check if this string at depth 1 is our target key
                    if depth == 1 {
                        let start = text.unicodeScalars.index(text.unicodeScalars.startIndex, offsetBy: stringStart + 1)
                        let end = text.unicodeScalars.index(text.unicodeScalars.startIndex, offsetBy: i)
                        let keyStr = String(text.unicodeScalars[start..<end])

                        if keyStr == key {
                            // Found the key — now find the colon and the value after it
                            var j = i + 1
                            // Skip whitespace and colon
                            while j < count && (chars[j] == " " || chars[j] == "\t" || chars[j] == "\n" || chars[j] == "\r") {
                                j += 1
                            }
                            if j < count && chars[j] == ":" {
                                j += 1
                                // Skip whitespace after colon
                                while j < count && (chars[j] == " " || chars[j] == "\t" || chars[j] == "\n" || chars[j] == "\r") {
                                    j += 1
                                }
                                // Skip any inline comments after colon
                                if j + 1 < count && chars[j] == "/" && chars[j + 1] == "/" {
                                    while j < count && chars[j] != "\n" { j += 1 }
                                    while j < count && (chars[j] == " " || chars[j] == "\t" || chars[j] == "\n" || chars[j] == "\r") { j += 1 }
                                }
                                if j + 1 < count && chars[j] == "/" && chars[j + 1] == "*" {
                                    j += 2
                                    while j + 1 < count && !(chars[j] == "*" && chars[j + 1] == "/") { j += 1 }
                                    j += 2
                                    while j < count && (chars[j] == " " || chars[j] == "\t" || chars[j] == "\n" || chars[j] == "\r") { j += 1 }
                                }

                                // Now at the start of the value — find its end
                                let valueStart = text.unicodeScalars.index(text.unicodeScalars.startIndex, offsetBy: j)
                                let valueEnd = findValueEnd(in: chars, from: j)
                                let valueEndIdx = text.unicodeScalars.index(text.unicodeScalars.startIndex, offsetBy: valueEnd)

                                // Convert UnicodeScalar indices to String indices
                                let strStart = String.Index(valueStart, within: text) ?? text.startIndex
                                let strEnd = String.Index(valueEndIdx, within: text) ?? text.endIndex
                                return strStart..<strEnd
                            }
                        }
                    }
                }
                i += 1
                continue
            }

            // Not in string
            if c == "\"" {
                inString = true
                stringStart = i
                i += 1
                continue
            }

            // Line comment
            if c == "/" && i + 1 < count && chars[i + 1] == "/" {
                i += 2
                while i < count && chars[i] != "\n" { i += 1 }
                continue
            }

            // Block comment
            if c == "/" && i + 1 < count && chars[i + 1] == "*" {
                i += 2
                while i + 1 < count && !(chars[i] == "*" && chars[i + 1] == "/") { i += 1 }
                i += 2
                continue
            }

            if c == "{" || c == "[" {
                depth += 1
            } else if c == "}" || c == "]" {
                depth -= 1
            }

            i += 1
        }

        return nil
    }

    // MARK: - Insertion Point

    /// Finds the position just before the top-level closing `}` for inserting new keys.
    /// Returns the index of the `}` character.
    static func insertionPoint(in text: String) -> String.Index? {
        let chars = Array(text.unicodeScalars)
        let count = chars.count
        var i = 0
        var depth = 0
        var inString = false
        var lastTopLevelClose: Int?

        while i < count {
            let c = chars[i]

            if inString {
                if c == "\\" {
                    i += 2
                    continue
                }
                if c == "\"" { inString = false }
                i += 1
                continue
            }

            if c == "\"" {
                inString = true
                i += 1
                continue
            }

            if c == "/" && i + 1 < count && chars[i + 1] == "/" {
                i += 2
                while i < count && chars[i] != "\n" { i += 1 }
                continue
            }

            if c == "/" && i + 1 < count && chars[i + 1] == "*" {
                i += 2
                while i + 1 < count && !(chars[i] == "*" && chars[i + 1] == "/") { i += 1 }
                i += 2
                continue
            }

            if c == "{" || c == "[" {
                depth += 1
            } else if c == "}" || c == "]" {
                depth -= 1
                if depth == 0 && c == "}" {
                    lastTopLevelClose = i
                }
            }

            i += 1
        }

        guard let pos = lastTopLevelClose else { return nil }
        let idx = text.unicodeScalars.index(text.unicodeScalars.startIndex, offsetBy: pos)
        return String.Index(idx, within: text) ?? nil
    }

    // MARK: - Helpers

    /// Finds the end of a JSON value starting at position `from`.
    /// Handles numbers, strings, booleans, null, objects, and arrays.
    private static func findValueEnd(in chars: [Unicode.Scalar], from start: Int) -> Int {
        let count = chars.count
        guard start < count else { return start }

        let c = chars[start]

        // String value
        if c == "\"" {
            var i = start + 1
            while i < count {
                if chars[i] == "\\" {
                    i += 2
                    continue
                }
                if chars[i] == "\"" {
                    return i + 1
                }
                i += 1
            }
            return count
        }

        // Object or array
        if c == "{" || c == "[" {
            let close: Unicode.Scalar = c == "{" ? "}" : "]"
            var depth = 1
            var i = start + 1
            var inStr = false
            while i < count && depth > 0 {
                if inStr {
                    if chars[i] == "\\" { i += 2; continue }
                    if chars[i] == "\"" { inStr = false }
                } else {
                    if chars[i] == "\"" { inStr = true }
                    else if chars[i] == c { depth += 1 }
                    else if chars[i] == close { depth -= 1 }
                }
                i += 1
            }
            return i
        }

        // Number, boolean, null — scan until delimiter
        var i = start
        while i < count {
            let ch = chars[i]
            if ch == "," || ch == "}" || ch == "]" || ch == "\n" || ch == "\r" || ch == " " || ch == "\t" || ch == "/" {
                break
            }
            i += 1
        }
        return i
    }
}
