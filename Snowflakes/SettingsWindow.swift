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

    var body: some View {
        Form {
            PhysicsSection(settings: s)
            VisualsSection(settings: s)
            WindowSection(settings: s)
        }
        .padding(16)
        .frame(width: 520)
        .onChange(of: s.intensity) { s.notifyChanged() }
        .onChange(of: s.windAmplitude) { s.notifyChanged() }
        .onChange(of: s.speedMultiplier) { s.notifyChanged() }
        .onChange(of: s.twinkle) { s.notifyChanged() }
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
            HStack { Text("Intensity"); Slider(value: $settings.intensity, in: 0.3...2.0) }
            HStack { Text("Wind"); Slider(value: $settings.windAmplitude, in: 0...20) }
            WindDirectionPicker(settings: settings)
            HStack { Text("Speed"); Slider(value: $settings.speedMultiplier, in: 0.6...1.6) }
            HStack { Text("Twinkle"); Slider(value: $settings.twinkle, in: 0.6...1.6) }
        }
    }
}

struct VisualsSection: View {
    @ObservedObject var settings: SnowSettings
    
    var body: some View {
        Section("Visuals") {
            HStack { Text("Flake Size"); Slider(value: $settings.sizeMultiplier, in: 0.6...1.6) }
            HStack { Text("Emission Spread (Â°)"); Slider(value: $settings.emissionSpreadDeg, in: 0...40) }
            HStack { Text("Spin"); Slider(value: $settings.spinBase, in: 0.0...1.2) }
            HStack { Text("Spin Variability"); Slider(value: $settings.spinRange, in: 0.0...2.0) }
            ShapePicker(settings: settings)
        }
    }
}

struct ShapePicker: View {
    @ObservedObject var settings: SnowSettings
    
    var body: some View {
        Picker("Shape", selection: $settings.shape) {
            Text("Dots").tag(SnowSettings.SnowShape.dots)
            Text("Classic â„ï¸Ž").tag(SnowSettings.SnowShape.classic)
            Text("Star âœ¦").tag(SnowSettings.SnowShape.star)
            Text("Crystal âœ§").tag(SnowSettings.SnowShape.crystal)
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
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 480),
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
