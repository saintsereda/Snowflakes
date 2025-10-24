//
//  SnowView.swift - Enhanced with drifting/zigzag control
//  Snowflakes
//
//  Created by Andrew Sereda on 22.10.2025.
//  Enhanced with natural zigzag motion control via sine wave acceleration
//

import Cocoa
import QuartzCore

final class SnowView: NSView {
    override var wantsUpdateLayer: Bool { true }

    // Mask cutoff
    private var cutoffPoints: CGFloat? { didSet { updateCutoffMask() } }
    private let cutoffFeather: CGFloat = 18

    // 3 emitters for parallax
    private var emitters: [CAEmitterLayer] = []
    private var currentWindAmp: CGFloat = 6.0
    private var currentWindDirection: SnowSettings.WindDirection = .right
    private var currentDrifting: CGFloat = 1.0
    private var currentBlurEnabled: Bool = false  // NEW: Track blur state

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        let container = CALayer()
        container.masksToBounds = false
        self.layer = container

        addParallaxLayers()
        setupAllEmitters()
        startWindAnimations()
        startDriftingAnimations()  // NEW: Start drifting animations
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
            let aSpeed   = base.alphaSpeed
            
            // Wind direction multiplier
            let windMultiplier: CGFloat = settings.windDirection == .left ? -1.0 : 1.0
            
            // Wind effects
            let baseWindVel = settings.windAmplitude * 12.0 * windMultiplier
            let baseXAccel = settings.windAmplitude * 20.0 * windMultiplier

            let imgs = imagesForShape(size: sizeBase, shape: settings.shape)
            let img0 = imgs.first!
            let img1 = imgs.indices.contains(1) ? imgs[1] : img0
            let img2 = imgs.indices.contains(2) ? imgs[2] : img0

            // Create cell variants
            var allCells: [CAEmitterCell] = []
            
            let normalFlakes = createNormalFlakes(
                sizeBase: sizeBase, images: [img0, img1, img2],
                xAccel: baseXAccel, yAccel: yAccel, aSpeed: aSpeed,
                settings: settings, baseWindVel: baseWindVel
            )
            
            let disappearingFlakes = createDisappearingFlakes(
                sizeBase: sizeBase, images: [img0, img1, img2],
                xAccel: baseXAccel, yAccel: yAccel, aSpeed: aSpeed,
                settings: settings, baseWindVel: baseWindVel,
                baseTotal: base.birthTotal
            )
            
            allCells.append(contentsOf: normalFlakes)
            allCells.append(contentsOf: disappearingFlakes)
            
