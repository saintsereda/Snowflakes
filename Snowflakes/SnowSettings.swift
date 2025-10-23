//
//  SnowSettings.swift
//  Snowflakes
//
//  Created by Andrew Sereda on 22.10.2025.
//

import SwiftUI
import Combine

// Typed notification for live updates
extension Notification.Name {
    static let SnowSettingsDidChange = Notification.Name("SnowSettingsDidChange")
}

final class SnowSettings: ObservableObject, Codable {
    static let shared: SnowSettings = SnowSettings.loadFromDefaults()

    // Enable / disable snowfall
    @Published var enabled: Bool = true

    // Physics/visuals (Published for SwiftUI; Codable via mirror struct below)
    @Published var intensity: CGFloat = 1.0
    @Published var windAmplitude: CGFloat = 6.0
    @Published var speedMultiplier: CGFloat = 1.0

    @Published var sizeMultiplier: CGFloat = 1.0
    @Published var emissionSpreadDeg: CGFloat = 12
    @Published var spinBase: CGFloat = 0.25
    @Published var spinRange: CGFloat = 1.0

    enum Cutoff: String, Codable, CaseIterable { case full, small150 }
    enum Appearance: String, Codable, CaseIterable { case overContent, desktopOnly }
    enum SnowShape: String, Codable, CaseIterable { case dots, classic, star, crystal, mixed, custom }
    enum WindDirection: String, Codable, CaseIterable { case left, right }

    @Published var cutoff: Cutoff = .full
    @Published var appearance: Appearance = .overContent
    @Published var shape: SnowShape = .dots
    @Published var windDirection: WindDirection = .right

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

    // Persist
    private static let defaultsKey = "SnowSettings.swiftui.v1"

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
        // REMOVED: twinkle from snapshot
        var sizeMultiplier: Double; var emissionSpreadDeg: Double; var spinBase: Double; var spinRange: Double
        var cutoff: Cutoff; var appearance: Appearance; var shape: SnowShape; var windDirection: WindDirection
    }
    private var snapshot: Snap {
        Snap(
            enabled: enabled,
            intensity: intensity.d, windAmplitude: windAmplitude.d, speedMultiplier: speedMultiplier.d,
            // REMOVED: twinkle from snapshot creation
            sizeMultiplier: sizeMultiplier.d, emissionSpreadDeg: emissionSpreadDeg.d, spinBase: spinBase.d, spinRange: spinRange.d,
            cutoff: cutoff, appearance: appearance, shape: shape, windDirection: windDirection
        )
    }
    private func applySnapshot(_ p: Snap) throws {
        enabled = p.enabled
        intensity = p.intensity.cg; windAmplitude = p.windAmplitude.cg; speedMultiplier = p.speedMultiplier.cg
        // REMOVED: twinkle from snapshot application
        sizeMultiplier = p.sizeMultiplier.cg; emissionSpreadDeg = p.emissionSpreadDeg.cg; spinBase = p.spinBase.cg; spinRange = p.spinRange.cg
        cutoff = p.cutoff; appearance = p.appearance; shape = p.shape; windDirection = p.windDirection
    }

    // Codable conformance (unused, but required by protocol)
    init() {}
    required convenience init(from decoder: Decoder) throws { self.init() }
    func encode(to encoder: Encoder) throws {}
}

private extension Double { var cg: CGFloat { .init(self) } }
private extension CGFloat { var d: Double { .init(self) } }
