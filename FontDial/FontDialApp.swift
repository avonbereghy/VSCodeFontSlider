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

    func applicationDidFinishLaunching(_ notification: Notification) {
        ProcessInfo.processInfo.disableAutomaticTermination("FontDial keeps a menu bar status item active")

        UserDefaults.standard.register(defaults: [
            DefaultsKey.showInMenuBar: true,
            DefaultsKey.showInDock: false
        ])

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
    }

    private func applyShellPreferences() {
        let defaults = UserDefaults.standard
        var showInMenuBar = defaults.bool(forKey: DefaultsKey.showInMenuBar)
        let showInDock = defaults.bool(forKey: DefaultsKey.showInDock)

        if !showInMenuBar && !showInDock {
            showInMenuBar = true
            defaults.set(true, forKey: DefaultsKey.showInMenuBar)
        }

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
    }

    private func removeStatusItem() {
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
