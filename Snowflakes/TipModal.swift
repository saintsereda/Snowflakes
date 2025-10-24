//
//  TipModal.swift
//  Snowflakes
//
//  Created by Andrew Sereda on 24.10.2025.
//  Two-piece Liquid Glass that separate on appear
//

import Cocoa
import SwiftUI
import Combine

// MARK: - Presentation Model

@MainActor
final class TipPresentation: ObservableObject {
    @Published var isVisible: Bool = false
}

// MARK: - Modal Controller

final class TipModal {
    private static let hasShownTipKey = "HasShownFirstLaunchTip"
    private static var activeModal: TipModal? // Keep strong reference
    
    private var window: NSWindow?
    private var dismissTimer: Timer?
    private var hosting: NSHostingController<TipView>?
    private let presentation = TipPresentation()
    
    // Motion timings
    private let showAnimation = Animation.smooth(duration: 0.22)
    private let hideDuration: TimeInterval = 0.12
    
    // Size tuned for two glass elements
    private let windowSize = NSSize(width: 360, height: 88)
    
    static func showIfNeeded(below statusItem: NSStatusItem) {
        guard !UserDefaults.standard.bool(forKey: hasShownTipKey) else {
            print("✅ Tip already shown, skipping")
            return
        }
        print("🎯 Showing tip modal for first time")
        let modal = TipModal()
        activeModal = modal
        modal.show(below: statusItem)
        UserDefaults.standard.set(true, forKey: hasShownTipKey)
    }
    
    private func show(below statusItem: NSStatusItem) {
        guard let button = statusItem.button,
              let buttonWindow = button.window else {
            print("❌ Could not get status bar button")
            return
        }
        
        // Button position in screen coordinates
        let buttonFrame = button.convert(button.bounds, to: nil)
        let buttonScreenFrame = buttonWindow.convertToScreen(buttonFrame)
        print("📍 Status bar position: \(buttonScreenFrame)")
        
        // SwiftUI content
        let tipView = TipView(presentation: presentation, onDismiss: { [weak self] in
            print("👆 OK button clicked")
            self?.dismiss()
        })
        
        // Host
        let hosting = NSHostingController(rootView: tipView)
        hosting.view.frame = NSRect(origin: .zero, size: windowSize)
        
        // Window below status item
        let windowX = buttonScreenFrame.midX - (windowSize.width / 2)
        let windowY = buttonScreenFrame.minY - (windowSize.height - 12)
        
        let window = NSWindow(
            contentRect: NSRect(x: windowX, y: windowY, width: windowSize.width, height: windowSize.height),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false              // let glass own the look
        window.level = .statusBar
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.isReleasedWhenClosed = false
        window.contentViewController = hosting
        
        self.window = window
        self.hosting = hosting
        
        print("🪟 Showing tip window at: \(window.frame)")
        window.makeKeyAndOrderFront(nil)
        
        // Animate IN on next runloop tick
        DispatchQueue.main.async {
            withAnimation(self.showAnimation) {
                self.presentation.isVisible = true
            }
        }
        
        // Auto-dismiss after 10 seconds
        print("⏱️ Starting 10 second timer")
        dismissTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
            print("⏰ Timer fired - auto dismissing")
            self?.dismiss()
        }
        if let dismissTimer { RunLoop.main.add(dismissTimer, forMode: .common) }
    }
    
    private func dismiss() {
        print("👋 Dismissing tip modal")
        if let timer = dismissTimer {
            timer.invalidate()
            dismissTimer = nil
        }
        
        // Animate OUT first (short, no bounce)
        withAnimation(.easeInOut(duration: hideDuration)) {
            presentation.isVisible = false
        }
        
        // Close after the animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + hideDuration) { [weak self] in
            guard let self = self, let window = self.window else {
                TipModal.activeModal = nil
                print("✅ Dismiss complete (no window)")
                return
            }
            print("🚪 Closing window - isVisible: \(window.isVisible)")
            window.orderOut(nil)
            window.close()
            self.window = nil
            self.hosting = nil
            TipModal.activeModal = nil
            print("✅ Dismiss complete")
        }
    }
}

// MARK: - SwiftUI View

// Reusable capsule glass button (macOS 15+)
struct GlassCapsuleButton: View {
    let title: String
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.body)
                .foregroundStyle(.primary)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .frame(minWidth: 44, alignment: .center)
                .glassEffect(in: .capsule)
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.12), value: isHovering)
        .keyboardShortcut(.defaultAction)
        .accessibilityLabel(Text(title))
    }
}

