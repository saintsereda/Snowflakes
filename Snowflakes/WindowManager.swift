//
//  WindowManager.swift - Debug version to understand screen detection
//  Snowflakes
//
//  Created by Andrew Sereda on 22.10.2025.
//  Debug version to understand extended display issues
//

import Cocoa
import CoreGraphics
import Combine

final class WindowManager: NSObject, ObservableObject {
    private(set) var controllers: [OverlayWindowController] = []
    private var lastScreenCount = 0
    private var isRebuilding = false

    override init() {
        super.init()
        
        // Listen to screen change notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onScreensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        
        // ADDED: Also listen to workspace notifications which catch display changes better
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onScreensChanged),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )
        
        // Build at launch
        printScreenInfo("INITIAL")
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
        
        // ADDED: Force check every 5 seconds as backup
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkScreens()
        }
    }
    
    private func printScreenInfo(_ context: String) {
        print("\n=== SCREEN INFO (\(context)) ===")
        print("Screen count: \(NSScreen.screens.count)")
        for (i, screen) in NSScreen.screens.enumerated() {
            print("Screen \(i): \(screen.localizedName) - Frame: \(screen.frame)")
        }
        print("Controller count: \(controllers.count)")
        print("=======================\n")
    }
    
    private func checkScreens() {
        let currentCount = NSScreen.screens.count
        if currentCount != controllers.count {
            print("BACKUP CHECK: Screen count mismatch detected!")
            printScreenInfo("BACKUP CHECK")
            onScreensChanged()
        }
    }

    @objc func onScreensChanged() {
        guard !isRebuilding else {
            print("Already rebuilding, skipping...")
            return
        }
        
        let currentScreenCount = NSScreen.screens.count
        
        print("Screen change detected! Current: \(currentScreenCount), Last: \(lastScreenCount)")
        printScreenInfo("SCREEN CHANGE")
        
        // Always rebuild if counts don't match
        if currentScreenCount != lastScreenCount {
            print("Screen count changed - rebuilding...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.rebuildForAllScreens()
                self.apply(SnowSettings.shared)
            }
        }
    }

    func rebuildForAllScreens() {
        guard !isRebuilding else { return }
        isRebuilding = true
        
        print("🔧 REBUILDING for \(NSScreen.screens.count) screens...")
        
        // Close existing controllers
        for (i, controller) in controllers.enumerated() {
            print("Closing controller \(i)")
            controller.close()
        }
        controllers.removeAll()
        
        // Create new controllers for all screens
        for (i, screen) in NSScreen.screens.enumerated() {
            print("Creating controller \(i) for: \(screen.localizedName)")
            let controller = OverlayWindowController(screen: screen)
            controllers.append(controller)
        }
        
        lastScreenCount = NSScreen.screens.count
        isRebuilding = false
        
        print("✅ Rebuild complete - \(controllers.count) controllers created")
        printScreenInfo("AFTER REBUILD")
    }

    func apply(_ settings: SnowSettings) {
        guard !isRebuilding else { return }
        
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

    init(screen: NSScreen) {
        self.targetScreen = screen
        let frame = screen.frame
        
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
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func apply(settings: SnowSettings) {
        guard let window else { return }

        // Check if window is on correct screen
        if window.screen != targetScreen {
            print("⚠️ Window moved to different screen - repositioning")
            window.setFrame(targetScreen.frame, display: true, animate: false)
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
