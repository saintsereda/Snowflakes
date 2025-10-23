//
//  SnowView.swift
//  Snowflakes
//
//  Created by Andrew Sereda on 22.10.2025.
//

import Cocoa
import QuartzCore

final class SnowView: NSView {
    override var wantsUpdateLayer: Bool { true }

    // Mask cutoff
    private var cutoffPoints: CGFloat? { didSet { updateCutoffMask() } }
    private let cutoffFeather: CGFloat = 18

    // Parallax emitters
    private var emitters: [CAEmitterLayer] = [] // far, mid, near
    private var currentWindAmp: CGFloat = 6.0
    private var currentWindDirection: SnowSettings.WindDirection = .right

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        let container = CALayer()
        container.masksToBounds = false
        self.layer = container

        addParallaxLayers()
        setupAllEmitters()
        startWindAnimations()
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        layoutEmitters()
        updateCutoffMask()
    }

    func apply(settings: SnowSettings) {
        // Build cells per layer using settings
        func cells(for base: SnowSettings.LayerBase) -> [CAEmitterCell] {
            let sizeBase = base.baseSize * settings.sizeMultiplier
            let yAccel   = base.yAccel * settings.speedMultiplier
            let aSpeed   = base.alphaSpeed * settings.twinkle
            
            // Add wind direction multiplier (-1 for left, +1 for right)
            let windMultiplier: CGFloat = settings.windDirection == .left ? -1.0 : 1.0
            
            // Add base wind velocity (direction-aware)
            let baseWindVel = settings.windAmplitude * 8.0 * windMultiplier  // Increased from 5.0
            
            // Calculate initial horizontal acceleration for immediate wind effect
            let baseXAccel = settings.windAmplitude * 15.0 * windMultiplier  // Increased from 8.0

            let imgs = imagesForShape(size: sizeBase, shape: settings.shape)
            let img0 = imgs.first!
            let img1 = imgs.indices.contains(1) ? imgs[1] : img0
            let img2 = imgs.indices.contains(2) ? imgs[2] : img0

            let neutral = makeCell(size: sizeBase, image: img0, xAccel: baseXAccel, yAccel: yAccel,
                                   alphaSpeed: aSpeed, spinBase: settings.spinBase,
                                   spinRange: settings.spinRange, spreadDeg: settings.emissionSpreadDeg,
                                   baseWindVel: baseWindVel)
            let left    = makeCell(size: sizeBase - 4, image: img1, xAccel: baseXAccel * 0.8, yAccel: yAccel,
                                   alphaSpeed: aSpeed, spinBase: settings.spinBase,
                                   spinRange: settings.spinRange, spreadDeg: settings.emissionSpreadDeg,
                                   baseWindVel: baseWindVel)
            let right   = makeCell(size: sizeBase + 6, image: img2, xAccel: baseXAccel * 1.2,  yAccel: yAccel,
                                   alphaSpeed: aSpeed, spinBase: settings.spinBase,
                                   spinRange: settings.spinRange, spreadDeg: settings.emissionSpreadDeg,
                                   baseWindVel: baseWindVel)

            let total = base.birthTotal * Float(settings.intensity)
            neutral.birthRate = total * 0.5; left.birthRate = total * 0.25; right.birthRate = total * 0.25
            return [neutral, left, right]
        }

        guard emitters.count == 3 else { return }
        emitters[0].emitterCells = cells(for: settings.far)
        emitters[1].emitterCells = cells(for: settings.mid)
        emitters[2].emitterCells = cells(for: settings.near)

        if currentWindAmp != settings.windAmplitude || currentWindDirection != settings.windDirection {
            currentWindAmp = settings.windAmplitude
            currentWindDirection = settings.windDirection
            updateWindAnimations()
        }

        switch settings.cutoff {
        case .full: setCutoff(nil)
        case .small150:
            let scale = window?.backingScaleFactor ?? (window?.screen?.backingScaleFactor ?? 2.0)
            setCutoff(150.0 / scale)
        }
    }

    // MARK: emitter plumbing
    private func addParallaxLayers() {
        guard let container = layer else { return }
        let far = CAEmitterLayer(); far.zPosition = 0
        let mid = CAEmitterLayer(); mid.zPosition = 1
        let near = CAEmitterLayer(); near.zPosition = 2
        [far,mid,near].forEach { $0.masksToBounds = false; container.addSublayer($0) }
        emitters = [far, mid, near]
    }

    private func setupAllEmitters() {
        for e in emitters {
            e.emitterShape = .line; e.emitterMode = .surface
            e.seed = UInt32.random(in: 0...UInt32.max)
            e.renderMode = .unordered
        }
        layoutEmitters()
        apply(settings: SnowSettings.shared)
    }

    private func layoutEmitters() {
        let top = bounds.maxY
        let size = CGSize(width: bounds.width, height: 1)
        for e in emitters {
            e.frame = bounds; e.emitterSize = size
            e.emitterPosition = CGPoint(x: bounds.midX, y: top + 12)
        }
    }

    // MARK: wind
    private func startWindAnimations() {
        updateWindAnimations()
    }
    
    private func updateWindAnimations() {
        let gustValues = makeNoiseGusts(samples: 64, amp: currentWindAmp, direction: currentWindDirection)
        for e in emitters {
            e.removeAnimation(forKey: "wind")
            let gusts = CAKeyframeAnimation(keyPath: "emitterCells.snow.xAcceleration")
            gusts.values = gustValues
            gusts.duration = 12  // Slightly faster for more dynamic feel
            gusts.calculationMode = .linear
            gusts.repeatCount = .infinity
            e.add(gusts, forKey: "wind")
        }
    }

    private func makeNoiseGusts(samples: Int = 64, amp: CGFloat = 6, direction: SnowSettings.WindDirection = .right) -> [CGFloat] {
        // If amplitude is 0, return no wind
        guard amp > 0 else { return Array(repeating: 0, count: samples) }
        
        // Wind direction multiplier (-1 for left, +1 for right)
        let windMultiplier: CGFloat = direction == .left ? -1.0 : 1.0
        
        // Create simple unidirectional wind with gentle variations
        var gustValues: [CGFloat] = []
        var x: CGFloat = .random(in: 0...100) // random phase
        
        for _ in 0..<samples {
            // Create gentle variation between 0.7 and 1.3 of base wind strength
            let variation = 0.7 + 0.6 * (0.5 + 0.5 * sin(x)) // Results in [0.7, 1.3]
            let windStrength = amp * 12.0 * windMultiplier * variation // Strong consistent wind
            gustValues.append(windStrength)
            x += 0.2
        }
        
        return gustValues
    }


    // MARK: cutoff mask
    func setCutoff(_ points: CGFloat?) { cutoffPoints = points }
    private func updateCutoffMask() {
        guard let layer else { return }
        guard let cutoff = cutoffPoints else { layer.mask = nil; return }
        let grad: CAGradientLayer = (layer.mask as? CAGradientLayer) ?? CAGradientLayer()
        layer.mask = grad
        grad.frame = bounds
        grad.startPoint = CGPoint(x: 0.5, y: 1.0)
        grad.endPoint   = CGPoint(x: 0.5, y: 0.0)
        let h = max(bounds.height, 1)
        let t = min(max(cutoff / h, 0), 1)
        let feather = min(max(18 / h, 0), 1)
        let before = max(t - feather/2, 0)
        let after  = min(t + feather/2, 1)
        grad.colors = [NSColor.white.cgColor, NSColor.white.cgColor, NSColor.clear.cgColor]
        grad.locations = [0, NSNumber(value: Float(before)), NSNumber(value: Float(after))]
    }

    // MARK: shapes + textures
    private func imagesForShape(size: CGFloat, shape: SnowSettings.SnowShape) -> [CGImage] {
        let scale = window?.backingScaleFactor ?? (window?.screen?.backingScaleFactor ?? 2.0)
        func asset(_ name: String) -> CGImage? { TextureCache.shared.image(named: name, size: size, scale: scale) }

        func dot() -> CGImage? {
            TextureCache.shared.renderShape("dot_plain", size: size, scale: scale) { ctx, px in
                ctx.setFillColor(NSColor.white.cgColor)
                let inset = px * 0.08
                let d = px - inset * 2
                ctx.addEllipse(in: CGRect(x: -d/2, y: -d/2, width: d, height: d))
                ctx.fillPath()
            }
        }
        func classic() -> CGImage? {
            TextureCache.shared.renderShape("classic", size: size, scale: scale) { ctx, px in
                let r = px * 0.42
                ctx.setStrokeColor(NSColor.white.cgColor); ctx.setLineWidth(px*0.08)
                for i in 0..<6 {
                    let a = CGFloat(i) * .pi/3
                    ctx.saveGState(); ctx.rotate(by: a)
                    ctx.move(to: .zero); ctx.addLine(to: CGPoint(x: 0, y: r)); ctx.strokePath()
                    ctx.restoreGState()
                }
            }
        }
        func star() -> CGImage? {
            TextureCache.shared.renderShape("star", size: size, scale: scale) { ctx, px in
                let r = px * 0.42
                ctx.setFillColor(NSColor.white.cgColor)
                let p = CGMutablePath(); let spikes = 5
                let inner = r*0.45, outer = r
                for i in 0..<(spikes*2) {
                    let a = CGFloat(i) * .pi/CGFloat(spikes)
                    let rad = (i % 2 == 0) ? outer : inner
                    let pt = CGPoint(x: cos(a)*rad, y: sin(a)*rad)
                    (i == 0) ? p.move(to: pt) : p.addLine(to: pt)
                }
                p.closeSubpath(); ctx.addPath(p); ctx.fillPath()
            }
        }
        func crystal() -> CGImage? {
            TextureCache.shared.renderShape("crystal", size: size, scale: scale) { ctx, px in
                let r = px * 0.4
                ctx.setFillColor(NSColor.white.cgColor)
                let p = CGMutablePath()
                for i in 0..<8 {
                    let a = CGFloat(i) * .pi/4
                    let w = px*0.08, h = r
                    let rect = CGRect(x: -w/2, y: 0, width: w, height: h)
                    ctx.saveGState(); ctx.rotate(by: a); p.addRect(rect); ctx.restoreGState()
                }
                ctx.addPath(p); ctx.fillPath()
            }
        }

        switch shape {
        case .dots:    return [dot()].compactMap { $0 }
        case .classic: return [asset("flake_classic") ?? classic()].compactMap { $0 }
        case .star:    return [asset("flake_star") ?? star()].compactMap { $0 }
        case .crystal: return [asset("flake_crystal") ?? crystal()].compactMap { $0 }
        case .mixed:   return [asset("flake_classic") ?? classic(),
                               asset("flake_star") ?? star(),
                               asset("flake_crystal") ?? crystal(),
                               dot()].compactMap { $0 }
        case .custom:  return [asset("flake_custom") ?? asset("custom") ?? dot()].compactMap { $0 }
        }
    }

    private func makeCell(size: CGFloat, image: CGImage, xAccel: CGFloat, yAccel: CGFloat,
                          alphaSpeed: CGFloat, spinBase: CGFloat, spinRange: CGFloat, spreadDeg: CGFloat,
                          baseWindVel: CGFloat) -> CAEmitterCell {
        let c = CAEmitterCell()
        c.name = "snow"
        c.contents = image
        c.lifetime = 14; c.lifetimeRange = 6
        c.velocity = 24; c.velocityRange = 16
        
        // Set base wind direction through emission angle and initial velocity
        if abs(baseWindVel) > 0.1 {
            // Calculate wind angle based on velocity (handles both positive and negative)
            let windAngle = min(abs(baseWindVel) * 0.015, 0.5) * (baseWindVel < 0 ? -1 : 1)
            c.emissionLongitude = -.pi/2 + windAngle
            
            // Add horizontal velocity component for immediate wind effect
            c.velocityRange = 20  // Increased range for more variation
        } else {
            c.emissionLongitude = -.pi/2
        }
        
        c.yAcceleration = yAccel; c.xAcceleration = xAccel
        let spread = max(0, min(.pi/2, spreadDeg * .pi / 180))
        c.emissionRange = spread
        c.scale = size / 180.0; c.scaleRange = 0.06; c.scaleSpeed = -0.002
        c.alphaRange = 0.15; c.alphaSpeed = Float(alphaSpeed)
        c.spin = spinBase; c.spinRange = spinRange
        return c
    }
}

