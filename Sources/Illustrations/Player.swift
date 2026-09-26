import SwiftUI

/// Steps through a scenario, easing params toward each step's targets every frame.
@MainActor
@Observable
final class Player {
    let scenario: Scenario
    private(set) var stepIndex = 0
    private(set) var params: Params
    private(set) var t: Double = 0
    var reduceMotion = false

    @ObservationIgnored private var targets: Params
    @ObservationIgnored private let start = Date()
    @ObservationIgnored private var last = Date()

    init(_ scenario: Scenario) {
        self.scenario = scenario
        let initial = scenario.targets(at: 0)
        params = initial
        targets = initial
    }

    var step: Step { scenario.steps[stepIndex] }
    var solved: Bool { step.kind == .watch || (step.try?.success(params) ?? true) }

    func tick() {
        let now = Date()
        let dt = min(0.1, now.timeIntervalSince(last))
        last = now
        let k = reduceMotion ? 1 : 1 - exp(-3.5 * dt)
        var next = params
        for (key, goal) in targets { next[key] = (next[key] ?? goal) + (goal - (next[key] ?? goal)) * k }
        params = next
        t = now.timeIntervalSince(start)
    }

    func goTo(_ index: Int) {
        stepIndex = min(scenario.steps.count - 1, max(0, index))
        targets = scenario.targets(at: stepIndex)
    }

    /// jump now (drag, taps)
    func set(_ values: Params) {
        targets.merge(values) { _, new in new }
        params.merge(values) { _, new in new }
    }

    /// ease toward (sliders, "Show me")
    func ease(_ values: Params) {
        targets.merge(values) { _, new in new }
    }

    /// jump to 1 and ease back to 0 — a press or beat
    func pulse(_ key: String) {
        params[key] = 1
        targets[key] = 0
    }
}

struct IllustrationScreen: View {
    let id: String
    @Environment(Settings.self) private var settings

    var body: some View {
        if let scenario = Illustrations.find(id, for: settings.profile) {
            PlayerView(player: Player(scenario))
                .id(settings.profile)
                .profileToolbar()
        } else {
            Text(settings.t("Not found", "未找到"))
        }
    }
}

private struct PlayerView: View {
    @State var player: Player
    @Environment(Settings.self) private var settings
    @State private var tapTimes: [Date] = []
    @State private var heldSeconds: Double = 0
    @State private var holding = false

    var body: some View {
        let scenario = player.scenario
        let step = player.step
        VStack(spacing: 0) {
            GeometryReader { geo in
                Canvas { ctx, size in
                    let s = min(size.width / sceneSize.width, size.height / sceneSize.height)
                    ctx.translateBy(x: (size.width - sceneSize.width * s) / 2, y: (size.height - sceneSize.height * s) / 2)
                    ctx.scaleBy(x: s, y: s)
                    var sketch = Sketch(ctx: ctx, zh: settings.zh)
                    scenario.draw(&sketch, player.params, player.t)
                }
                .background(Color.white, ignoresSafeAreaEdges: [])
                .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                    guard case .drag = step.try?.mode, let onDrag = scenario.onDrag else { return }
                    let s = min(geo.size.width / sceneSize.width, geo.size.height / sceneSize.height)
                    let p = CGPoint(x: (value.location.x - (geo.size.width - sceneSize.width * s) / 2) / s,
                                    y: (value.location.y - (geo.size.height - sceneSize.height * s) / 2) / s)
                    player.set(onDrag(p, player.params))
                })
            }
            if let note = scenario.profileNote {
                Label(settings.t(note), systemImage: "person.fill")
                    .font(.caption.weight(.semibold)).foregroundStyle(Color(hex: "#2B2250"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16).padding(.vertical, 6)
                    .background(Color(hex: "#E8E2F6"))
            }
            if let w = scenario.warning {
                Text("⚠ \(settings.t(w))").font(.caption).foregroundStyle(Color(hex: "#B5462E"))
                    .padding(.horizontal, 16).padding(.vertical, 4)
            }
            panel(step)
        }
        .navigationTitle(settings.t(scenario.title))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            player.reduceMotion = UIAccessibility.isReduceMotionEnabled
            while !Task.isCancelled {
                player.tick()
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
    }

