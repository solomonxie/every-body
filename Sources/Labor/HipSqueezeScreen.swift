import RealityKit
import SwiftUI

/// The double hip squeeze: a partner's hands pressing her hips in through a contraction, in 3D on a loop,
/// with how to do it, tips, a caveat and sources.
struct HipSqueezeScreen: View {
    @Environment(Settings.self) private var settings
    @State private var scene = HipSqueezeScene()
    @State private var ready = false
    @State private var playing = true
    @State private var bones = false

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                HipSqueezeView(scene: scene)
                    .opacity(ready ? 1 : 0)
                if !ready {
                    LoadingBadge(text: settings.t("Loading 3D…", "正在载入 3D…"))
                } else {
                    controls
                }
            }
            .frame(maxHeight: .infinity)
            ScrollView {
                HipSqueezePanel(bones: bones).padding(Space.l)
            }
            .frame(maxHeight: .infinity)
            .background(Color.page)
        }
        .navigationTitle(settings.t(Self.title))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            BodyScene.glassOpacity = 0.22
            await BodyScene.prepare()
            if !scene.ready { scene.build(heritage: settings.heritage, chest: settings.chest) }
            ready = true
        }
        .onDisappear { BodyScene.glassOpacity = 0.12 }
        .onChange(of: playing) { scene.playing = playing }
        .onChange(of: bones) { scene.bones = bones }
    }

    static let title = Bilingual("Double hip squeeze in labor", "分娩时的双髋挤压")

    private var controls: some View {
        VStack(spacing: Space.s) {
            HStack(spacing: Space.s) {
                Spacer()
                RailButton(symbol: playing ? "pause.fill" : "play.fill", label: settings.t(playing ? "Pause" : "Play", playing ? "暂停" : "播放")) {
                    playing.toggle()
                }
                RailButton(symbol: "figure.stand", label: settings.t("Bones", "骨骼"), on: bones) { bones.toggle() }
                RailButton(symbol: "arrow.counterclockwise", label: settings.t("Reset view", "重置视角")) { scene.resetView() }
            }
            Spacer(minLength: 0)
            ContractionCard(scene: scene)
        }
        .padding(Space.m)
    }
}

/// The loop's step and the contraction's strength, read from the scene as it plays.
private struct ContractionCard: View {
    let scene: HipSqueezeScene
    @Environment(Settings.self) private var settings

    static let steps: [HipSqueezeScene.Phase: (Bilingual, String)] = [
        .building: (Bilingual("A contraction builds", "宫缩开始增强"), "waveform.path.ecg"),
        .squeeze: (Bilingual("Press in and slightly up", "向内并稍向上挤压"), "arrow.right.and.line.vertical.and.arrow.left"),
        .hold: (Bilingual("Hold firmly through the peak", "高峰期间稳稳按住"), "hand.raised.fill"),
        .easing: (Bilingual("The contraction eases", "宫缩逐渐减弱"), "waveform.path"),
        .release: (Bilingual("Release slowly", "慢慢松开"), "hand.raised"),
        .rest: (Bilingual("Rest until the next one", "休息，等下一次宫缩"), "pause.circle"),
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 20)) { _ in
            let t = scene.time
            let phase = HipSqueezeScene.phase(at: t)
            let step = Self.steps[phase] ?? (Bilingual("", ""), "circle")
            VStack(alignment: .leading, spacing: Space.xs) {
                HStack(spacing: Space.s) {
                    Image(systemName: step.1).foregroundStyle(Color.brand)
                    Text(settings.t(step.0)).font(.subheadline.weight(.semibold))
                    Spacer(minLength: Space.s)
                    Text("\(phase.rawValue + 1)/\(HipSqueezeScene.Phase.allCases.count)")
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
                ContractionWave(time: t)
                    .frame(height: 34)
                HStack {
                    Text(settings.t("Contraction", "宫缩")).foregroundStyle(Color(hex: "#C77DA0"))
                    Text(settings.t("Squeeze", "挤压")).foregroundStyle(Color(hex: "#4F73C4"))
                    Spacer()
                    Text(settings.t("Sped up: a real one lasts about a minute", "已加速：真实宫缩约持续 1 分钟")).foregroundStyle(.secondary)
                }
                .font(.caption2)
            }
            .padding(Space.m)
            .background(.regularMaterial, in: .rect(cornerRadius: Radius.card, style: .continuous))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(settings.t(step.0))
        }
    }
}

/// The loop as two curves, contraction and squeeze, with a marker at now.
private struct ContractionWave: View {
    let time: Float

