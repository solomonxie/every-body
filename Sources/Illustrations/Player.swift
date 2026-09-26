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
        Group {
            if let scenario = Illustrations.find(id, for: settings.profile) {
                PlayerView(player: Player(scenario))
                    .id(settings.profile)
            } else {
                ContentUnavailableView(settings.t("Illustration not found", "未找到此图解"), systemImage: "questionmark.square.dashed")
            }
        }
        .profileToolbar()
    }
}

struct PlayerView: View {
    @State var player: Player
    @Environment(Settings.self) private var settings
    @State private var tapTimes: [Date] = []
    @State private var heldSeconds: Double = 0
    @State private var holding = false
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let scenario = player.scenario
        Group {
            // huge type: scroll the whole page instead of squeezing the scene
            if typeSize.isAccessibilitySize {
                ScrollView {
                    VStack(spacing: 0) {
                        stage(scenario)
                        panel(player.step)
                    }
                }
            } else {
                VStack(spacing: 0) {
                    stage(scenario).frame(maxHeight: .infinity)
                    panel(player.step)
                }
            }
        }
        .background(Color.page)
        .navigationTitle(settings.t(scenario.title))
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.selection, trigger: player.stepIndex)
        .sensoryFeedback(trigger: player.solved) { old, new in
            !old && new && player.step.kind == .try ? .success : nil
        }
        .task {
            player.reduceMotion = UIAccessibility.isReduceMotionEnabled
            while !Task.isCancelled {
                player.tick()
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
    }

    private func stage(_ scenario: Scenario) -> some View {
        VStack(spacing: Space.s) {
            canvas(scenario)
            if let note = scenario.profileNote {
                Banner(text: settings.t(note), symbol: "person.fill", ink: .note, fill: .noteFill)
            }
            if let w = scenario.warning {
                Banner(text: settings.t(w), symbol: "exclamationmark.triangle.fill", ink: .caution, fill: .cautionFill)
            }
        }
        .padding(.horizontal, Space.l)
        .padding(.vertical, Space.m)
    }

    /// the scene keeps its 360 × 300 shape on a white card
    private func canvas(_ scenario: Scenario) -> some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                let s = min(size.width / sceneSize.width, size.height / sceneSize.height)
                ctx.translateBy(x: (size.width - sceneSize.width * s) / 2, y: (size.height - sceneSize.height * s) / 2)
                ctx.scaleBy(x: s, y: s)
                var sketch = Sketch(ctx: ctx, zh: settings.zh)
                scenario.draw(&sketch, player.params, player.t)
            }
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                guard case .drag = player.step.try?.mode, let onDrag = scenario.onDrag else { return }
                let s = min(geo.size.width / sceneSize.width, geo.size.height / sceneSize.height)
                let p = CGPoint(x: (value.location.x - (geo.size.width - sceneSize.width * s) / 2) / s,
                                y: (value.location.y - (geo.size.height - sceneSize.height * s) / 2) / s)
                player.set(onDrag(p, player.params))
            })
        }
        .aspectRatio(sceneSize.width / sceneSize.height, contentMode: .fit)
        .background(Color.white)
        .clipShape(.rect(cornerRadius: Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Color.hairline.opacity(0.5), lineWidth: 0.5))
        .accessibilityElement()
        .accessibilityLabel(settings.t(player.step.caption))
        .accessibilityAddTraits(.isImage)
    }

    private func panel(_ step: Step) -> some View {
        let count = player.scenario.steps.count
        let last = player.stepIndex == count - 1
        return VStack(alignment: .leading, spacing: Space.m) {
            HStack(spacing: Space.s) {
                Text(settings.t("Step \(player.stepIndex + 1) of \(count)", "第 \(player.stepIndex + 1) / \(count) 步"))
                    .font(.footnote.weight(.semibold).monospacedDigit()).foregroundStyle(.secondary)
                Spacer()
                Label(step.kind == .try ? settings.t("Try it", "试一试") : settings.t("Watch", "观看"),
                      systemImage: step.kind == .try ? "hand.tap.fill" : "eye.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(step.kind == .try ? Color.brand : .secondary)
                    .padding(.horizontal, Space.s).padding(.vertical, Space.xs)
                    .background(step.kind == .try ? Color.brand.opacity(0.14) : Color.fill, in: .capsule)
            }
            progress
            Text(settings.t(step.caption))
                .font(.body.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            if let t = step.try { control(t) }
            if let t = step.try, player.solved {
                Label(settings.t(t.ok), systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Color.success)
                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .leading)))
            }
            HStack(spacing: Space.s) {
                Button { player.goTo(player.stepIndex - 1) } label: {
                    Image(systemName: "chevron.left").font(.body.weight(.bold))
                }
                .buttonStyle(SecondaryButtonStyle(fullWidth: false))
                .disabled(player.stepIndex == 0)
                .accessibilityLabel(settings.t("Previous step", "上一步"))
                if let demo = step.try?.demo, !player.solved {
                    Button { player.ease(demo) } label: {
                        Label(settings.t("Show me", "演示"), systemImage: "play.fill")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                let next = Button {
                    heldSeconds = 0
                    tapTimes = []
                    player.goTo(last ? 0 : player.stepIndex + 1)
                } label: {
                    if last {
                        Label(settings.t("Replay", "重播"), systemImage: "arrow.counterclockwise")
                    } else if step.kind == .try && !player.solved {
                        Text(settings.t("Skip", "跳过"))
                    } else {
                        Text(settings.t("Next", "下一步"))
                    }
                }
                if player.solved {
                    next.buttonStyle(PrimaryButtonStyle())
                } else {
                    next.buttonStyle(SecondaryButtonStyle())
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, Space.l)
        .padding(.top, Space.l)
        .padding(.bottom, Space.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: Radius.sheet, topTrailingRadius: Radius.sheet, style: .continuous)
                .fill(Color.card)
                .shadow(color: .black.opacity(0.08), radius: 12, y: -2)
                .ignoresSafeArea(edges: .bottom)
        }
        .animation(.snappy(duration: 0.25), value: player.solved)
        .animation(.snappy(duration: 0.25), value: player.stepIndex)
    }

    /// one segment per step: done, current, to come; tap to jump
    private var progress: some View {
        HStack(spacing: Space.xs) {
            ForEach(player.scenario.steps.indices, id: \.self) { i in
                Button { player.goTo(i) } label: {
                    Capsule()
                        .fill(i == player.stepIndex ? Color.brand : i < player.stepIndex ? Color.brand.opacity(0.4) : Color.fill)
                        .frame(height: i == player.stepIndex ? 6 : 4)
                        .frame(maxWidth: .infinity, minHeight: 24)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(settings.t("Step \(i + 1)", "第 \(i + 1) 步"))
                .accessibilityAddTraits(i == player.stepIndex ? .isSelected : [])
            }
        }
    }

    @ViewBuilder private func control(_ t: TryStep) -> some View {
        switch t.mode {
        case let .scrub(scrubs):
            ForEach(scrubs, id: \.param) { s in
                let v = player.params[s.param] ?? s.min
                VStack(spacing: Space.xxs) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(settings.t(mixed: s.label)).font(.subheadline)
                        Spacer()
                        Text(s.digits.map { String(format: "%.\($0)f", v) } ?? "\(Int((v - s.min) / (s.max - s.min) * 100))%")
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            + Text(s.unit.map { " \($0)" } ?? "").font(.footnote).foregroundStyle(.secondary)
                    }
                    Slider(value: Binding(get: { v }, set: { player.ease([s.param: $0]) }), in: s.min...s.max)
                        .accessibilityLabel(settings.t(mixed: s.label))
                }
            }
        case let .rhythm(_, minRate, maxRate, label):
            let rate = player.params["rate"] ?? 0
            let inRange = rate >= minRate && rate <= maxRate
            HStack(spacing: Space.l) {
                RoundAction(label: settings.t(mixed: label), color: .emergency, pressed: (player.params["press"] ?? 0) > 0.5) { tapRhythm() }
                    .sensoryFeedback(.impact(weight: .medium), trigger: player.params["taps"] ?? 0)
                if maxRate < 1000 {
                    VStack(alignment: .leading, spacing: Space.xxs) {
                        Text(rate > 0 ? "\(Int(rate))" : "—")
                            .font(.system(.largeTitle, design: .rounded).weight(.bold).monospacedDigit())
                            .foregroundStyle(rate == 0 ? Color.secondary : inRange ? Color.success : Color.caution)
                        Text(settings.t("per minute · aim \(Int(minRate))–\(Int(maxRate))", "次/分 · 目标 \(Int(minRate))–\(Int(maxRate))"))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .frame(maxWidth: .infinity)
        case let .hold(param, progress, seconds, label):
            let done = player.params[progress] ?? 0
            HStack(spacing: Space.l) {
                Text(settings.t(mixed: label))
                    .font(.headline).foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.7)
                    .padding(Space.s)
                    .frame(width: 96, height: 96)
                    .background(holding ? Color(hex: "#A82F36") : Color.emergency, in: .circle)
                    .overlay(Circle().inset(by: -5).trim(from: 0, to: done)
                        .stroke(Color.emergency, style: StrokeStyle(lineWidth: 4, lineCap: .round)).rotationEffect(.degrees(-90)))
                    .scaleEffect(holding ? 0.94 : 1)
                    .animation(.snappy(duration: 0.15), value: holding)
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
                    .sensoryFeedback(.impact(weight: .light), trigger: holding)
                    .accessibilityLabel(settings.t(mixed: label))
                    .accessibilityAddTraits(.isButton)
                Label(settings.t("Press and keep holding", "按住不放"), systemImage: "hand.point.up.left.fill")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        case let .compare(param, options):
            HStack(spacing: Space.s) {
                ForEach(options, id: \.label) { o in
                    let selected = abs((player.params[param] ?? 0) - o.value) < 0.5
                    Button { player.ease([param: o.value]) } label: {
                        Text(settings.t(mixed: o.label)).font(.subheadline.weight(.semibold))
                            .lineLimit(2).multilineTextAlignment(.center).minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity, minHeight: minTap)
                            .padding(.horizontal, Space.xs)
                            .background(selected ? Color.brandFill : Color.fill, in: .capsule)
                            .foregroundStyle(selected ? .white : .primary)
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityAddTraits(selected ? .isSelected : [])
                    .sensoryFeedback(.selection, trigger: selected)
                }
            }
        case .drag:
            if !player.solved {
                Label(settings.t("Drag on the picture", "在图上拖动"), systemImage: "hand.draw.fill")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
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
}

/// Big round tap target (rhythm).
private struct RoundAction: View {
    let label: String
    let color: Color
    let pressed: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.headline).foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
                .padding(Space.s)
                .frame(width: 96, height: 96)
                .background(color.gradient, in: .circle)
                .shadow(color: color.opacity(0.35), radius: pressed ? 2 : 8, y: pressed ? 1 : 4)
                .scaleEffect(pressed ? 0.93 : 1)
        }
        .buttonStyle(PressableStyle())
    }
}

/// Inline note under the scene.
struct Banner: View {
    let text: String
    let symbol: String
    let ink: Color
    let fill: Color

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Space.m).padding(.vertical, Space.s)
            .background(fill, in: .rect(cornerRadius: Radius.small, style: .continuous))
    }
}
