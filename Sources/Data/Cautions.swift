import Foundation

/// Who should skip or go gently on a point or zone, by person type.
enum Cautions {
    private static let pregnancyAvoid: Set<String> = [
        "hand-hegu", "body-sanyinjiao",
        "palm-gonads", "sole-gonads", "palm-pituitary", "sole-pituitary",
        "ear-genitals", "ear-pelvis", "ear-endocrine",
    ]

    /// Warnings for one point or zone id; the first is the most specific.
    static func warnings(_ id: String, for p: Profile) -> [Bilingual] {
        var out: [Bilingual] = []
        if p.isPregnant {
            switch id {
            case "hand-hegu":
                out.append(Bilingual("Pregnant: avoid Hegu (the web of the thumb). Strong pressure here is traditionally said to trigger contractions — skip it unless your midwife or doctor says otherwise.",
                                     "孕妇：避免按压合谷（虎口）。传统认为重按此穴可能诱发宫缩——除非医生或助产士同意，请跳过。"))
            case "body-sanyinjiao":
                out.append(Bilingual("Pregnant: avoid Sanyinjiao (above the inner ankle). It is traditionally used to bring on labour — do not press during pregnancy.",
                                     "孕妇：避免按压三阴交（内踝上方）。传统用于催产，孕期不要按压。"))
            case "hand-neiguan":
                out.append(Bilingual("Pregnant: gentle pressure on Neiguan is widely used for morning sickness and is considered low-risk.",
                                     "孕妇：轻按内关常用于缓解孕吐，一般认为风险较低。"))
            case _ where pregnancyAvoid.contains(id):
                out.append(Bilingual("Pregnant: skip reproductive and hormone zones, especially in the first 3 months.",
                                     "孕妇：避开生殖和内分泌相关区域，尤其是孕早期（前 3 个月）。"))
            default:
                out.append(Bilingual("Pregnant: light pressure only; stop at any cramping, bleeding or tightening.",
                                     "孕妇：只用轻柔力度；如出现腹痛、出血或宫缩感，立即停止。"))
            }
        }
        switch p.age {
        case .infant:
            out.append(Bilingual("Infant: no pressing on points — only a light stroke. A baby's bones and skin are soft.",
                                 "婴儿：不要点按穴位，只能轻抚。婴儿骨骼和皮肤都很娇嫩。"))
        case .child:
            out.append(Bilingual("Child: light pressure for a few seconds; stop if it hurts.",
                                 "儿童：轻按几秒即可，喊痛就停。"))
        case .senior:
            out.append(Bilingual("65+: go gently — thinner skin, weaker bones, and blood thinners bruise easily. Skip swollen, varicose or numb spots.",
                                 "老人：力度要轻——皮肤薄、骨质疏松，服抗凝药易淤青。避开肿胀、静脉曲张或麻木的部位。"))
        case .adult: break
        }
        return out
    }

    /// Serious enough to flag the point with ⚠ before it's pressed.
    static func avoid(_ id: String, for p: Profile) -> Bool {
        (p.isPregnant && pregnancyAvoid.contains(id)) || p.age == .infant
    }
}
