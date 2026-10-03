import RealityKit
import SwiftUI

/// Hands-on CPR practice on the 3D body: check, call, hand position, compressions, breaths, AED.
struct CPRTrainerScreen: View {
    let heritage: Heritage
    var chest: BodySize = .small
    var hips: BodySize = .small
    @State private var who = Profile.standard

    var body: some View {
        CPRTrainer(profile: who, heritage: heritage, chest: chest, hips: hips, who: $who)
            .id(who)
    }
}

private struct CPRTrainer: View {
    let profile: Profile
    let heritage: Heritage
    var chest: BodySize = .small
    var hips: BodySize = .small

    @Environment(Settings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @State private var coach: CPRCoach
    @State private var ready = false
    @State private var orbitStart: (azimuth: Float, elevation: Float)?
    @State private var zoomStart: Float?
    @State private var glass = false

    @Binding var who: Profile

    init(profile: Profile, heritage: Heritage, chest: BodySize, hips: BodySize, who: Binding<Profile>) {
        self.profile = profile
        self.heritage = heritage
        self.chest = chest
        self.hips = hips
        _who = who
        _coach = State(initialValue: CPRCoach(scene: CPRTrainerScene(victim: CPRVictim(profile.age), pregnant: profile.isPregnant)))
    }

    private var scene: CPRTrainerScene { coach.scene }

    var body: some View {
        ZStack {
            Color(light: "#DADCE2", dark: "#2B2D33").ignoresSafeArea()
            GeometryReader { geo in
                RealityView { content in
                    content.camera = .virtual
                    content.add(scene.root)
                    scene.body.subscription = content.subscribe(to: SceneEvents.Update.self) { event in
                        MainActor.assumeIsolated { coach.tick(Float(event.deltaTime)) }
                    }
                }
                .gesture(SingleTouchRecognizer(
                    onBegan: { coach.touchBegan($0, size: $1) },
                    onMoved: { coach.touchMoved($0, size: $1) },
                    onEnded: { coach.touchEnded($0, size: $1) }))
                .gesture(PanRecognizer(touches: 2, onChange: orbit, onEnd: { orbitStart = nil }))
                .gesture(PinchRecognizer(onChange: zoom, onEnd: { zoomStart = nil }))
            }
            .ignoresSafeArea()
            .opacity(ready ? 1 : 0)

            if !ready {
                LoadingBadge(text: settings.t("Preparing the body…", "正在准备人体…"))
            } else {
                VStack(spacing: Space.s) {
                    topBar
                    stageCard
                    Spacer(minLength: 0)
                    bottomPanel
                }
                .padding(.horizontal, Space.m)
                .padding(.bottom, Space.s)
            }
        }
        .sensoryFeedback(.impact(weight: .heavy, intensity: 0.9), trigger: coach.presses)
        .sensoryFeedback(.success, trigger: coach.successes)
        .sensoryFeedback(.warning, trigger: coach.misses)
        .sensoryFeedback(.impact(weight: .heavy, intensity: 1), trigger: coach.shocks)
        .task {
            BodyScene.glassOpacity = 0.22
            await BodyScene.prepare()
            if !scene.ready {
                scene.build(female: profile.female, heritage: heritage, age: profile.age, chest: chest, hips: hips)
            }
            ready = true
        }
        .onDisappear { BodyScene.glassOpacity = 0.12 }
    }

    // MARK: top

    private var topBar: some View {
        HStack(spacing: Space.s) {
            RailButton(symbol: "xmark", label: settings.t("Close", "关闭")) { dismiss() }
            Spacer()
            whoMenu
            RailButton(symbol: "arrow.counterclockwise", label: settings.t("Start over", "重新开始")) { coach.restart() }
            RailButton(symbol: "circle.lefthalf.filled", label: glass ? settings.t("Solid skin", "显示皮肤") : settings.t("See inside", "透视"),
                       on: glass) {
                glass.toggle()
                scene.glass = glass
            }
        }
    }

    private static let choices: [(Profile, Bilingual)] = [
        (Profile(age: .adult), Bilingual("Man", "男性")),
        (Profile(age: .adult, female: true), Bilingual("Woman", "女性")),
        (Profile(age: .adult, female: true, pregnant: true), Bilingual("Pregnant", "孕妇")),
        (Profile(age: .child), Bilingual("Child", "儿童")),
        (Profile(age: .infant), Bilingual("Baby", "婴儿")),
    ]

    private var current: Bilingual {
        Self.choices.first { $0.0 == profile }?.1 ?? Self.choices[0].1
    }

    private var whoMenu: some View {
        Menu {
            ForEach(Self.choices, id: \.1.en) { choice in
                Button(settings.t(choice.1)) { who = choice.0 }
            }
        } label: {
            Label(settings.t(current), systemImage: "person.fill")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, Space.m).padding(.vertical, Space.s)
                .background(.regularMaterial, in: .capsule)
        }
    }

