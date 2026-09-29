import SwiftUI

/// A posture topic: two poses to compare in 3D, a load gauge, what changes, tips and sources.
struct PostureTopic: Identifiable {
    struct Mark {
        let value: Float
        let label: Bilingual
    }

    let id: String
    let symbol: String
    let title: Bilingual
    let note: Bilingual
    /// false: listed as coming soon
    var ready = false
    var ends: (Bilingual, Bilingual) = (Bilingual("", ""), Bilingual("", ""))
    /// load at each end (relative, standing = 1) and the fixed marks on the gauge
    var loads: (Float, Float) = (1, 1)
    var gauge: (title: Bilingual, marks: [Mark], max: Float) = (Bilingual("", ""), [], 1)
    /// what's happening at each end
    var explain: ([Bilingual], [Bilingual]) = ([], [])
    var tips: [(symbol: String, text: Bilingual)] = []
    var sources: [String] = []
    var caveat: Bilingual?
    /// shown for a pregnant profile
    var pregnancy: Bilingual?

    static func find(_ id: String) -> PostureTopic? { all.first { $0.id == id } }

    static let all: [PostureTopic] = [
        PostureTopic(
            id: "sitting", symbol: "chair", title: Bilingual("Long sitting and your lower back", "久坐与腰椎"),
            note: Bilingual("Sit tall vs slump: the load on your lumbar discs", "坐直与瘫坐：腰椎间盘承受的压力"), ready: true,
            ends: (Bilingual("Sit tall", "坐直"), Bilingual("Slump", "瘫坐")),
            loads: (1.4, 1.85),
            gauge: (Bilingual("Pressure in a lumbar disc (L3), standing = 100%", "腰椎间盘（L3）内压，站立 = 100%"),
                    [Mark(value: 0.25, label: Bilingual("Lying", "平躺")), Mark(value: 1.0, label: Bilingual("Standing", "站立")),
                     Mark(value: 1.4, label: Bilingual("Sit tall", "坐直")), Mark(value: 1.85, label: Bilingual("Slump", "瘫坐"))], 2.2),
            explain: ([Bilingual("Pelvis upright on the sit bones", "骨盆立在坐骨上"),
                       Bilingual("Lower back keeps a gentle inward curve", "腰部保持自然前凸"),
                       Bilingual("Load spread evenly over each disc", "压力均匀分布在椎间盘上"),
                       Bilingual("Ears over the shoulders: the neck carries just the head's weight", "耳朵在肩膀正上方：颈部只承受头部本身的重量")],
                      [Bilingual("Pelvis rolls back, hips slide forward", "骨盆后倾，臀部前滑"),
                       Bilingual("Lower back rounds into a C: discs squeezed at the front, pushed backward", "腰椎弯成 C 形：椎间盘前缘受挤、髓核向后推"),
                       Bilingual("Back muscles and ligaments held on stretch", "腰背肌与韧带持续被拉长"),
                       Bilingual("Head pokes forward: the neck muscles carry several times its weight", "头部前伸：颈部肌肉承受数倍于头重的负荷")]),
            tips: [("rectangle.portrait.and.arrow.right", Bilingual("Sit back in the chair; a lumbar support or a rolled towel keeps the curve", "坐满椅面，用腰靠或卷起的毛巾撑住腰部曲线")),
                   ("shoeprints.fill", Bilingual("Feet flat, knees about level with the hips", "双脚平放，膝盖与髋部大致同高")),
                   ("figure.walk", Bilingual("Stand up and move every 30–60 minutes", "每 30–60 分钟起身活动一下")),
                   ("display", Bilingual("Screen at eye level, ears over shoulders, so you don't lean in", "屏幕与眼睛齐平、耳朵在肩膀正上方，免得身体前倾"))],
            sources: ["Nachemson A. Disc pressure measurements. Spine 1981;6(1):93–97.",
                      "Wilke HJ et al. New in vivo measurements of pressures in the intervertebral disc in daily life. Spine 1999;24(8):755–762.",
                      "O'Sullivan PB et al. Effect of different upright sitting postures on spinal-pelvic curvature and trunk muscle activation. Spine 2006;31(19):E707–712.",
                      "Hansraj KK. Assessment of stresses in the cervical spine caused by posture and position of the head. Surg Technol Int 2014;25:277–279."],
            caveat: Bilingual("Classic values (Nachemson). Later measurements (Wilke 1999) found relaxed sitting closer to standing, but slumped, bent-forward sitting stays the highest.",
                              "经典数据（Nachemson）。后来的测量（Wilke 1999）发现放松坐姿接近站立，但弯腰瘫坐始终最高。"),
            pregnancy: Bilingual("Pregnant: the bump already deepens the low-back curve. Sit back with a cushion behind your lower back, feet flat or on a low footrest, and get up often.",
                                 "孕期：孕肚本身会加深腰部前凸。坐满椅面、腰后垫靠枕，双脚平放或踩在矮凳上，并经常起身活动。")),
        PostureTopic(id: "computer", symbol: "keyboard", title: Bilingual("Arms and wrists at the computer", "电脑前的手臂与手腕"),
                     note: Bilingual("Elbows, shoulders, wrists and the carpal tunnel", "肘、肩、手腕与腕管")),
        PostureTopic(id: "standing", symbol: "figure.stand", title: Bilingual("Long standing and your legs", "久站与腿部"),
                     note: Bilingual("Blood pooling in the calves, and the calf pump", "小腿静脉淤血与小腿肌肉泵")),
        PostureTopic(id: "couch", symbol: "sofa", title: Bilingual("Sitting on a couch", "坐沙发"),
                     note: Bilingual("Sinking into soft cushions vs a cushion at the low back", "陷进软垫 vs 腰后垫靠枕")),
        PostureTopic(id: "floor", symbol: "figure.mind.and.body", title: Bilingual("Sitting on the floor", "席地而坐"),
                     note: Bilingual("Cross-legged and slouched vs against a wall", "盘腿弓背 vs 靠墙坐")),
        PostureTopic(id: "laptop", symbol: "laptopcomputer", title: Bilingual("Laptop on your lap", "笔记本放腿上"),
                     note: Bilingual("Bent neck and rounded shoulders vs a raised screen", "低头圆肩 vs 抬高屏幕")),
        PostureTopic(id: "phone-standing", symbol: "iphone", title: Bilingual("Looking down at your phone", "低头看手机"),
                     note: Bilingual("How the load on your neck grows as the head tips forward", "头越低，颈椎负荷越大")),
        PostureTopic(id: "phone-bed", symbol: "bed.double", title: Bilingual("Phone in bed", "躺着玩手机"),
                     note: Bilingual("Neck, shoulder and arm strain, and sleep", "颈、肩、手臂劳损与睡眠")),
    ]
}

