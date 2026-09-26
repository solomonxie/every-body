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
    @State private var zoomStart: Float?

    var body: some View {
        ZStack {
            (settings.whiteBackground ? Color.white : Color(hex: "#DADCE2"))
            RealityView { content in
                content.camera = .virtual
                content.add(scene.root)
                scene.subscription = content.subscribe(to: SceneEvents.Update.self) { event in
                    MainActor.assumeIsolated { scene.update(dt: Float(event.deltaTime)) }
                }
            }
            .gesture(drag.simultaneously(with: zoom))
            .gesture(SpatialTapGesture(count: 2).onEnded { _ in scene.resetView() })
            .gesture(tap)

            if !compact {
                rail
                if hintVisible {
                    Text("Drag to spin · pinch to zoom · tap a part")
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
            RailButton(symbol: "house", label: "Reset view") { scene.resetView() }
            RailButton(symbol: "circle.lefthalf.filled", label: "Background") { settings.whiteBackground.toggle() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .padding(12)
    }

    private func firstTouch() {
        scene.touched = true
        hintVisible = false
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                firstTouch()
                let start = dragStart ?? (scene.yaw, scene.pitch)
                dragStart = start
                scene.goalYaw = nil
                scene.yaw = start.yaw + Float(value.translation.width) * 0.008
                scene.pitch = max(-0.9, min(0.9, start.pitch + Float(value.translation.height) * 0.008))
            }
            .onEnded { _ in dragStart = nil }
    }

    private var zoom: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                firstTouch()
                let start = zoomStart ?? scene.goalDistance
                zoomStart = start
                let next = max(1.2, min(9, start / Float(value.magnification)))
                scene.goalDistance = next
                scene.distance = next
            }
            .onEnded { _ in zoomStart = nil }
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