    private var stageCard: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack(spacing: Space.xs) {
                ForEach(coach.stages, id: \.self) { s in
                    let index = coach.stages.firstIndex(of: s) ?? 0
                    let current = coach.stages.firstIndex(of: coach.chip) ?? 0
                    Text(settings.t(CPRCoach.title(s, victim: coach.victim)))
                        .font(.caption2.weight(.semibold))
                        .lineLimit(1).minimumScaleFactor(0.7)
                        .padding(.horizontal, Space.s).padding(.vertical, Space.xs)
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(s == coach.chip ? .white : index < current ? Color.brand : .secondary)
                        .background(s == coach.chip ? Color.emergency : index < current ? Color.brand.opacity(0.14) : Color.fill, in: .capsule)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(settings.t(CPRCoach.title(coach.chip, victim: coach.victim)))
            Text(settings.t(coach.instruction))
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            if !coach.feedback.en.isEmpty {
                Label(settings.t(coach.feedback), systemImage: coach.tone == .good ? "checkmark.circle.fill" : coach.tone == .warn ? "exclamationmark.circle.fill" : "info.circle.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(coach.tone == .good ? Color.success : coach.tone == .warn ? Color.caution : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            }
        }
        .padding(Space.m)
        .background(.regularMaterial, in: .rect(cornerRadius: Radius.card, style: .continuous))
        .animation(.snappy(duration: 0.2), value: coach.feedback.en)
    }

    // MARK: bottom

    @ViewBuilder private var bottomPanel: some View {
        switch coach.stage {
        case .call:
            Button { coach.call() } label: {
                Label(settings.zh ? "拨打 120" : "Call 911", systemImage: "phone.fill")
            }
            .buttonStyle(PrimaryButtonStyle(color: .emergency))
        case .compress:
            compressPanel
        case .airway, .breaths:
            breathPanel
        case .analyse:
            LoadingBadge(text: settings.t("Analyzing…", "分析中…"))
        case .shock:
            Button { coach.shock() } label: {
                Label(settings.t("Shock", "电击"), systemImage: "bolt.heart.fill")
            }
            .buttonStyle(PrimaryButtonStyle(color: Color(hex: "#E8871E")))
        default:
            skipRow
        }
    }

    private var skipRow: some View {
        HStack {
            Spacer()
            Button(settings.t("Skip", "跳过")) { coach.skip() }
                .buttonStyle(SecondaryButtonStyle(fullWidth: false))
        }
    }

    private var compressPanel: some View {
        let band = coach.victim.depth
        let rateOK = (100...120).contains(coach.rate)
        return VStack(spacing: Space.s) {
            HStack(alignment: .firstTextBaseline, spacing: Space.l) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(coach.count)").font(.system(.largeTitle, design: .rounded).weight(.bold).monospacedDigit())
                        + Text(" / 30").font(.headline).foregroundColor(.secondary)
                    Text(settings.t("pushes", "次按压")).font(.caption).foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    HStack(spacing: Space.xs) {
                        Beat()
                        Text(coach.rate > 0 ? "\(Int(coach.rate))" : "—")
                            .font(.system(.title, design: .rounded).weight(.bold).monospacedDigit())
                            .foregroundStyle(coach.rate == 0 ? Color.secondary : rateOK ? Color.success : Color.caution)
                    }
                    Text(settings.t("per min · aim 100–120", "次/分 · 目标 100–120")).font(.caption).foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
            DepthGauge(depth: coach.lastDepth, band: band, label: settings.t("Depth", "深度"))
            FlowMeter(flow: coach.flow, label: settings.t("Blood to the brain", "脑部供血"))
        }
        .padding(Space.m)
        .background(.regularMaterial, in: .rect(cornerRadius: Radius.card, style: .continuous))
    }

    private var breathPanel: some View {
        HStack(spacing: Space.m) {
            ForEach(0..<2, id: \.self) { i in
                Image(systemName: i < coach.breathsGiven ? "wind.circle.fill" : "wind.circle")
                    .font(.title)
                    .foregroundStyle(i < coach.breathsGiven ? Color.brand : .secondary)
            }
            Text(settings.t("Breath \(min(2, coach.breathsGiven)) of 2", "第 \(min(2, coach.breathsGiven)) / 2 次吹气"))
                .font(.subheadline.weight(.semibold))
            Spacer()
            Button(settings.t("Skip", "跳过")) { coach.skip() }
                .buttonStyle(SecondaryButtonStyle(fullWidth: false))
        }
        .padding(Space.m)
        .background(.regularMaterial, in: .rect(cornerRadius: Radius.card, style: .continuous))
    }

    // MARK: camera

    /// two fingers: turn and tilt, as in the body viewer (the step's own camera move stops once you take over)
    private func orbit(_ t: CGPoint) {
        let start = orbitStart ?? (scene.azimuth, scene.elevation)
        orbitStart = start
        scene.goalElevation = nil
        scene.azimuth = start.azimuth + Float(t.x) * 0.008
        // not straight down: from overhead a turn only spins the picture
        scene.elevation = max(0.15, min(1.2, start.elevation + Float(t.y) * 0.008))
    }

    private func zoom(_ s: CGFloat) {
        let start = zoomStart ?? scene.zoom
        zoomStart = start
        scene.zoom = max(0.45, min(1.8, start / Float(s)))
    }
}

/// Depth of the last push against the target band.
private struct DepthGauge: View {
    let depth: Float
    let band: ClosedRange<Float>
    let label: String
    private let top: Float = 8

    var body: some View {
        let ok = band.contains((depth * 10).rounded() / 10)
        HStack(spacing: Space.s) {
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(.secondary).frame(width: 64, alignment: .leading)
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.fill)
                    Rectangle().fill(Color.success.opacity(0.35))
                        .frame(width: w * CGFloat((band.upperBound - band.lowerBound) / top))
                        .offset(x: w * CGFloat(band.lowerBound / top))
                    Capsule().fill(depth == 0 ? Color.secondary : ok ? Color.success : Color.caution)
                        .frame(width: 4, height: 18)
                        .offset(x: w * CGFloat(min(depth, top) / top) - 2)
                        .animation(.snappy(duration: 0.15), value: depth)
                }
                .frame(height: 12)
                .frame(maxHeight: .infinity)
            }
            .frame(height: 20)
            Text(depth > 0 ? String(format: "%.1f cm", depth) : "— cm")
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(depth == 0 ? Color.secondary : ok ? Color.success : Color.caution)
                .frame(width: 52, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) \(String(format: "%.1f", depth)) cm")
    }
}

/// How much blood the pushes are getting to the brain.
private struct FlowMeter: View {
    let flow: Double
    let label: String

    var body: some View {
        HStack(spacing: Space.s) {
            Label(label, systemImage: "brain.head.profile").labelStyle(.iconOnly)
                .foregroundStyle(Color.emergency).frame(width: 64, alignment: .leading)
            ProgressView(value: flow).tint(Color.emergency)
            Text(label).font(.caption2).foregroundStyle(.secondary).lineLimit(1).fixedSize()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) \(Int(flow * 100))%")
    }
}

/// A dot pulsing at 110 a minute to push along with.
private struct Beat: View {
    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 60.0 / 110)
            let on = t < 0.12
            Circle().fill(Color.emergency)
                .frame(width: 10, height: 10)
                .scaleEffect(on ? 1.3 : 0.8)
                .opacity(on ? 1 : 0.35)
        }
        .accessibilityHidden(true)
    }
}
