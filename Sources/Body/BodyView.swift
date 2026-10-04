import RealityKit
import SwiftUI

enum Pick {
    case point(String)
    case part(String)
    case empty
}

/// Full-bleed 3D body: one finger moves it, two fingers turn it, pinch zooms, tap a part or point (again to let go).
struct BodyView: View {
    let scene: BodyScene
    var compact = false
    /// acupuncture: a rail switch for the meridian lines
    var meridians: Binding<Bool>? = nil
    /// the reset button puts the whole page back as it opened, not just the camera
    var onReset: (() -> Void)? = nil
    var onSearch: (() -> Void)? = nil
    /// every rendered frame, with the view's size (a callout follows the body)
    var onFrame: ((CGSize) -> Void)? = nil
    var onPick: (Pick) -> Void = { _ in }

    @Environment(Settings.self) private var settings
    @State private var hintVisible = true
    @State private var dragStart: (yaw: Float, pitch: Float)?
    @State private var panStart: (x: Float, y: Float)?
    @State private var zoomStart: Float?
    private let frame = FrameBox()

    var body: some View {
        ZStack {
            (settings.whiteBackground ? Color.white : Color(light: "#DADCE2", dark: "#2B2D33"))
                .ignoresSafeArea(.container, edges: compact ? [] : .bottom)
            RealityView { content in
                content.camera = .virtual
                scene.root.removeFromParent()
                content.add(scene.root)
                scene.subscription = content.subscribe(to: SceneEvents.Update.self) { event in
                    MainActor.assumeIsolated {
                        scene.update(dt: Float(event.deltaTime))
                        onFrame?(frame.size)
                    }
                }
            }
            .onGeometryChange(for: CGSize.self) { $0.size } action: { frame.size = $0 }
            // one finger slides the body around, two fingers turn it, pinch zooms
            .gesture(PanRecognizer(touches: 1, onChange: move, onEnd: { panStart = nil }))
            .gesture(PanRecognizer(touches: 2, onChange: rotate, onEnd: { dragStart = nil }))
            .gesture(PinchRecognizer(onChange: zoom, onEnd: { zoomStart = nil }))
            .gesture(TapRecognizer { point, size in
                firstTouch()
                guard let name = scene.pick(at: point, in: size), !name.isEmpty else { onPick(.empty); return }
                onPick(name.hasPrefix("point:") ? .point(String(name.dropFirst(6))) : .part(name))
            })
            .ignoresSafeArea(.container, edges: compact ? [] : .bottom)

            if !compact {
                rail
                if hintVisible {
                    Label(settings.t("1 finger move · 2 fingers turn · pinch zoom", "单指移动 · 双指旋转 · 捏合缩放"), systemImage: "hand.draw")
                        .font(.footnote.weight(.medium))
                        .padding(.horizontal, Space.l).padding(.vertical, Space.s)
                        .background(.regularMaterial, in: .capsule)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .padding(.bottom, Space.m)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
        }
        .animation(.easeOut(duration: 0.3), value: hintVisible)
        .onAppear { if !settings.autoRotate || UIAccessibility.isReduceMotionEnabled { scene.touched = true } }
    }

    private var rail: some View {
        VStack(spacing: 10) {
            if let onReset {
                RailButton(symbol: "arrow.counterclockwise", label: settings.t("Reset everything", "全部重置"), action: onReset)
            } else {
                RailButton(symbol: "arrow.counterclockwise", label: settings.t("Reset view", "重置视角")) { scene.resetView() }
            }
            if let onSearch {
                RailButton(symbol: "magnifyingglass", label: settings.t("Find a part", "查找部位"), action: onSearch)
            }
            if let meridians {
                RailButton(symbol: "point.bottomleft.forward.to.point.topright.scurvepath",
                           label: meridians.wrappedValue ? settings.t("Hide meridians", "隐藏经络线") : settings.t("Show meridians", "显示经络线"),
                           on: meridians.wrappedValue) { meridians.wrappedValue.toggle() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .padding(12)
    }

    private func firstTouch() {
        scene.touched = true
        hintVisible = false
    }

    /// two fingers: spin and tilt
    private func rotate(_ t: CGPoint) {
        firstTouch()
        let start = dragStart ?? (scene.yaw, scene.pitch)
        dragStart = start
        scene.goalYaw = nil
        scene.yaw = start.yaw + Float(t.x) * 0.008
        scene.pitch = max(-0.9, min(0.9, start.pitch + Float(t.y) * 0.008))
    }

    /// one finger: slide the whole body, scaled so it tracks the finger at any zoom
    private func move(_ t: CGPoint) {
        firstTouch()
        let start = panStart ?? (scene.panX, scene.goalFocusY)
        panStart = start
        let k = scene.distance * 0.0012
        scene.panX = max(-2, min(2, start.x - Float(t.x) * k))
        scene.goalPanX = scene.panX
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

}

struct RailButton: View {
    let symbol: String
    let label: String
    var on: Bool? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(on == true ? Color.brand : .primary)
                .frame(width: minTap, height: minTap)
                .background(.regularMaterial, in: .circle)
                .overlay(Circle().strokeBorder(Color.brand.opacity(on == true ? 0.7 : 0), lineWidth: 1.5))
                // off: struck through, so the state reads without colour
                .overlay {
                    if on == false {
                        Capsule().fill(.primary).frame(width: 2, height: 26).rotationEffect(.degrees(-45))
                    }
                }
                .shadow(color: .black.opacity(0.12), radius: 4, y: 1)
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(label)
        .accessibilityAddTraits(on == true ? .isSelected : [])
        .sensoryFeedback(.impact(weight: .light), trigger: on ?? false)
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

/// One finger down/move/up with no delay; a second finger cancels it so two-finger turn and pinch stay free.
struct SingleTouchRecognizer: UIGestureRecognizerRepresentable {
    let onBegan: (CGPoint, CGSize) -> Void
    let onMoved: (CGPoint, CGSize) -> Void
    let onEnded: (CGPoint, CGSize) -> Void

    final class Coordinator: Simultaneous {
        var active = false
    }

    func makeUIGestureRecognizer(context: Context) -> UILongPressGestureRecognizer {
        let g = UILongPressGestureRecognizer()
        g.minimumPressDuration = 0
        g.allowableMovement = .greatestFiniteMagnitude
        g.numberOfTouchesRequired = 1
        g.delegate = context.coordinator
        return g
    }

    func handleUIGestureRecognizerAction(_ g: UILongPressGestureRecognizer, context: Context) {
        guard let v = g.view else { return }
        let c = context.coordinator, pt = g.location(in: v), size = v.bounds.size
        switch g.state {
        case .began:
            c.active = true
            onBegan(pt, size)
        case .changed:
            if g.numberOfTouches > 1 { c.active = false; onEnded(pt, size) }
            else if c.active { onMoved(pt, size) }
        case .ended, .cancelled, .failed:
            if c.active { c.active = false; onEnded(pt, size) }
        default: break
        }
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }
}

/// the 3D view's current size, read from the render loop
final class FrameBox { var size = CGSize.zero }

/// A tap, hit-tested by the scene itself (a SwiftUI tap on entities dropped taps once a part was selected).
struct TapRecognizer: UIGestureRecognizerRepresentable {
    let onTap: (CGPoint, CGSize) -> Void

    func makeUIGestureRecognizer(context: Context) -> UITapGestureRecognizer {
        let g = UITapGestureRecognizer()
        g.delegate = context.coordinator
        return g
    }

    func handleUIGestureRecognizerAction(_ g: UITapGestureRecognizer, context: Context) {
        guard g.state == .ended, let v = g.view else { return }
        onTap(g.location(in: v), v.bounds.size)
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
class Simultaneous: NSObject, UIGestureRecognizerDelegate {
    func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
}
