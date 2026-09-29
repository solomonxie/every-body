import RealityKit
import SwiftUI

/// A posture topic: the 3D figure on top, a slider between the two postures, the load gauge, what changes and tips.
struct PostureScreen: View {
    let id: String
    @Environment(Settings.self) private var settings

    var body: some View {
        if let topic = PostureTopic.find(id), topic.ready {
            PostureTopicView(topic: topic)
        } else {
            ContentUnavailableView(settings.t("Coming soon", "即将推出"), systemImage: "hourglass")
        }
    }
}

private struct PostureTopicView: View {
    let topic: PostureTopic
    @Environment(Settings.self) private var settings
    @State private var scene = PostureScene()
    @State private var blend: Double = 0
    @State private var ready = false
    @State private var neckLean: Float = 34
    @State private var seeThrough = true
    @State private var view: PostureScene.View = .side
    @State private var person = PosturePerson()

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                PostureView(scene: scene) { scene.show(view) }
                if !ready {
                    LoadingBadge(text: settings.t("Loading 3D…", "正在载入 3D…"))
                }
                rail
            }
            .frame(maxHeight: .infinity)
            ScrollView {
                PosturePanel(topic: topic, blend: $blend, neckLean: neckLean, pregnant: person.kind == .pregnant).padding(Space.l)
            }
            .frame(maxHeight: .infinity)
            .background(Color.page)
        }
        .navigationTitle(settings.t(topic.title))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { PosturePersonMenu(person: $person) } }
        .task(id: "\(person.kind)-\(person.heritage.rawValue)") {
            await BodyScene.prepare()
            scene.loads = [topic.loads.0, topic.loads.1]
            scene.build(topic: topic.id, female: person.kind != .man, pregnant: person.kind == .pregnant,
                        heritage: person.heritage, underwear: true, chest: .large, hips: .medium)
            neckLean = scene.neck.last ?? neckLean
            scene.seeThrough = seeThrough
            if !ready { scene.show(view); scene.settle() }
            ready = true
        }
        .onChange(of: blend) { scene.goalBlend = Float(blend) }
        .onChange(of: seeThrough) { scene.seeThrough = seeThrough }
        .sensoryFeedback(.selection, trigger: blend == 0 || blend == 1)
    }

    // MARK: 3D controls

    private static let views: [(view: PostureScene.View, label: Bilingual)] = [
        (.side, Bilingual("Whole body", "全身")), (.spine, Bilingual("Low back", "腰椎")),
        (.back, Bilingual("Back", "背面")), (.front, Bilingual("Front", "正面")),
    ]

    private var rail: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                legend
                Spacer(minLength: Space.s)
                Button { seeThrough.toggle() } label: {
                    Label(seeThrough ? settings.t("Show skin", "显示皮肤") : settings.t("See inside", "透视"),
                          systemImage: seeThrough ? "person.fill" : "eye")
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, Space.m).frame(height: 36)
                        .background(.regularMaterial, in: .capsule)
                }
                .buttonStyle(PressableStyle())
                .foregroundStyle(.primary)
            }
            Spacer()
            HStack(spacing: 2) {
                ForEach(Self.views, id: \.label.en) { v in
                    let on = view == v.view
                    Button { view = v.view; scene.show(v.view) } label: {
                        Text(settings.t(v.label))
                            .font(.footnote.weight(on ? .semibold : .regular))
                            .lineLimit(1).minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity).frame(height: 32)
                            .background(on ? Color.brand.opacity(0.18) : .clear, in: .capsule)
                            .foregroundStyle(on ? Color.brand : .primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            .padding(3)
            .background(.regularMaterial, in: .capsule)
            .sensoryFeedback(.selection, trigger: view)
        }
        .padding(12)
    }

    /// what the disc and muscle colours mean
    private var legend: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(settings.t("Pressure", "压力")).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            Capsule()
                .fill(LinearGradient(colors: [1.0, 1.4, 1.85, 2.3].map { Color(uiColor: PostureColors.load($0)) }, startPoint: .leading, endPoint: .trailing))
                .frame(width: 96, height: 8)
            HStack {
                Text(settings.t("Low", "低"))
                Spacer()
                Text(settings.t("High", "高"))
            }
            .font(.caption2).foregroundStyle(.secondary).frame(width: 96)
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(.regularMaterial, in: .rect(cornerRadius: 12, style: .continuous))
        .opacity(seeThrough ? 1 : 0)
        .accessibilityHidden(true)
    }

}