struct MaterialCapsuleButton: View {
    let title: String
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .frame(minWidth: 44, alignment: .center)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.10), lineWidth: 1))
                .contentShape(Capsule())
                .compositingGroup()
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovering ? 1.03 : 1.0)
        .animation(.easeOut(duration: 0.12), value: isHovering)
        .onHover { isHovering = $0 }
        .keyboardShortcut(.defaultAction)
    }
}


struct TipView: View {
    @ObservedObject var presentation: TipPresentation
    let onDismiss: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHoveringOK = false

    // animate this for BOTH: the container blend AND the physical layout
    @State private var splitSpacing: CGFloat = -40

    // motion
    private let appearOffsetY: CGFloat = -4
    private let appearScale: CGFloat = 0.94

    // separation targets & timing
    private let targetSpacing: CGFloat = 8
    private let splitDelay: Double = 0.16
    private let splitAnim = Animation.easeIn(duration: 0.33)

    var body: some View {
        ZStack {
            Color.clear

            if #available(macOS 15.0, *) {
                // One container for BOTH shapes; use the SAME spacing value for container & HStack
                GlassEffectContainer(spacing: splitSpacing) {
                    HStack(spacing: splitSpacing) {
                        // LEFT: pill (icon + text)
                        HStack(spacing: 6) {
                            Image(systemName: "snowflake")
                                .font(.title3)
                                .foregroundStyle(.primary)
                            Text("App icon is up here")
                                .font(.body)
                                .foregroundStyle(.primary)
                        }
                        .padding(.leading, 12)
                        .padding(.trailing, 16)
                        .padding(.vertical, 12)
                        .glassEffect(in: .capsule)

                        // RIGHT: OK chip
                        GlassCapsuleButton(title: "Okay", action: onDismiss)
                    }
                }
                .blur(radius: presentation.isVisible ? 0 : 6)
                .padding(.horizontal, 12)
                // (animate spacing value changes)
                .animation(splitAnim, value: splitSpacing)
                // Drive the "connect → delay → separate" sequence
                .onChange(of: presentation.isVisible) { _, visible in
                    if visible {
                        // 1) connect immediately
                        splitSpacing = 0
                        // 2) after a small delay, separate to 16pt
                        let delay = reduceMotion ? 0 : splitDelay
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                            withAnimation(splitAnim) { splitSpacing = targetSpacing }
                        }
                    } else {
                        // on dismiss, reunite them before/while fading out
                        withAnimation(.easeOut(duration: 0.33)) { splitSpacing = -50 }
                    }
                }
                .onAppear {
                    // initial state: connected; if already visible, schedule split
                    splitSpacing = presentation.isVisible ? 0 : 0
                    if presentation.isVisible && !reduceMotion {
                        DispatchQueue.main.asyncAfter(deadline: .now() + splitDelay) {
                            withAnimation(splitAnim) { splitSpacing = targetSpacing }
                        }
                    }
                }
            } else {
                // Fallback (pre-macOS 15): animate HStack spacing; use materials
                HStack(spacing: splitSpacing) {
                    HStack(spacing: 8) {
                        Image(systemName: "snowflake")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text("App icon is up here")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().strokeBorder(.white.opacity(0.10), lineWidth: 1))

                    MaterialCapsuleButton(title: "Okay", action: onDismiss)
                }
                .padding(.horizontal, 12)
                .animation(splitAnim, value: splitSpacing)
                .onChange(of: presentation.isVisible) { _, visible in
                    if visible {
                        splitSpacing = 0
                        DispatchQueue.main.asyncAfter(deadline: .now() + splitDelay) {
                            withAnimation(splitAnim) { splitSpacing = targetSpacing }
                        }
                    } else {
                        withAnimation(.smooth(duration: 0.16)) { splitSpacing = 0 }
                    }
                }
                .onAppear { splitSpacing = 0 }
            }
        }
        .padding(.vertical, 14)
        .frame(width: 360, height: 88)
        // global appear/disappear motion
        .scaleEffect(reduceMotion ? 1.0 : (presentation.isVisible ? 1.0 : appearScale), anchor: .top)
        .opacity(presentation.isVisible ? 1 : 0)
        .offset(y: reduceMotion ? 0 : (presentation.isVisible ? 0 : appearOffsetY))
        .contentTransition(.opacity)
        .animation(reduceMotion ? .default.speed(2) : .smooth(duration: 0.22), value: presentation.isVisible)
    }
}




// MARK: - Preview

struct TipView_Previews: PreviewProvider {
    static var previews: some View {
        let p = TipPresentation()
        p.isVisible = true
        return TipView(presentation: p, onDismiss: {})
            .frame(width: 280, height: 70)
            .padding(50)
            .background(Color.accentColor)
    }
}
