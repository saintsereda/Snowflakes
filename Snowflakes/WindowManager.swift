//
//  WindowManager.swift
//  Snowflakes
//
//  Created by Andrew Sereda on 22.10.2025.
//

import Cocoa
import CoreGraphics
import Combine

final class WindowManager: NSObject, ObservableObject {
    private(set) var controllers: [OverlayWindowController] = []

    override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onScreensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        // Build at launch
        rebuildForAllScreens()

        // Live-apply whenever settings change
        NotificationCenter.default.addObserver(
            forName: .SnowSettingsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.apply(SnowSettings.shared)
        }
    }

    @objc func onScreensChanged() {
        rebuildForAllScreens()
        // After rebuilding, re-apply current settings so new windows pick up state
        apply(SnowSettings.shared)
    }

    func rebuildForAllScreens() {
        controllers.forEach { $0.close() }
        controllers.removeAll()
        for screen in NSScreen.screens {
            controllers.append(OverlayWindowController(screen: screen))
        }
    }

    func apply(_ settings: SnowSettings) {
        controllers.forEach { $0.apply(settings: settings) }
        if settings.enabled {
            controllers.forEach { $0.showWindow(nil) }
        } else {
            controllers.forEach { $0.window?.orderOut(nil) }
        }
    }
}

final class OverlayWindowController: NSWindowController {
    private let snowView: SnowView

    init(screen: NSScreen) {
        let frame = screen.frame
        let window = NSWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

        snowView = SnowView(frame: NSRect(origin: .zero, size: frame.size))
        window.contentView = snowView

        super.init(window: window)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func apply(settings: SnowSettings) {
        guard let window else { return }

        // Appearance → window level + behaviors
        switch settings.appearance {
        case .overContent:
            window.level = .statusBar
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            window.orderFrontRegardless()
        case .desktopOnly:
            let desktopIconLevel = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)))
            window.level = desktopIconLevel
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            window.orderBack(nil)
        }

        // Cutoff + physics
        snowView.apply(settings: settings)
    }
}