/// Full-bleed 3D posture view: one finger moves it, two fingers turn it, pinch zooms, double-tap resets.
struct PostureView: View {
    let scene: PostureScene
    var reset: () -> Void = {}
    @Environment(Settings.self) private var settings
    @State private var dragStart: (yaw: Float, pitch: Float)?
    @State private var panStart: (x: Float, y: Float)?
    @State private var zoomStart: Float?

    var body: some View {
        ZStack {
            (settings.whiteBackground ? Color.white : Color(light: "#DADCE2", dark: "#2B2D33"))
            RealityView { content in
                content.camera = .virtual
                scene.root.removeFromParent()
                content.add(scene.root)
                scene.subscription = content.subscribe(to: SceneEvents.Update.self) { event in
                    MainActor.assumeIsolated { scene.update(dt: Float(event.deltaTime)) }
                }
            }
            .gesture(PanRecognizer(touches: 1, onChange: move, onEnd: { panStart = nil }))
            .gesture(PanRecognizer(touches: 2, onChange: rotate, onEnd: { dragStart = nil }))
            .gesture(PinchRecognizer(onChange: zoom, onEnd: { zoomStart = nil }))
            .gesture(SpatialTapGesture(count: 2).onEnded { _ in reset() })
        }
        .accessibilityElement()
        .accessibilityLabel(settings.t("3D figure sitting on a chair", "坐在椅子上的 3D 人体"))
    }

    private func rotate(_ t: CGPoint) {
        let start = dragStart ?? (scene.yaw, scene.pitch)
        dragStart = start
        scene.goalYaw = nil; scene.goalPitch = nil
        scene.yaw = start.yaw + Float(t.x) * 0.008
        scene.pitch = Swift.max(-0.9, Swift.min(0.9, start.pitch + Float(t.y) * 0.008))
    }

    private func move(_ t: CGPoint) {
        let start = panStart ?? (scene.panX, scene.goalFocusY)
        panStart = start
        let k = scene.distance * 0.0012
        scene.panX = Swift.max(-2, Swift.min(2, start.x - Float(t.x) * k))
        scene.goalPanX = scene.panX
        scene.goalFocusY = Swift.max(-1.8, Swift.min(1.8, start.y + Float(t.y) * k))
        scene.focusY = scene.goalFocusY
    }

    private func zoom(_ scale: CGFloat) {
        let start = zoomStart ?? scene.goalDistance
        zoomStart = start
        let next = Swift.max(1.2, Swift.min(9, start / Float(scale)))
        scene.goalDistance = next
        scene.distance = next
    }
}

/// The posture figures: an adult man, woman or pregnant woman (a fresh white man on each visit).
struct PosturePerson: Equatable {
    enum Kind: CaseIterable { case man, woman, pregnant }
    var kind = Kind.man
    var heritage = Heritage.white
}

private struct PosturePersonMenu: View {
    @Binding var person: PosturePerson
    @Environment(Settings.self) private var settings

    var body: some View {
        Menu {
            Picker(settings.t("Person", "人物"), selection: $person.kind) {
                ForEach(PosturePerson.Kind.allCases, id: \.self) { Text(settings.t(label($0))).tag($0) }
            }
            .pickerStyle(.inline)
            Picker(settings.t("Appearance", "外貌"), selection: $person.heritage) {
                ForEach(Heritage.allCases, id: \.self) { Text(settings.t($0.label)).tag($0) }
            }
            .pickerStyle(.inline)
        } label: {
            Label("\(settings.t(person.heritage.label)) \(settings.t(label(person.kind)))", systemImage: "figure.stand")
                .labelStyle(.titleAndIcon)
                .font(.footnote.weight(.semibold))
        }
        .accessibilityLabel(settings.t("Person type", "人群"))
        .sensoryFeedback(.selection, trigger: person)
    }

    private func label(_ kind: PosturePerson.Kind) -> Bilingual {
        switch kind {
        case .man: Bilingual("Man", "男性")
        case .woman: Bilingual("Woman", "女性")
        case .pregnant: Bilingual("Pregnant", "孕妇")
        }
    }
}
