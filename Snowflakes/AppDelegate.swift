//
//  AppDelegate.swift - Enhanced with dock icon management
//  Snowflakes
//
//  Created by Andrew Sereda on 22.10.2025.
//  Enhanced to show dock icon when settings window is open
//

import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    // Status bar
    private var statusItem: NSStatusItem!

    // Menu items we need to toggle/check
    private var toggleItem: NSMenuItem!
    private var smallItem: NSMenuItem!
    private var fullItem: NSMenuItem!
    private var overContentItem: NSMenuItem!
    private var desktopOnlyItem: NSMenuItem!

    // App state
    private let settings = SnowSettings.shared
    private let windows  = WindowManager()
    private let launchAtLogin = LaunchAtLogin.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        buildStatusMenu()

        // Initialize launch at login (auto-enables on first run)
        launchAtLogin.refresh()

        // Create overlays for all screens and apply current settings
        windows.apply(settings)

        // React to settings changes (from Settings window or menu)
        NotificationCenter.default.addObserver(
            forName: .SnowSettingsDidChange,
            object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.windows.apply(self.settings)
            self.refreshMenuChecks()
            self.applyStatusIcon(isActive: self.settings.enabled)
        }

        // ADDED: Listen for settings window state changes
        NotificationCenter.default.addObserver(
            forName: .SettingsWindowDidOpen,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.showDockIcon()
        }

        NotificationCenter.default.addObserver(
            forName: .SettingsWindowDidClose,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.hideDockIcon()
        }
    }

    // MARK: - Dock Icon Management

    private func showDockIcon() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func hideDockIcon() {
        // Small delay to ensure window closing animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    // MARK: - Menu

    private func buildStatusMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.imagePosition = .imageOnly
            applyStatusIcon(isActive: settings.enabled)
            button.toolTip = settings.enabled ? "Snowfall: On" : "Snowfall: Off"
        }

        let menu = NSMenu()
        menu.delegate = self

        // Toggle Snow
        toggleItem = NSMenuItem(title: settings.enabled ? "Hide Snow" : "Show Snow",
                                action: #selector(toggleSnow), keyEquivalent: "s")
        toggleItem.target = self
        menu.addItem(toggleItem)

        // ---- Window options ----
        let windowMenu = NSMenu(title: "Window")
        smallItem = NSMenuItem(title: "Small (150 px)", action: #selector(setSmallWindow), keyEquivalent: "")
        fullItem  = NSMenuItem(title: "Full",            action: #selector(setFullWindow),  keyEquivalent: "")
        smallItem.target = self
        fullItem.target  = self

        let windowParent = NSMenuItem(title: "Window", action: nil, keyEquivalent: "")
        menu.setSubmenu(windowMenu, for: windowParent)
        windowMenu.addItem(smallItem)
        windowMenu.addItem(fullItem)
        menu.addItem(windowParent)

        // ---- Appearance options ----
        let appearanceMenu = NSMenu(title: "Appearance")
        overContentItem  = NSMenuItem(title: "Over the content", action: #selector(setOverContent), keyEquivalent: "")
        desktopOnlyItem  = NSMenuItem(title: "Desktop only",     action: #selector(setDesktopOnly), keyEquivalent: "")
        overContentItem.target = self
        desktopOnlyItem.target = self

        let appearanceParent = NSMenuItem(title: "Appearance", action: nil, keyEquivalent: "")
        menu.setSubmenu(appearanceMenu, for: appearanceParent)
        appearanceMenu.addItem(overContentItem)
        appearanceMenu.addItem(desktopOnlyItem)
        menu.addItem(appearanceParent)

        // Settings…
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        // Launch at Login menu item
        let launchAtLoginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchAtLoginItem.target = self
        menu.addItem(launchAtLoginItem)

        menu.addItem(.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu

        // Initial checkmarks/titles
        refreshMenuChecks()
    }

    // Keep the menu states fresh whenever it opens
    func menuWillOpen(_ menu: NSMenu) { refreshMenuChecks() }

    private func refreshMenuChecks() {
        // Toggle title
        toggleItem.title = settings.enabled ? "Hide Snow" : "Show Snow"

        // Window cutoff checks
        smallItem.state = (settings.cutoff == .small150) ? .on : .off
        fullItem.state  = (settings.cutoff == .full)     ? .on : .off

        // Appearance checks
        overContentItem.state  = (settings.appearance == .overContent) ? .on : .off
        desktopOnlyItem.state  = (settings.appearance == .desktopOnly) ? .on : .off

        // Launch at Login check
        if let launchAtLoginItem = statusItem.menu?.item(withTitle: "Launch at Login") {
            launchAtLoginItem.state = launchAtLogin.isEnabled ? .on : .off
        }

        // Keep tooltip current
        statusItem.button?.toolTip = settings.enabled ? "Snowfall: On" : "Snowfall: Off"
    }

    // MARK: - SF Symbol status icon

    private enum Symbol {
        static let activeCandidates   = ["snowflake", "snow", "sparkles"]
        static let inactiveCandidates = ["snowflake.slash", "nosign"]
    }

    private func applyStatusIcon(isActive: Bool) {
        let candidates = isActive ? Symbol.activeCandidates : Symbol.inactiveCandidates
        let desc = isActive ? "Snowfall On" : "Snowfall Off"

        if let image = makeSymbol(from: candidates,
                                  pointSize: 18,
                                  weight: .regular,
                                  desc: desc) {
            image.isTemplate = true
            statusItem.button?.image = image
            statusItem.button?.title = ""
        } else {
            statusItem.button?.image = nil
            statusItem.button?.title = isActive ? "❄︎" : "⛔︎"
        }
    }

    private func makeSymbol(from candidates: [String],
                            pointSize: CGFloat,
                            weight: NSFont.Weight,
                            desc: String) -> NSImage? {
        for name in candidates {
            if let base = NSImage(systemSymbolName: name, accessibilityDescription: desc) {
                let cfg = NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
                return base.withSymbolConfiguration(cfg)
            }
        }
        return nil
    }

    // MARK: - Actions

    @objc private func toggleSnow() {
        settings.enabled.toggle()
        settings.notifyChanged()
        applyStatusIcon(isActive: settings.enabled)
    }

    @objc private func setSmallWindow() {
        settings.cutoff = .small150
        settings.notifyChanged()
    }

    @objc private func setFullWindow() {
        settings.cutoff = .full
        settings.notifyChanged()
    }

    @objc private func setOverContent() {
        settings.appearance = .overContent
        settings.notifyChanged()
    }

    @objc private func setDesktopOnly() {
        settings.appearance = .desktopOnly
        settings.notifyChanged()
    }

    @objc private func openSettings() {
        SettingsWindowController.shared.show()
    }

    @objc private func toggleLaunchAtLogin() {
        launchAtLogin.toggle()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let SettingsWindowDidOpen = Notification.Name("SettingsWindowDidOpen")
    static let SettingsWindowDidClose = Notification.Name("SettingsWindowDidClose")
}
