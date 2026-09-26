import SwiftUI

struct ViewerScreen: View {
    let systemID: String
    var initialPoint: String?
    var initialPart: String?

    @Environment(Settings.self) private var settings
    @State private var scene = BodyScene()
    @State private var layers: Set<LayerID> = []
    @State private var parts = PartState()
    @State private var history: [PartState] = []
    @State private var selectedPart: String?
    @State private var activePoint: String?
    @State private var effectVisible = false
    @State private var filter = "all"
    @State private var bpm: Float = 72
    @State private var angles: [String: Float] = [:]
    @State private var built = false

    private var system: BodySystem { Catalog.system(systemID) ?? Catalog.systems[0] }
    private var systemPoints: SystemPoints? { Catalog.points[systemID] }
    private var isReflex: Bool { systemPoints?.points.contains { $0.target != nil } ?? false }
    private var flowStops: [BodyPoint] {
        guard let sp = systemPoints, let flow = sp.flow else { return [] }
        return flow.pointIds.compactMap { id in sp.points.first { $0.id == id } }
    }
    private var tryJoint: Joint? {
        guard let id = selectedPart else { return nil }
        return Catalog.body.joints.first { $0.movers.contains(id) } ?? Catalog.body.joints.first { $0.parts.contains(id) }
    }

    var body: some View {
        VStack(spacing: 0) {
            BodyView(scene: scene) { pick in
                switch pick {
                case let .point(id): press(id)
                case let .part(id): selectedPart = selectedPart == id ? nil : id
                }
            }
            .overlay { if !built { ProgressView() } }
            panel
        }
        .navigationTitle(settings.name(system.name, system.nameZh))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem { NavigationLink(value: Route.info(system: systemID)) { Image(systemName: "info.circle") } }
            ToolbarItem { ProfileMenu() }
        }
        .task { await BodyScene.prepare(); setUp() }
        .onChange(of: layers) { scene.setLayers(layers) }
        .onChange(of: parts) { scene.setParts(parts, selected: selectedPart) }
        .onChange(of: selectedPart) { scene.setParts(parts, selected: selectedPart) }
        .onChange(of: settings.female) { rebuild() }
        .onChange(of: bpm) { scene.bpm = bpm }
    }

    private func setUp() {
        guard !built else { return }
        built = true
        var base = Set(Catalog.body.defaultLayers[systemID] ?? [.skin, .organs])
        if let part = initialPart, let layer = Catalog.part(part)?.layer { base.insert(layer) }
        layers = base
        selectedPart = initialPart
        rebuild()
        if let point = initialPoint { press(point) }
    }

    private func rebuild() {
        scene.build(skinColor: UIColor(hex: "#F2C9A5"), female: settings.female,
                    points: systemPoints?.points ?? [], flowStops: flowStops)
        scene.setLayers(layers)
        scene.setParts(parts, selected: selectedPart)
        for (id, deg) in angles { scene.setJoint(id, degrees: deg) }
    }

    private func press(_ id: String) {
        guard let point = systemPoints?.points.first(where: { $0.id == id }) else { return }
        scene.touched = true
        activePoint = id
        scene.setActivePoint(id)
        guard let target = point.target else { return }
        scene.faceFront()
        scene.pulse(from: point.position.simd, to: target.organIds)
        effectVisible = false
        Task {
            try? await Task.sleep(for: .milliseconds(1400))
            if activePoint == id { effectVisible = true }
        }
    }

    private func change(_ next: PartState) {
        history.append(parts)
        parts = next
    }

    // MARK: panel

    private var panel: some View {
        VStack(alignment: .leading, spacing: 10) {
            PillRow {
                if !history.isEmpty { Pill(label: settings.t("↶ Undo", "↶ 撤销")) { parts = history.removeLast() } }
                ForEach(Catalog.body.layers) { layer in
                    Pill(label: settings.name(layer.label, layer.labelZh), selected: layers.contains(layer.id)) {
                        if layers.contains(layer.id) { layers.remove(layer.id) } else { layers.insert(layer.id) }
                    }
                }
                if parts.changedCount > 0 { Pill(label: settings.t("Reset parts (\(parts.changedCount))", "还原部位（\(parts.changedCount)）")) { change(PartState()) } }
            }
            if let id = selectedPart {
                PartCard(partID: id, parts: parts, female: settings.female, onChange: change) { selectedPart = nil }
            }
            if let joint = tryJoint {
                JointControl(joint: joint, angle: angles[joint.id] ?? 0) { deg in
                    angles[joint.id] = deg
                    scene.setJoint(joint.id, degrees: deg)
                }
            }
            if isReflex, let sp = systemPoints {
                ReflexPanel(points: sp.points, filter: $filter, activeID: activePoint, effectVisible: effectVisible, onPress: press) { f in
                    scene.touched = true
                    scene.faceFront()
                    scene.focus(f)
                }
            } else if !flowStops.isEmpty {
                FlowPanel(stops: flowStops, bpm: $bpm, activeID: activePoint, onStop: press)
            } else if selectedPart == nil {
                Text(settings.t("Tap any part to name it. Tap an arm or leg bone or muscle to move its joint.", "点击任意部位查看名称。点击手臂或腿部的骨骼、肌肉可活动关节。"))
                    .font(.footnote).foregroundStyle(.secondary).padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground))
    }
}
