//
//  SnowSettings.swift - Enhanced with drifting/zigzag control
//  Snowflakes
//
//  Created by Andrew Sereda on 22.10.2025.
//  Enhanced with drifting parameter for natural zigzag motion
//

import SwiftUI
import Combine

// Typed notification for live updates
extension Notification.Name {
    static let SnowSettingsDidChange = Notification.Name("SnowSettingsDidChange")
}

final class SnowSettings: ObservableObject, Codable {
    static let shared: SnowSettings = SnowSettings.loadFromDefaults()

    // MARK: - Default Values
    private struct Defaults {
        static let enabled: Bool = true
        static let intensity: CGFloat = 1.0
        static let windAmplitude: CGFloat = 0
        static let speedMultiplier: CGFloat = 1.0
        static let sizeMultiplier: CGFloat = 1.0
        static let emissionSpreadDeg: CGFloat = 12
        static let spinBase: CGFloat = 0.25
        static let spinRange: CGFloat = 1.0
        static let drifting: CGFloat = 1.0  // New: zigzag/sway power (0 = straight down, 3 = maximum sway)
        static let cutoff: Cutoff = .full
        static let appearance: Appearance = .overContent
        static let shape: SnowShape = .dots
        static let windDirection: WindDirection = .right
    }

    // Enable / disable snowfall
    @Published var enabled: Bool = Defaults.enabled

    // Physics/visuals (Published for SwiftUI; Codable via mirror struct below)
    @Published var intensity: CGFloat = Defaults.intensity
    @Published var windAmplitude: CGFloat = Defaults.windAmplitude
    @Published var speedMultiplier: CGFloat = Defaults.speedMultiplier

    @Published var sizeMultiplier: CGFloat = Defaults.sizeMultiplier
    @Published var emissionSpreadDeg: CGFloat = Defaults.emissionSpreadDeg
    @Published var spinBase: CGFloat = Defaults.spinBase
    @Published var spinRange: CGFloat = Defaults.spinRange
    @Published var drifting: CGFloat = Defaults.drifting  // New drifting parameter

    enum Cutoff: String, Codable, CaseIterable { case full, small150 }
    enum Appearance: String, Codable, CaseIterable { case overContent, desktopOnly }
    enum SnowShape: String, Codable, CaseIterable { case dots, classic, star, crystal, mixed, custom }
    enum WindDirection: String, Codable, CaseIterable { case left, right }

    @Published var cutoff: Cutoff = Defaults.cutoff
    @Published var appearance: Appearance = Defaults.appearance
    @Published var shape: SnowShape = Defaults.shape
    @Published var windDirection: WindDirection = Defaults.windDirection

    // Baselines for parallax layers
    struct LayerBase: Codable {
        var baseSize: CGFloat
        var birthTotal: Float
        var yAccel: CGFloat
        var alphaSpeed: CGFloat
    }
    var far  = LayerBase(baseSize: 18, birthTotal: 32, yAccel: -70,  alphaSpeed: -0.010)
    var mid  = LayerBase(baseSize: 24, birthTotal: 28, yAccel: -90,  alphaSpeed: -0.014)
    var near = LayerBase(baseSize: 32, birthTotal: 22, yAccel: -110, alphaSpeed: -0.018)

    // MARK: - Reset to Defaults
    func resetToDefaults() {
        enabled = Defaults.enabled
        intensity = Defaults.intensity
        windAmplitude = Defaults.windAmplitude
        speedMultiplier = Defaults.speedMultiplier
        sizeMultiplier = Defaults.sizeMultiplier
        emissionSpreadDeg = Defaults.emissionSpreadDeg
        spinBase = Defaults.spinBase
        spinRange = Defaults.spinRange
        drifting = Defaults.drifting
        cutoff = Defaults.cutoff
        appearance = Defaults.appearance
        shape = Defaults.shape
        windDirection = Defaults.windDirection
        
        // Notify about the changes
        notifyChanged()
    }

    // Persist
    private static let defaultsKey = "SnowSettings.swiftui.v2"  // Updated version for new parameter

    func notifyChanged() {
        saveToDefaults()
        objectWillChange.send() // ping SwiftUI bindings
        NotificationCenter.default.post(name: .SnowSettingsDidChange, object: self) // <-- broadcast for AppKit listeners
    }

    private func saveToDefaults() {
        do { UserDefaults.standard.set(try JSONEncoder().encode(snapshot), forKey: Self.defaultsKey) }
        catch { NSLog("SnowSettings save error: \(error)") }
    }

    private static func loadFromDefaults() -> SnowSettings {
        let s = SnowSettings()
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return s }
        do { try s.applySnapshot(JSONDecoder().decode(Snap.self, from: data)) }
        catch { NSLog("SnowSettings load error: \(error)") }
        return s
    }

    // Codable snapshot (CGFloat → Double; Published mirroring)
    private struct Snap: Codable {
        var enabled: Bool
        var intensity: Double; var windAmplitude: Double; var speedMultiplier: Double
        var sizeMultiplier: Double; var emissionSpreadDeg: Double; var spinBase: Double; var spinRange: Double
        var drifting: Double  // New parameter
        var cutoff: Cutoff; var appearance: Appearance; var shape: SnowShape; var windDirection: WindDirection
    }
    private var snapshot: Snap {
        Snap(
            enabled: enabled,
            intensity: intensity.d, windAmplitude: windAmplitude.d, speedMultiplier: speedMultiplier.d,
            sizeMultiplier: sizeMultiplier.d, emissionSpreadDeg: emissionSpreadDeg.d, spinBase: spinBase.d, spinRange: spinRange.d,
            drifting: drifting.d,
            cutoff: cutoff, appearance: appearance, shape: shape, windDirection: windDirection
        )
    }
    private func applySnapshot(_ p: Snap) throws {
        enabled = p.enabled
        intensity = p.intensity.cg; windAmplitude = p.windAmplitude.cg; speedMultiplier = p.speedMultiplier.cg
        sizeMultiplier = p.sizeMultiplier.cg; emissionSpreadDeg = p.emissionSpreadDeg.cg; spinBase = p.spinBase.cg; spinRange = p.spinRange.cg
        drifting = p.drifting.cg
        cutoff = p.cutoff; appearance = p.appearance; shape = p.shape; windDirection = p.windDirection
    }

    // Codable conformance (unused, but required by protocol)
    init() {}
    required convenience init(from decoder: Decoder) throws { self.init() }
    func encode(to encoder: Encoder) throws {}
}

private extension Double { var cg: CGFloat { .init(self) } }
private extension CGFloat { var d: Double { .init(self) } }