// Simple CGImage cache
private final class TextureCache {
    static let shared = TextureCache()
    private var cache: [String: CGImage] = [:]

    func image(named name: String, size: CGFloat, scale: CGFloat) -> CGImage? {
        let key = "\(name)-\(Int(size*scale))"
        if let c = cache[key] { return c }
        guard let nsimg = NSImage(named: name) else { return nil }
        let cg = render(nsimg, to: size, scale: scale)
        if let cg { cache[key] = cg }
        return cg
    }

    func render(_ nsimg: NSImage, to size: CGFloat, scale: CGFloat) -> CGImage? {
        let px = max(1, size * scale)
        let img = NSImage(size: NSSize(width: px, height: px))
        img.lockFocus(); nsimg.draw(in: NSRect(x: 0, y: 0, width: px, height: px)); img.unlockFocus()
        return img.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }

    func renderShape(_ name: String, size: CGFloat, scale: CGFloat, draw: (CGContext, CGFloat)->Void) -> CGImage? {
        let key = "\(name)-\(Int(size*scale))"
        if let c = cache[key] { return c }
        let px = max(1, size * scale)
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(px), pixelsHigh: Int(px),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ), let gctx = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
        let ctx = gctx.cgContext
        ctx.clear(CGRect(x: 0, y: 0, width: px, height: px))
        ctx.saveGState(); ctx.translateBy(x: px/2, y: px/2)
        draw(ctx, px)
        ctx.restoreGState()
        guard let cg = rep.cgImage else { return nil }
        cache[key] = cg
        return cg
    }
}