    var body: some View {
        Canvas { ctx, size in
            let n = 80
            func path(_ f: (Float) -> Float) -> Path {
                Path { p in
                    for i in 0...n {
                        let t = Float(i) / Float(n) * HipSqueezeScene.cycle
                        let pt = CGPoint(x: CGFloat(i) / CGFloat(n) * size.width, y: size.height * (1 - CGFloat(f(t)) * 0.9) - 1)
                        if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                    }
                }
            }
            var fill = path(HipSqueezeScene.contraction)
            fill.addLine(to: CGPoint(x: size.width, y: size.height))
            fill.addLine(to: CGPoint(x: 0, y: size.height))
            ctx.fill(fill, with: .color(Color(hex: "#C77DA0").opacity(0.18)))
            ctx.stroke(path(HipSqueezeScene.contraction), with: .color(Color(hex: "#C77DA0")), lineWidth: 2)
            ctx.stroke(path { HipSqueezeScene.press(at: $0) * 0.75 }, with: .color(Color(hex: "#4F73C4")), style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
            let x = CGFloat(time / HipSqueezeScene.cycle) * size.width
            ctx.fill(Path(CGRect(x: x - 1, y: 0, width: 2, height: size.height)), with: .color(.primary.opacity(0.6)))
        }
    }
}

/// Full-bleed 3D: one finger slides the view, two fingers turn it, pinch zooms, double-tap resets.
private struct HipSqueezeView: View {
    let scene: HipSqueezeScene
    @Environment(Settings.self) private var settings
    @State private var orbitStart: (azimuth: Float, elevation: Float)?
    @State private var panStart: SIMD3<Float>?
    @State private var zoomStart: Float?

    var body: some View {
        ZStack {
            (settings.whiteBackground ? Color.white : Color(light: "#DADCE2", dark: "#2B2D33"))
            RealityView { content in
                content.camera = .virtual
                scene.root.removeFromParent()
                content.add(scene.root)
                scene.body.subscription = content.subscribe(to: SceneEvents.Update.self) { event in
                    MainActor.assumeIsolated { scene.update(dt: Float(event.deltaTime)) }
                }
            }
            .gesture(PanRecognizer(touches: 1, onChange: slide, onEnd: { panStart = nil }))
            .gesture(PanRecognizer(touches: 2, onChange: orbit, onEnd: { orbitStart = nil }))
            .gesture(PinchRecognizer(onChange: zoom, onEnd: { zoomStart = nil }))
            .gesture(SpatialTapGesture(count: 2).onEnded { _ in scene.resetView() })
        }
        .accessibilityElement()
        .accessibilityLabel(settings.t("3D: a pregnant woman leans on a bed while a partner's hands press her hips inward",
                                       "3D：孕妇俯身扶着床，陪产者双手向内挤压她的髋部"))
    }

    private func orbit(_ t: CGPoint) {
        let start = orbitStart ?? (scene.azimuth, scene.elevation)
        orbitStart = start
        scene.holdCamera()
        scene.azimuth = start.azimuth - Float(t.x) * 0.008
        scene.elevation = max(-0.2, min(1.2, start.elevation + Float(t.y) * 0.008))
    }

    private func slide(_ t: CGPoint) {
        let start = panStart ?? scene.panOffset
        panStart = start
        let k = scene.distance * scene.zoom * 0.0012
        let (right, up) = scene.screenAxes
        scene.panOffset = start - right * Float(t.x) * k + up * Float(t.y) * k
    }

    private func zoom(_ s: CGFloat) {
        let start = zoomStart ?? scene.zoom
        zoomStart = start
        scene.holdCamera()
        scene.zoom = max(0.35, min(1.8, start / Float(s)))
    }
}

/// Under the 3D view: what it is, the steps, tips, the caveat and sources.
private struct HipSqueezePanel: View {
    let bones: Bool
    @Environment(Settings.self) private var settings

    static let intro = Bilingual(
        "During a contraction, a partner presses both palms on the fleshy part of her buttocks and squeezes in toward the middle. Many women find this counter-pressure eases back pain in labor.",
        "宫缩时，陪产者把双手手掌放在她臀部肌肉最丰满处，向中间挤压。许多产妇觉得这种反向按压能减轻分娩时的腰背痛。")

    static let steps: [Bilingual] = [
        Bilingual("She leans forward: standing with her hands on a bed or table, or on hands and knees.",
                  "她身体前倾：站着双手扶在床沿或桌边，或四肢着地跪趴。"),
        Bilingual("Stand behind her. Put your palms on the fleshy upper buttocks, below the top edge of the hip bones, fingers pointing up and out.",
                  "站在她身后。双手手掌放在臀部上方肌肉丰满处、髋骨上缘以下，手指朝上、朝外。"),
        Bilingual("As a contraction starts, press in toward the middle and slightly up, toward her waist.",
                  "宫缩一开始，就向中间并稍向上（朝腰部方向）挤压。"),
        Bilingual("Press firmly and steadily, as hard as she asks. Lean in with your body weight rather than squeezing with your arms.",
                  "用力要稳，力度以她的要求为准。用身体重量往前压，而不是只靠手臂夹。"),
        Bilingual("Hold through the whole contraction, then release slowly as it fades. Rest between contractions.",
                  "整个宫缩期间保持按压，宫缩消退时慢慢松开。宫缩间隙休息。"),
    ]

