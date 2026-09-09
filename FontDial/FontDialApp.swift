import SwiftUI

private let sharedSettingsManager = SettingsManager()

@main
struct FontDialApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var settingsManager = sharedSettingsManager

    var body: some Scene {
        Settings {
            SettingsView(settingsManager: settingsManager)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private enum DefaultsKey {
        static let showInMenuBar = "FontDial.showInMenuBar"
        static let showInDock = "FontDial.showInDock"
    }

    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private var settingsWindow: NSWindow?
    private let settingsManager = sharedSettingsManager
    private var defaultsObserver: NSObjectProtocol?
    private var visibilityObserver: NSKeyValueObservation?

    // Last settled shell state. The mutual-exclusion guard uses it to tell which
    // switch the user just flipped, so it can turn the other one on instead of
    // reverting the change they just made.
    private var lastShowInMenuBar = true
    private var lastShowInDock = false
    private var hasAppliedShellPreferences = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        ProcessInfo.processInfo.disableAutomaticTermination("FontDial keeps a menu bar status item active")

        UserDefaults.standard.register(defaults: [
            DefaultsKey.showInMenuBar: true,
            DefaultsKey.showInDock: false
        ])

        lastShowInMenuBar = UserDefaults.standard.bool(forKey: DefaultsKey.showInMenuBar)
        lastShowInDock = UserDefaults.standard.bool(forKey: DefaultsKey.showInDock)

        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyShellPreferences()
        }

        applyShellPreferences()
        settingsManager.load()
    }

    deinit {
        if let defaultsObserver {
            NotificationCenter.default.removeObserver(defaultsObserver)
        }
        visibilityObserver?.invalidate()
    }

    private func applyShellPreferences() {
        let defaults = UserDefaults.standard
        var showInMenuBar = defaults.bool(forKey: DefaultsKey.showInMenuBar)
        var showInDock = defaults.bool(forKey: DefaultsKey.showInDock)

        // didChangeNotification fires synchronously inside every defaults write,
        // including our own below. Ignore anything that leaves the shell unchanged
        // so the writes here settle instead of ping-ponging.
        guard !hasAppliedShellPreferences
            || showInMenuBar != lastShowInMenuBar
            || showInDock != lastShowInDock else { return }

        // The app has to stay reachable somewhere. Whichever switch was just turned
        // off, turn the other one on. Never undo the change the user just made.
        if !showInMenuBar && !showInDock {
            if lastShowInMenuBar {
                showInDock = true
                defaults.set(true, forKey: DefaultsKey.showInDock)
            } else {
                showInMenuBar = true
                defaults.set(true, forKey: DefaultsKey.showInMenuBar)
            }
        }

        lastShowInMenuBar = showInMenuBar
        lastShowInDock = showInDock
        hasAppliedShellPreferences = true

        NSApp.setActivationPolicy(showInDock ? .regular : .accessory)

        if showInMenuBar {
            installStatusItemIfNeeded()
        } else {
            removeStatusItem()
        }
    }

    private func installStatusItemIfNeeded() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = "FontDial"
        item.isVisible = true

        if let button = item.button {
            if let image = NSImage(systemSymbolName: "textformat.size", accessibilityDescription: "FontDial") {
                image.isTemplate = true
                button.image = image
                button.imagePosition = .imageOnly
            } else {
                button.title = "Aa"
                button.font = .menuBarFont(ofSize: 13)
            }
            button.toolTip = "FontDial"
            button.isEnabled = true
            button.target = self
            button.action = #selector(togglePopover(_:))
            button.sendAction(on: [.leftMouseUp])
        }

        let hostingView = NSHostingController(rootView: PopoverView(settingsManager: settingsManager))
        popover.contentViewController = hostingView
        popover.behavior = .transient
        popover.animates = false

        statusItem = item

        // Command-dragging the icon out of the menu bar flips isVisible behind our
        // back. Mirror that into the preference so the switch matches reality and
        // the app falls back to the Dock rather than becoming unreachable.
        visibilityObserver = item.observe(\.isVisible, options: [.new]) { _, change in
            guard change.newValue == false else { return }
            UserDefaults.standard.set(false, forKey: DefaultsKey.showInMenuBar)
        }
    }

    private func removeStatusItem() {
        visibilityObserver?.invalidate()
        visibilityObserver = nil
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(nil)
            return
        }

        popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    @objc private func openSettings() {
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView(settingsManager: settingsManager)
        let hostingController = NSHostingController(rootView: settingsView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Settings"
        window.styleMask = [.titled, .closable]
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.settingsWindow = window
    }

    // When clicking the Dock icon, show settings
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            openSettings()
        }
        return true
    }
}