    private func panel(_ step: Step) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ForEach(Array(player.scenario.steps.enumerated()), id: \.offset) { i, s in
                    Button { player.goTo(i) } label: {
                        Text(s.kind == .try ? "◆" : "●").opacity(i == player.stepIndex ? 1 : 0.35)
                    }
                    .buttonStyle(.plain)
                }
                Text(step.kind == .try ? settings.t("Try it", "试一试") : settings.t("Watch", "观看")).font(.caption).foregroundStyle(.secondary)
            }
            Text(settings.t(step.caption)).font(.subheadline.weight(.semibold))
            if let t = step.try { control(t) }
            if let t = step.try, player.solved {
                Text("✓ \(settings.t(t.ok))").font(.footnote.weight(.semibold)).foregroundStyle(Color(hex: "#2E9E5B"))
            }
            HStack {
                navButton(settings.t("‹ Prev", "‹ 上一步"), enabled: player.stepIndex > 0) { player.goTo(player.stepIndex - 1) }
                if let demo = step.try?.demo, !player.solved { navButton(settings.t("Show me", "演示")) { player.ease(demo) } }
                let last = player.stepIndex == player.scenario.steps.count - 1
                navButton(last ? settings.t("↺ Replay", "↺ 重播") : step.kind == .try && !player.solved ? settings.t("Skip ›", "跳过 ›") : settings.t("Next ›", "下一步 ›"), primary: player.solved) {
                    heldSeconds = 0
                    tapTimes = []
                    player.goTo(last ? 0 : player.stepIndex + 1)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground))
    }

    @ViewBuilder private func control(_ t: TryStep) -> some View {
        switch t.mode {
        case let .scrub(scrubs):
            ForEach(scrubs, id: \.param) { s in
                let v = player.params[s.param] ?? s.min
                VStack(spacing: 0) {
                    HStack {
                        Text(settings.t(mixed: s.label)).font(.footnote)
                        Spacer()
                        Text(s.digits.map { String(format: "%.\($0)f", v) } ?? "\(Int((v - s.min) / (s.max - s.min) * 100))%")
                            .font(.footnote.weight(.semibold)) + Text(s.unit.map { " \($0)" } ?? "").font(.footnote)
                    }
                    Slider(value: Binding(get: { v }, set: { player.ease([s.param: $0]) }), in: s.min...s.max)
                }
            }
        case let .rhythm(_, minRate, maxRate, label):
            VStack(spacing: 6) {
                bigButton(settings.t(mixed: label)) { tapRhythm() }
                if maxRate < 1000 {
                    Text(settings.t("Aim for \(Int(minRate))–\(Int(maxRate)) per minute — about 2 taps a second.", "目标每分钟 \(Int(minRate))–\(Int(maxRate)) 次，约每秒 2 下。")).font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
        case let .hold(param, progress, seconds, label):
            VStack(spacing: 6) {
                Text(settings.t(mixed: label))
                    .font(.headline).foregroundStyle(.white)
                    .frame(width: 140, height: 64)
                    .background(holding ? Color(hex: "#A82F36") : Color(hex: "#D8434B"), in: .capsule)
                    .onLongPressGesture(minimumDuration: 60, pressing: { down in
                        holding = down
                        player.ease([param: down ? 1 : 0])
                    }, perform: {})
                    .task(id: holding) {
                        while holding && !Task.isCancelled {
                            try? await Task.sleep(for: .milliseconds(100))
                            heldSeconds += 0.1
                            player.set([progress: min(1, heldSeconds / seconds)])
                        }
                    }
                Text(settings.t("Press and keep holding", "按住不放")).font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        case let .compare(param, options):
            HStack {
                ForEach(options, id: \.label) { o in
                    let selected = abs((player.params[param] ?? 0) - o.value) < 0.5
                    Button { player.ease([param: o.value]) } label: {
                        Text(settings.t(mixed: o.label)).font(.footnote.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 8)
                            .background(selected ? Color.brand : Color.secondary.opacity(0.15), in: .capsule)
                            .foregroundStyle(selected ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        case .drag:
            if !player.solved { Text(settings.t("☝ Drag on the picture", "☝ 在图上拖动")).font(.footnote).foregroundStyle(.secondary) }
        }
    }

    private func tapRhythm() {
        let now = Date()
        let kept = (tapTimes.last.map { now.timeIntervalSince($0) > 2 } ?? false) ? [] : tapTimes
        let recent = Array((kept + [now]).suffix(6))
        let intervals = zip(recent.dropFirst(), recent).map { $0.timeIntervalSince($1) }
        let avg = intervals.isEmpty ? 0 : intervals.reduce(0, +) / Double(intervals.count)
        tapTimes = recent
        var values: Params = ["taps": (player.params["taps"] ?? 0) + 1, "rate": avg > 0 ? 60 / avg : 0]
        if let extra = player.scenario.onTap?(player.params) { values.merge(extra) { _, new in new } }
        player.set(values)
        player.pulse("press")
    }

    private func bigButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).font(.headline).foregroundStyle(.white)
                .frame(width: 140, height: 64)
                .background(Color(hex: "#D8434B"), in: .capsule)
        }
        .buttonStyle(.plain)
    }

    private func navButton(_ label: String, enabled: Bool = true, primary: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 10)
                .background(primary ? Color.brand : Color.secondary.opacity(0.15), in: .capsule)
                .foregroundStyle(primary ? .white : .primary)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
    }
}
