//
//  SettingsWindow.swift
//  Snowflakes
//
//  Created by Andrew Sereda on 22.10.2025.
//

import SwiftUI
import Combine

struct SettingsView: View {
    @ObservedObject var s = SnowSettings.shared
    @State private var showingResetAlert = false

    var body: some View {
        VStack(spacing: 0) {
            // Main settings form
            Form {
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

struct PhysicsSection: View {
    @ObservedObject var settings: SnowSettings
    
    var body: some View {
        Section("Physics") {
            // INCREASED RANGE: 0.1 to 3.0 (was 0.3 to 2.0)
            // Now: 0.1 = very few flakes, 3.0 = snow storm
            HStack { Text("Intensity"); Slider(value: $settings.intensity, in: 0.1...3.0) }
            
            // INCREASED RANGE: 0 to 30 (was 0 to 20)
            // Now: 0 = no wind, 30 = hurricane-force wind
            HStack { Text("Wind"); Slider(value: $settings.windAmplitude, in: 0...30) }
            
            WindDirectionPicker(settings: settings)
            
            // INCREASED RANGE: 0.2 to 3.0 (was 0.6 to 1.6)
            // Now: 0.2 = super slow motion, 3.0 = fast falling
            HStack { Text("Speed"); Slider(value: $settings.speedMultiplier, in: 0.2...3.0) }
        }
    }
}

struct VisualsSection: View {
    @ObservedObject var settings: SnowSettings
    
    var body: some View {
        Section("Visuals") {
            // INCREASED RANGE: 0.3 to 2.5 (was 0.6 to 1.6)
            // Now: 0.3 = tiny dots, 2.5 = huge flakes
            HStack { Text("Flake Size"); Slider(value: $settings.sizeMultiplier, in: 0.3...2.5) }
            
            // INCREASED RANGE: 0 to 60 (was 0 to 40)
            // Now: 0 = straight down column, 60 = wide cone spread
            HStack { Text("Emission Spread (°)"); Slider(value: $settings.emissionSpreadDeg, in: 0...60) }
            
            // INCREASED RANGE: 0.0 to 3.0 (was 0.0 to 1.2)
            // Now: 0.0 = no rotation, 3.0 = fast spinning
            HStack { Text("Spin"); Slider(value: $settings.spinBase, in: 0.0...3.0) }
            
            // INCREASED RANGE: 0.0 to 4.0 (was 0.0 to 2.0)
            // Now: 0.0 = all same speed, 4.0 = wild variation
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
                // Left arrow button
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
                
                // Right arrow button
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

// Simple NSWindowController hosting SwiftUI SettingsView
final class SettingsWindowController: NSWindowController {
    static let shared = SettingsWindowController()

    private init() {
        let hosting = NSHostingView(rootView: SettingsView())
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 520), // Slightly taller for reset button
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false
        )
        window.title = "Snowflakes Settings"
        window.center()
        window.isReleasedWhenClosed = false
        window.contentView = hosting
        super.init(window: window)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