    static let tips: [(symbol: String, text: Bilingual)] = [
        ("figure.cooldown", Bilingual("Other positions work too: kneeling and leaning over a birth ball or the head of the bed, or on hands and knees.",
                                      "其他姿势也可以：跪着趴在分娩球或床头上，或四肢着地跪趴。")),
        ("bubble.left", Bilingual("Ask her what helps. She may want it higher, lower, harder or softer, and that can change as labor goes on.",
                                  "问她怎样舒服。她可能想要更高、更低、更重或更轻，而且产程中会变化。")),
        ("hand.raised", Bilingual("Sacral pressure instead: the heel of one hand or a fist pressed steadily on her low back, over the flat bone at the base of the spine.",
                                  "也可以按骶骨：用一只手的掌根或拳头，稳稳压在她下背部脊柱底端那块扁平的骨头上。")),
        ("chair", Bilingual("Knee press: she sits upright on a chair, you kneel in front, cup her knees and lean in, pressing them back toward her hips.",
                            "膝部按压：她端坐在椅子上，你跪在她面前，双手捧住她的膝盖，身体前倾，把膝盖往她髋部方向推。")),
        ("person.2", Bilingual("It's tiring for the helper: take turns with someone else, or switch to sacral pressure.",
                               "陪产者容易累：和别人轮流，或改为按压骶骨。")),
    ]

    static let caveat = Bilingual(
        "Stop if it hurts or she doesn't want it. It's a comfort measure, not a treatment. Ask your midwife or doctor first, especially if you have pelvic girdle pain. Back or belly pain that doesn't ease between contractions needs a midwife to check.",
        "如果疼痛或她不想要，就停下。这是一种舒缓方法，不是治疗。请先咨询助产士或医生，尤其是有骨盆带疼痛时。宫缩间隙腰背或腹部仍持续疼痛，需要助产士检查。")

    static let sources = [
        "Simkin P. The Birth Partner: A Complete Guide to Childbirth for Dads, Partners, Doulas, and All Other Labor Companions. 5th ed. Harvard Common Press; 2018.",
        "Simkin P, Hanson L, Ancheta R. The Labor Progress Handbook. 4th ed. Wiley-Blackwell; 2017.",
        "Smith CA, Levett KM, Collins CT, et al. Massage, reflexology and other manual methods for pain management in labour. Cochrane Database Syst Rev 2018;3:CD009290.",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            VStack(alignment: .leading, spacing: Space.s) {
                Text(settings.t(Self.intro)).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                Text(settings.t("Pressing the top of the pelvis in may also open its outlet a little. Evidence for these comfort methods is limited, and mostly small studies.",
                                "向内压骨盆上部，也可能让骨盆出口稍微张开一点。这类舒缓方法的证据有限，多为小型研究。"))
                    .font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if bones {
                    Banner(text: settings.t("Bones: the hip bones' movement is exaggerated many times; the real change is a millimetre or two.",
                                            "骨骼：髋骨的移动被放大了许多倍，实际只有一两毫米。"),
                           symbol: "figure.stand", ink: .note, fill: .noteFill)
                }
            }
            .card()
            steps
            tips
            caution
            sources
        }
    }

    private var steps: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Eyebrow(settings.t("How to do it", "怎么做"))
            ForEach(Array(Self.steps.enumerated()), id: \.offset) { i, step in
                Label {
                    Text(settings.t(step)).fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Text("\(i + 1)").font(.caption.weight(.bold)).foregroundStyle(.white)
                        .frame(width: 20, height: 20).background(Color(hex: "#C77DA0"), in: .circle)
                }
                .font(.subheadline)
            }
        }
        .card()
    }

    private var tips: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Eyebrow(settings.t("Tips", "小贴士"))
            ForEach(Array(Self.tips.enumerated()), id: \.offset) { _, tip in
                Label { Text(settings.t(tip.text)).fixedSize(horizontal: false, vertical: true) } icon: {
                    Image(systemName: tip.symbol).foregroundStyle(Color.success)
                }
                .font(.subheadline)
            }
        }
        .card()
    }

    private var caution: some View {
        Label { Text(settings.t(Self.caveat)).fixedSize(horizontal: false, vertical: true) } icon: {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Color.caution)
        }
        .font(.subheadline)
        .padding(Space.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cautionFill, in: .rect(cornerRadius: Radius.card, style: .continuous))
    }

    private var sources: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Eyebrow(settings.t("Sources", "参考资料"))
            ForEach(Self.sources, id: \.self) { Text($0).font(.caption).foregroundStyle(.secondary) }
            Text(settings.t("Not medical advice. Follow your midwife or doctor.", "非医疗建议，请遵从助产士或医生的指导。"))
                .font(.caption).foregroundStyle(.secondary).padding(.top, Space.xs)
        }
        .card()
    }
}
