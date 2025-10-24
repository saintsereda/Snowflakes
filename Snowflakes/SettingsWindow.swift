//
//  SettingsWindow.swift - Enhanced with guaranteed front window behavior
//  Snowflakes
//
//  Created by Andrew Sereda on 22.10.2025.
//  Enhanced to always bring settings window to front
//

import SwiftUI
import Combine

struct SettingsView: View {
    @ObservedObject var s = SnowSettings.shared
    @ObservedObject var launchAtLogin = LaunchAtLogin.shared
    @State private var showingResetAlert = false

    var body: some View {
        VStack(spacing: 0) {
            // Main settings form
            Form {
                GeneralSection(launchAtLogin: launchAtLogin)
                PhysicsSection(settings: s)
                VisualsSection(settings: s)
                WindowSection(settings: s)
            }
            .padding(16)
            
            // Reset button at the bottom
            VStack(spacing: 8) {
                Divider()
                
                HStack {
                    Spacer()
                    
                    Button("Reset to Defaults") {
                        showingResetAlert = true
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.red)
                    .alert("Reset Settings", isPresented: $showingResetAlert) {
                        Button("Cancel", role: .cancel) { }
                        Button("Reset", role: .destructive) {
                            s.resetToDefaults()
                        }
                    } message: {
                        Text("This will reset all settings to their default values. This action cannot be undone.")
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
        .frame(width: 520)
        .onAppear {
            launchAtLogin.refresh()
        }
        .onChange(of: s.intensity) { s.notifyChanged() }
        .onChange(of: s.windAmplitude) { s.notifyChanged() }
        .onChange(of: s.speedMultiplier) { s.notifyChanged() }
        .onChange(of: s.sizeMultiplier) { s.notifyChanged() }
        .onChange(of: s.emissionSpreadDeg) { s.notifyChanged() }
        .onChange(of: s.spinBase) { s.notifyChanged() }
        .onChange(of: s.spinRange) { s.notifyChanged() }
        .onChange(of: s.shape) { s.notifyChanged() }
        .onChange(of: s.cutoff) { s.notifyChanged() }
        .onChange(of: s.appearance) { s.notifyChanged() }
        .onChange(of: s.windDirection) { s.notifyChanged() }
    }
}

struct GeneralSection: View {
    @ObservedObject var launchAtLogin: LaunchAtLogin
    
    var body: some View {
        Section("General") {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Launch at Login")
                        .font(.system(size: 13))
                    Text("Automatically start Snowflakes when you log in")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $launchAtLogin.isEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
            .padding(.vertical, 4)
        }
    }
}

struct PhysicsSection: View {
    @ObservedObject var settings: SnowSettings
    
    var body: some View {
        Section("Physics") {
            HStack { Text("Intensity"); Slider(value: $settings.intensity, in: 0.1...3.0) }
            HStack { Text("Wind"); Slider(value: $settings.windAmplitude, in: 0...30) }
            WindDirectionPicker(settings: settings)
            HStack { Text("Speed"); Slider(value: $settings.speedMultiplier, in: 0.2...3.0) }
        }
    }
}

struct VisualsSection: View {
    @ObservedObject var settings: SnowSettings
    
    var body: some View {
        Section("Visuals") {
            HStack { Text("Flake Size"); Slider(value: $settings.sizeMultiplier, in: 0.3...2.5) }
            HStack { Text("Emission Spread (°)"); Slider(value: $settings.emissionSpreadDeg, in: 0...60) }
            HStack { Text("Spin"); Slider(value: $settings.spinBase, in: 0.0...3.0) }
            HStack { Text("Spin Variability"); Slider(value: $settings.spinRange, in: 0.0...4.0) }
            ShapePicker(settings: settings)
        }
    }
}

struct ShapePicker: View {
    @ObservedObject var settings: SnowSettings
    
    var body: some View {
        Picker("Shape", selection: $settings.shape) {
            Text("Dots").tag(SnowSettings.SnowShape.dots)
            Text("Classic ❄︎").tag(SnowSettings.SnowShape.classic)
            Text("Star ✦").tag(SnowSettings.SnowShape.star)
            Text("Crystal ✧").tag(SnowSettings.SnowShape.crystal)
            Text("Mixed").tag(SnowSettings.SnowShape.mixed)
            Text("Custom PNG").tag(SnowSettings.SnowShape.custom)
        }
    }
}

struct WindowSection: View {
    @ObservedObject var settings: SnowSettings
    
    var body: some View {
        Section("Window") {
            Picker("Cutoff", selection: $settings.cutoff) {
                Text("Full").tag(SnowSettings.Cutoff.full)
                Text("Small (150 px)").tag(SnowSettings.Cutoff.small150)
            }
            Picker("Appearance", selection: $settings.appearance) {
                Text("Over the content").tag(SnowSettings.Appearance.overContent)
                Text("Desktop only").tag(SnowSettings.Appearance.desktopOnly)
            }
        }
    }
}

struct WindDirectionPicker: View {
    @ObservedObject var settings: SnowSettings
    
    var body: some View {
        HStack {
            Text("Wind Direction")
            Spacer()
            HStack(spacing: 8) {
                Button(action: { settings.windDirection = .left }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 14, weight: .medium))
                        Text("Left")
                            .font(.system(size: 12))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(settings.windDirection == .left ? Color.accentColor : Color.gray.opacity(0.2))
                    .foregroundColor(settings.windDirection == .left ? .white : .primary)
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: { settings.windDirection = .right }) {
                    HStack(spacing: 4) {
                        Text("Right")
                            .font(.system(size: 12))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(settings.windDirection == .right ? Color.accentColor : Color.gray.opacity(0.2))
                    .foregroundColor(settings.windDirection == .right ? .white : .primary)
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

// Enhanced NSWindowController with guaranteed front window behavior
final class SettingsWindowController: NSWindowController {
    static let shared = SettingsWindowController()

    private init() {
        let hosting = NSHostingView(rootView: SettingsView())
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 580),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false
        )
        window.title = "Snowflakes Settings"
        window.center()
        window.isReleasedWhenClosed = false
        window.contentView = hosting
        
        // ENHANCED: Set window properties for better front behavior
        window.level = .normal
        window.collectionBehavior = [.moveToActiveSpace]
        
        super.init(window: window)
        
        setupWindowObservers()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    private func setupWindowObservers() {
        guard let window = window else { return }
        
        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeMainNotification,
            object: window,
            queue: .main
        ) { _ in
            NotificationCenter.default.post(name: .SettingsWindowDidOpen, object: nil)
        }
        
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { _ in
            NotificationCenter.default.post(name: .SettingsWindowDidClose, object: nil)
        }
        
        NotificationCenter.default.addObserver(
            forName: NSWindow.didMiniaturizeNotification,
            object: window,
            queue: .main
        ) { _ in
            NotificationCenter.default.post(name: .SettingsWindowDidClose, object: nil)
        }
        
        NotificationCenter.default.addObserver(
            forName: NSWindow.didDeminiaturizeNotification,
            object: window,
            queue: .main
        ) { _ in
            NotificationCenter.default.post(name: .SettingsWindowDidOpen, object: nil)
        }
    }

    func show() {
        // FIXED: Simpler, more reliable approach
        
        // Step 1: Ensure app activation policy is correct
        NSApp.setActivationPolicy(.regular)
        
        // Step 2: Show the window first
        showWindow(nil)
        
        guard let window = window else { return }
        
        // Step 3: Set window properties for proper behavior
        window.collectionBehavior = [.moveToActiveSpace]
        window.center()
        
        // Step 4: Activate app and bring window to front in sequence
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        
        // Step 5: Short delay then force focus again (without changing window level)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            // Second activation wave - this is the key
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            
            // Make sure this window is the key window
            window.makeKey()
        }
        
        // Post notification
        NotificationCenter.default.post(name: .SettingsWindowDidOpen, object: nil)
    }
    
    override func close() {
        NotificationCenter.default.post(name: .SettingsWindowDidClose, object: nil)
        super.close()
    }
}