/// Home section: one row per posture topic; unfinished ones are listed as coming soon.
struct PostureSection: View {
    @Environment(Settings.self) private var settings
    private let color = Color(hex: "#2E8B7A")

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            VStack(alignment: .leading, spacing: Space.xxs) {
                SectionHeader(settings.t("Posture & habits", "姿势与习惯"))
                Text(settings.t("See what everyday positions do inside your body.", "看看日常姿势对身体内部的影响。"))
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(PostureTopic.all.enumerated()), id: \.element.id) { i, topic in
                    if i > 0 { Divider().padding(.leading, Space.l + 30 + Space.m) }
                    if topic.ready {
                        NavigationLink(value: Route.posture(id: topic.id)) { row(topic) }
                            .buttonStyle(RowButtonStyle())
                    } else {
                        row(topic)
                    }
                }
            }
            .background(Color.card, in: .rect(cornerRadius: Radius.card, style: .continuous))
            .clipShape(.rect(cornerRadius: Radius.card, style: .continuous))
        }
    }

    private func row(_ topic: PostureTopic) -> some View {
        let soon = !topic.ready
        return HStack(spacing: Space.m) {
            IconBadge(symbol: topic.symbol, color: soon ? .gray : color)
            VStack(alignment: .leading, spacing: 2) {
                Text(settings.t(topic.title)).font(.body).foregroundStyle(soon ? .secondary : .primary)
                Text(settings.t(topic.note)).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: Space.s)
            if soon {
                Text(settings.t("Soon", "即将推出"))
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    .padding(.horizontal, Space.s).padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.12), in: .capsule)
            } else {
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, Space.l)
        .padding(.vertical, Space.m)
        .frame(minHeight: minTap)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityHint(soon ? settings.t("Coming soon", "即将推出") : "")
    }
}