            return allCells
        }

        guard emitters.count == 3 else { return }
        emitters[0].emitterCells = cells(for: settings.far)
        emitters[1].emitterCells = cells(for: settings.mid)
        emitters[2].emitterCells = cells(for: settings.near)

        // Update wind animations if changed
        if currentWindAmp != settings.windAmplitude || currentWindDirection != settings.windDirection {
            currentWindAmp = settings.windAmplitude
            currentWindDirection = settings.windDirection
            updateWindAnimations()
        }
        
        // Update drifting animations if changed
        if currentDrifting != settings.drifting {
            currentDrifting = settings.drifting
            updateDriftingAnimations()
        }
        
        // NEW: Update blur if changed
        if currentBlurEnabled != settings.blurEnabled {
            currentBlurEnabled = settings.blurEnabled
            updateBlur()
        }

        switch settings.cutoff {
        case .full: setCutoff(nil)
        case .small150:
            let scale = window?.backingScaleFactor ?? (window?.screen?.backingScaleFactor ?? 2.0)
            setCutoff(150.0 / scale)
        }
    }

    // MARK: - Cell Creation Methods
    
    private func createNormalFlakes(sizeBase: CGFloat, images: [CGImage],
                                   xAccel: CGFloat, yAccel: CGFloat, aSpeed: CGFloat,
                                   settings: SnowSettings, baseWindVel: CGFloat) -> [CAEmitterCell] {
        
        let img0 = images[0]
        let img1 = images.indices.contains(1) ? images[1] : img0
        let img2 = images.indices.contains(2) ? images[2] : img0
        
        let neutral = makeCell(
            size: sizeBase, image: img0, xAccel: xAccel, yAccel: yAccel,
            alphaSpeed: aSpeed, spinBase: settings.spinBase, spinRange: settings.spinRange,
            spreadDeg: settings.emissionSpreadDeg, baseWindVel: baseWindVel,
            lifetime: 14, lifetimeRange: 6, cellType: .normal,
            drifting: settings.drifting
        )
        
        let left = makeCell(
            size: sizeBase - 4, image: img1, xAccel: xAccel * 0.8, yAccel: yAccel,
            alphaSpeed: aSpeed, spinBase: settings.spinBase, spinRange: settings.spinRange,
            spreadDeg: settings.emissionSpreadDeg, baseWindVel: baseWindVel,
            lifetime: 14, lifetimeRange: 6, cellType: .normal,
            drifting: settings.drifting
        )
        
        let right = makeCell(
            size: sizeBase + 6, image: img2, xAccel: xAccel * 1.2, yAccel: yAccel,
            alphaSpeed: aSpeed, spinBase: settings.spinBase, spinRange: settings.spinRange,
            spreadDeg: settings.emissionSpreadDeg, baseWindVel: baseWindVel,
            lifetime: 14, lifetimeRange: 6, cellType: .normal,
            drifting: settings.drifting
        )
        
        let normalRatio = calculateNormalFlakeRatio(intensity: settings.intensity)
        let totalRate = Float(settings.intensity) * 32.0
        let normalRate = totalRate * normalRatio
        
        neutral.birthRate = normalRate * 0.5
        left.birthRate = normalRate * 0.25
        right.birthRate = normalRate * 0.25
        
        return [neutral, left, right]
    }
    
    private func createDisappearingFlakes(sizeBase: CGFloat, images: [CGImage],
                                         xAccel: CGFloat, yAccel: CGFloat, aSpeed: CGFloat,
                                         settings: SnowSettings, baseWindVel: CGFloat,
                                         baseTotal: Float) -> [CAEmitterCell] {
        
        let img0 = images[0]
        let img1 = images.indices.contains(1) ? images[1] : img0
        let img2 = images.indices.contains(2) ? images[2] : img0
        
        var disappearingCells: [CAEmitterCell] = []
        
        let disappearanceRatio = calculateDisappearanceRatio(intensity: settings.intensity)
        let totalRate = Float(settings.intensity) * baseTotal
        let disappearingRate = totalRate * disappearanceRatio
        
        let earlyDisappearer = makeCell(
            size: sizeBase, image: img0, xAccel: xAccel, yAccel: yAccel,
            alphaSpeed: aSpeed * 2.0, spinBase: settings.spinBase, spinRange: settings.spinRange,
            spreadDeg: settings.emissionSpreadDeg, baseWindVel: baseWindVel,
            lifetime: 3, lifetimeRange: 2, cellType: .earlyDisappearing,
            drifting: settings.drifting
        )
        earlyDisappearer.birthRate = disappearingRate * 0.4
        disappearingCells.append(earlyDisappearer)
        
        let midDisappearer = makeCell(
            size: sizeBase - 2, image: img1, xAccel: xAccel * 0.9, yAccel: yAccel,
            alphaSpeed: aSpeed * 1.5, spinBase: settings.spinBase, spinRange: settings.spinRange,
            spreadDeg: settings.emissionSpreadDeg, baseWindVel: baseWindVel,
            lifetime: 5.5, lifetimeRange: 2.5, cellType: .midDisappearing,
            drifting: settings.drifting
        )
        midDisappearer.birthRate = disappearingRate * 0.4
        disappearingCells.append(midDisappearer)
        
        if settings.intensity > 1.5 {
            let quickDisappearer = makeCell(
                size: sizeBase + 2, image: img2, xAccel: xAccel * 1.1, yAccel: yAccel,
                alphaSpeed: aSpeed * 3.0, spinBase: settings.spinBase, spinRange: settings.spinRange,
                spreadDeg: settings.emissionSpreadDeg, baseWindVel: baseWindVel,
                lifetime: 2, lifetimeRange: 2, cellType: .quickDisappearing,
                drifting: settings.drifting
            )
            quickDisappearer.birthRate = disappearingRate * 0.2
            disappearingCells.append(quickDisappearer)
        }
        
        return disappearingCells
    }

    // MARK: - Emitter Setup
    
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
            e.emitterShape = .line
            e.emitterMode = .volume
            e.seed = UInt32.random(in: 0...UInt32.max)
            e.renderMode = .unordered
        }
        layoutEmitters()
        apply(settings: SnowSettings.shared)
    }

    private func layoutEmitters() {
        let top = bounds.maxY + 48
        let extraWidth: CGFloat = 300
        let emissionWidth = bounds.width + (extraWidth * 2)
        let size = CGSize(width: emissionWidth, height: 1)
        
        for e in emitters {
            e.frame = bounds
            e.emitterSize = size
            e.emitterPosition = CGPoint(x: bounds.midX, y: top)
        }
    }

    // MARK: - Wind Animations
    
    private func startWindAnimations() {
        updateWindAnimations()
    }
    
    private func updateWindAnimations() {
        let gustValues = makeNoiseGusts(samples: 64, amp: currentWindAmp, direction: currentWindDirection)
        for e in emitters {
            e.removeAnimation(forKey: "wind")
            let gusts = CAKeyframeAnimation(keyPath: "emitterCells.snow.xAcceleration")
            gusts.values = gustValues
            gusts.duration = 12
            gusts.calculationMode = .linear
            gusts.repeatCount = .infinity
            e.add(gusts, forKey: "wind")
        }
    }

    private func makeNoiseGusts(samples: Int = 64, amp: CGFloat = 6, direction: SnowSettings.WindDirection = .right) -> [CGFloat] {
        guard amp > 0 else { return Array(repeating: 0, count: samples) }
        
        let windMultiplier: CGFloat = direction == .left ? -1.0 : 1.0
        var gustValues: [CGFloat] = []
        var x: CGFloat = .random(in: 0...100)
        
        for _ in 0..<samples {
            let variation = 0.5 + 1.0 * (0.5 + 0.5 * sin(x))
            let windStrength = amp * 15.0 * windMultiplier * variation
            gustValues.append(windStrength)
            x += 0.2
        }
        
        return gustValues
    }

    // MARK: - NEW: Drifting/Zigzag Animations
    
    private func startDriftingAnimations() {
        updateDriftingAnimations()
    }
    
    private func updateDriftingAnimations() {
        let driftValues = makeDriftingPattern(samples: 80, amplitude: currentDrifting)
        
        for (index, e) in emitters.enumerated() {
            e.removeAnimation(forKey: "drifting")
            
            // Only apply drifting if amplitude > 0
            guard currentDrifting > 0.01 else { continue }
            
            let drift = CAKeyframeAnimation(keyPath: "emitterCells.snow.xAcceleration")
            
            // Add slight phase shift between layers for more natural effect
            let phaseShift = Double(index) * 0.3
            drift.values = driftValues
            drift.duration = 8.0 + phaseShift  // Slightly different timing per layer
            drift.calculationMode = .linear
            drift.repeatCount = .infinity
            drift.isAdditive = true  // This makes it ADD to the wind acceleration
            
            e.add(drift, forKey: "drifting")
        }
    }
    
    private func makeDriftingPattern(samples: Int = 80, amplitude: CGFloat = 1.0) -> [CGFloat] {
        guard amplitude > 0 else { return Array(repeating: 0, count: samples) }
        
        var driftValues: [CGFloat] = []
        
        // Create smooth sine wave pattern for natural zigzag
        // amplitude: 0 = no drift, 1 = gentle sway, 3 = dramatic zigzag
        let baseStrength: CGFloat = 8.0 * amplitude  // Base drift strength
        
        for i in 0..<samples {
            let t = CGFloat(i) / CGFloat(samples)
            let angle = t * 2.0 * .pi  // One complete cycle
            
            // Sine wave creates smooth back-and-forth motion
            let drift = sin(angle) * baseStrength
            driftValues.append(drift)
        }
        
        return driftValues
    }

    // MARK: - NEW: Blur Effect
    
    private func updateBlur() {
        guard let container = layer else { return }
        
        if currentBlurEnabled {
            // Create Gaussian blur filter
            let blur = CIFilter(name: "CIGaussianBlur")
            blur?.name = "snowBlur"
            blur?.setValue(1.5, forKey: kCIInputRadiusKey)  // Subtle blur radius
            
            container.filters = [blur].compactMap { $0 }
            container.shouldRasterize = false  // Keep GPU rendering
        } else {
            // Remove blur
            container.filters = nil
        }
    }

    // MARK: - Cutoff Mask
    
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

    // MARK: - Shapes & Textures
    
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

    // MARK: - Cell Type Enum
    
    private enum CellType {
        case normal
        case earlyDisappearing
        case midDisappearing
        case quickDisappearing
    }

    // MARK: - Cell Creation with Drifting Support
    
    private func makeCell(size: CGFloat, image: CGImage, xAccel: CGFloat, yAccel: CGFloat,
                          alphaSpeed: CGFloat, spinBase: CGFloat, spinRange: CGFloat, spreadDeg: CGFloat,
                          baseWindVel: CGFloat, lifetime: CGFloat, lifetimeRange: CGFloat,
                          cellType: CellType, drifting: CGFloat) -> CAEmitterCell {
        let c = CAEmitterCell()
        c.name = "snow"
        c.contents = image
        
        c.lifetime = Float(lifetime)
        c.lifetimeRange = Float(lifetimeRange)
        
        // FIXED: Separate wind and no-wind behavior (from previous fix)
        if abs(baseWindVel) > 0.1 {
            c.velocity = 20
            c.velocityRange = 16
            
            let windAngle = min(abs(baseWindVel) * 0.02, 0.8) * (baseWindVel < 0 ? -1 : 1)
            c.emissionLongitude = -.pi/2 + windAngle
            
            let baseSpread = max(0, min(.pi * 0.6, spreadDeg * .pi / 180))
            c.emissionRange = max(baseSpread, .pi * 0.12)
        } else if drifting > 0.01 {
            // NEW: With drifting but no wind - allow slight initial velocity for natural motion
            c.velocity = 5 * drifting
            c.velocityRange = 3 * drifting
            c.emissionLongitude = -.pi/2
            c.emissionRange = .pi * 0.05
        } else {
            // No wind and no drifting - straight down
            c.velocity = 0
            c.velocityRange = 0
            c.emissionLongitude = -.pi/2
            c.emissionRange = .pi * 0.03
        }
        
        c.yAcceleration = yAccel
        c.xAcceleration = xAccel
        
        let baseScale = size / 180.0
        c.scale = baseScale
        c.scaleRange = min(0.1, baseScale * 0.25)
        c.scaleSpeed = -0.002
        
        switch cellType {
        case .normal:
            c.alphaRange = 0.15
            c.alphaSpeed = Float(alphaSpeed)
        case .earlyDisappearing:
            c.alphaRange = 0.25
            c.alphaSpeed = Float(alphaSpeed * 1.5)
        case .midDisappearing:
            c.alphaRange = 0.2
            c.alphaSpeed = Float(alphaSpeed * 1.2)
        case .quickDisappearing:
            c.alphaRange = 0.3
            c.alphaSpeed = Float(alphaSpeed * 2.0)
        }
        
        c.spin = spinBase
        c.spinRange = spinRange
        
        return c
    }
    
    private func calculateNormalFlakeRatio(intensity: CGFloat) -> Float {
        let clampedIntensity = max(0.1, min(3.0, intensity))
        let normalizedIntensity = (clampedIntensity - 0.1) / 2.9
        return 0.8 - (0.2 * Float(normalizedIntensity))
    }
    
    private func calculateDisappearanceRatio(intensity: CGFloat) -> Float {
        let clampedIntensity = max(0.1, min(3.0, intensity))
        let normalizedIntensity = (clampedIntensity - 0.1) / 2.9
        return 0.2 + (0.2 * Float(normalizedIntensity))
    }
}

// MARK: - Texture Cache

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
