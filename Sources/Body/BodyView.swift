import RealityKit
import SwiftUI

enum Pick {
    case point(String)
    case part(String)
}

/// Full-bleed 3D body: drag to spin, pinch to zoom, tap a part or point, double-tap to reset.
struct BodyView: View {
    let scene: BodyScene
    var compact = false
    var onPick: (Pick) -> Void = { _ in }

    @Environment(Settings.self) private var settings
    @State private var hintVisible = true
    @State private var dragStart: (yaw: Float, pitch: Float)?
    @State private var panStart: (x: Float, y: Float)?
    @State private var zoomStart: Float?

    var body: some View {
        ZStack {
            (settings.whiteBackground ? Color.white : Color(hex: "#DADCE2"))
            RealityView { content in
                content.camera = .virtual
                scene.root.removeFromParent()
                content.add(scene.root)
                scene.subscription = content.subscribe(to: SceneEvents.Update.self) { event in
                    MainActor.assumeIsolated { scene.update(dt: Float(event.deltaTime)) }
                }
            }
            .gesture(PanRecognizer(touches: 1, onChange: rotate, onEnd: { dragStart = nil }))
            .gesture(PanRecognizer(touches: 2, onChange: move, onEnd: { panStart = nil }))
            .gesture(PinchRecognizer(onChange: zoom, onEnd: { zoomStart = nil }))
            .gesture(SpatialTapGesture(count: 2).onEnded { _ in scene.resetView() })
            .gesture(tap)

            if !compact {
                rail
                if hintVisible {
                    Text(settings.t("1 finger: spin · 2 fingers: move · pinch: zoom · tap a part", "单指旋转 · 双指移动 · 捏合缩放 · 点击部位"))
                        .font(.footnote)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Color(hex: "#2B2250").opacity(0.85), in: .capsule)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .padding(.bottom, 14)
                        .allowsHitTesting(false)
                }
            }
        }
        .onAppear { if !settings.autoRotate || UIAccessibility.isReduceMotionEnabled { scene.touched = true } }
    }

    private var rail: some View {
        VStack(spacing: 10) {
            RailButton(symbol: "house", label: settings.t("Reset view", "重置视角")) { scene.resetView() }
            RailButton(symbol: "circle.lefthalf.filled", label: settings.t("Background", "背景")) { settings.whiteBackground.toggle() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .padding(12)
    }

    private func firstTouch() {
        scene.touched = true
        hintVisible = false
    }

    /// one finger: spin and tilt
    private func rotate(_ t: CGPoint) {
        firstTouch()
        let start = dragStart ?? (scene.yaw, scene.pitch)
        dragStart = start
        scene.goalYaw = nil
        scene.yaw = start.yaw + Float(t.x) * 0.008
        scene.pitch = max(-0.9, min(0.9, start.pitch + Float(t.y) * 0.008))
    }

    /// two fingers: slide the whole body, scaled so it tracks the fingers at any zoom
    private func move(_ t: CGPoint) {
        firstTouch()
        let start = panStart ?? (scene.panX, scene.goalFocusY)
        panStart = start
        let k = scene.distance * 0.0012
        scene.panX = max(-2, min(2, start.x - Float(t.x) * k))
        scene.goalFocusY = max(-1.8, min(1.8, start.y + Float(t.y) * k))
        scene.focusY = scene.goalFocusY
    }

    private func zoom(_ scale: CGFloat) {
        firstTouch()
        let start = zoomStart ?? scene.goalDistance
        zoomStart = start
        let next = max(1.2, min(9, start / Float(scale)))
        scene.goalDistance = next
        scene.distance = next
    }

    private var tap: some Gesture {
        SpatialTapGesture()
            .targetedToAnyEntity()
            .onEnded { value in
                firstTouch()
                let name = value.entity.name
                if name.hasPrefix("point:") {
                    onPick(.point(String(name.dropFirst(6))))
                } else if !name.isEmpty {
                    onPick(.part(name))
                }
            }
    }
}

struct RailButton: View {
    let symbol: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color(hex: "#2B2250"))
                .frame(width: 44, height: 44)
                .background(.white.opacity(0.8), in: .circle)
        }
        .accessibilityLabel(label)
    }
}

/// UIKit pan with an exact finger count — SwiftUI's drag can't tell one finger from two.
struct PanRecognizer: UIGestureRecognizerRepresentable {
    let touches: Int
    let onChange: (CGPoint) -> Void
    let onEnd: () -> Void

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let g = UIPanGestureRecognizer()
        g.minimumNumberOfTouches = touches
        g.maximumNumberOfTouches = touches
        g.delegate = context.coordinator
        return g
    }

    func handleUIGestureRecognizerAction(_ g: UIPanGestureRecognizer, context: Context) {
        switch g.state {
        case .changed: onChange(g.translation(in: g.view))
        case .ended, .cancelled, .failed: onEnd()
        default: break
        }
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Simultaneous { Simultaneous() }
}

struct PinchRecognizer: UIGestureRecognizerRepresentable {
    let onChange: (CGFloat) -> Void
    let onEnd: () -> Void

    func makeUIGestureRecognizer(context: Context) -> UIPinchGestureRecognizer {
        let g = UIPinchGestureRecognizer()
        g.delegate = context.coordinator
        return g
    }

    func handleUIGestureRecognizerAction(_ g: UIPinchGestureRecognizer, context: Context) {
        switch g.state {
        case .changed: onChange(g.scale)
        case .ended, .cancelled, .failed: onEnd()
        default: break
        }
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Simultaneous { Simultaneous() }
}

/// lets two-finger pan and pinch run together
final class Simultaneous: NSObject, UIGestureRecognizerDelegate {
    func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
}
