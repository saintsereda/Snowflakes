//
//  WindowManager.swift - Fixed for extended displays
//  Snowflakes
//
//  Created by Andrew Sereda on 22.10.2025.
//  Enhanced to reliably detect and handle extended displays
//

import Cocoa
import CoreGraphics
import Combine

final class WindowManager: NSObject, ObservableObject {
    private(set) var controllers: [OverlayWindowController] = []
    private var screenIdentifiers: Set<String> = []
    private var rebuildWorkItem: DispatchWorkItem?
    private var lastSettings: SnowSettings?

    override init() {
        super.init()
        
        // Listen to multiple screen change notifications for better coverage
        let notifications: [Notification.Name] = [
            NSApplication.didChangeScreenParametersNotification,
            NSWorkspace.activeSpaceDidChangeNotification
        ]
        
        for name in notifications {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(scheduleScreenCheck),
                name: name,
                object: nil
            )
        }
        
        // Initial build
        printScreenInfo("INITIAL")
        rebuildForAllScreens()
        
        // Save initial screen state
        updateScreenIdentifiers()

        // Live-apply whenever settings change
        NotificationCenter.default.addObserver(
            forName: .SnowSettingsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.apply(SnowSettings.shared)
        }
        
        // Periodic check for screen changes (every 2 seconds)
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkForScreenChanges()
        }
    }
    
    deinit {
        rebuildWorkItem?.cancel()
    }
    
    // MARK: - Screen Identification
    
    private func updateScreenIdentifiers() {
        screenIdentifiers = Set(NSScreen.screens.map { screenIdentifier(for: $0) })
    }
    
    private func screenIdentifier(for screen: NSScreen) -> String {
        // Create unique identifier using frame and name
        let frame = screen.frame
        return "\(screen.localizedName)-\(Int(frame.origin.x))-\(Int(frame.origin.y))-\(Int(frame.width))-\(Int(frame.height))"
    }
    
    // MARK: - Screen Change Detection
    
    @objc private func scheduleScreenCheck() {
        // Cancel any pending rebuild
        rebuildWorkItem?.cancel()
        
        // Schedule a new rebuild with a slight delay to batch multiple notifications
        let workItem = DispatchWorkItem { [weak self] in
            self?.checkForScreenChanges()
        }
        rebuildWorkItem = workItem
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: workItem)
    }
    
    private func checkForScreenChanges() {
        let currentScreens = NSScreen.screens
        let currentIdentifiers = Set(currentScreens.map { screenIdentifier(for: $0) })
        
        // Check if screens have changed
        let screensChanged = currentIdentifiers != screenIdentifiers
        let countChanged = currentScreens.count != controllers.count
        
        if screensChanged || countChanged {
            print("🔄 Screen configuration changed!")
            printScreenInfo("CHANGE DETECTED")
            print("Previous screens: \(screenIdentifiers.count)")
            print("Current screens: \(currentIdentifiers.count)")
            
            // Update stored identifiers
            screenIdentifiers = currentIdentifiers
            
            // Rebuild windows
            rebuildForAllScreens()
            
            // Reapply last settings if available
            if let settings = lastSettings {
                apply(settings)
            }
        }
    }
    
    private func printScreenInfo(_ context: String) {
        print("\n=== SCREEN INFO (\(context)) ===")
        print("Screen count: \(NSScreen.screens.count)")
        for (i, screen) in NSScreen.screens.enumerated() {
            let isMain = screen == NSScreen.main ? " (MAIN)" : ""
            print("Screen \(i)\(isMain): \(screen.localizedName)")
            print("  Frame: \(screen.frame)")
            print("  Visible: \(screen.visibleFrame)")
            print("  ID: \(screenIdentifier(for: screen))")
        }
        print("Controller count: \(controllers.count)")
        print("=======================\n")
    }

    // MARK: - Window Management
    
    func rebuildForAllScreens() {
        print("🔧 REBUILDING for \(NSScreen.screens.count) screens...")
        
        // Close existing controllers
        for (i, controller) in controllers.enumerated() {
            print("Closing controller \(i)")
            controller.close()
        }
        controllers.removeAll()
        
        // Small delay to ensure screens are stable
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self else { return }
            
            let currentScreens = NSScreen.screens
            print("Creating controllers for \(currentScreens.count) screens")
            
            // Create new controllers for all screens
            for (i, screen) in currentScreens.enumerated() {
                print("Creating controller \(i) for: \(screen.localizedName)")
                let controller = OverlayWindowController(screen: screen)
                self.controllers.append(controller)
            }
            
            print("✅ Rebuild complete - \(self.controllers.count) controllers created")
            self.printScreenInfo("AFTER REBUILD")
            
            // Update screen identifiers
            self.updateScreenIdentifiers()
            
            // Reapply settings if we have them
            if let settings = self.lastSettings {
                self.apply(settings)
            }
        }
    }

    func apply(_ settings: SnowSettings) {
        // Store settings for reapplication after screen changes
        lastSettings = settings
        
        // Verify we have controllers for all screens
        if controllers.count != NSScreen.screens.count {
            print("⚠️ Controller count mismatch - rebuilding...")
            rebuildForAllScreens()
            return
        }
        
        print("⚙️ Applying settings to \(controllers.count) overlays (enabled: \(settings.enabled))")
        
        for (i, controller) in controllers.enumerated() {
            controller.apply(settings: settings)
            
            if settings.enabled {
                controller.showWindow(nil)
                if let window = controller.window, let screen = window.screen {
                    print("✅ Overlay \(i) shown on: \(screen.localizedName)")
                } else {
                    print("❌ Overlay \(i) failed to show - no screen!")
                }
            } else {
                controller.window?.orderOut(nil)
                print("🙈 Overlay \(i) hidden")
            }
        }
    }
}

final class OverlayWindowController: NSWindowController {
    private let snowView: SnowView
    private let targetScreen: NSScreen
    private let screenIdentifier: String

    init(screen: NSScreen) {
        self.targetScreen = screen
        
        // Store screen identifier for validation
        let frame = screen.frame
        self.screenIdentifier = "\(screen.localizedName)-\(Int(frame.origin.x))-\(Int(frame.origin.y))"
        
        print("🖼️ Creating window for screen: \(screen.localizedName) at \(frame)")
        
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
        
        // Force window to appear on the target screen
        window.setFrameOrigin(frame.origin)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func apply(settings: SnowSettings) {
        guard let window else { return }

        // Verify window is on correct screen and reposition if needed
        if window.screen?.localizedName != targetScreen.localizedName {
            print("⚠️ Window screen mismatch - repositioning")
            let frame = targetScreen.frame
            window.setFrame(frame, display: true, animate: false)
            snowView.frame = NSRect(origin: .zero, size: frame.size)
        }

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
