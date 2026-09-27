import Foundation

/// Who should skip or go gently on a point or zone, by person type.
enum Cautions {
    private static let pregnancyAvoid = Set([
        "hand-hegu", "back-hegu", "body-sanyinjiao",
        "palm-gonads", "sole-gonads", "palm-pituitary", "sole-pituitary", "palm-uterus", "back-groin", "top-fallopian",
        "ear-genitals", "ear-ext-genitals", "ear-pelvis", "ear-endocrine",
    ]).union(acuForbidden).union(acuLowerTrunk)

    /// Traditionally forbidden in pregnancy (WHO guidelines on basic training and safety in acupuncture, 1999).
    private static let acuForbidden: Set<String> = ["acu-li4", "acu-sp6", "acu-gb21", "acu-bl60", "acu-bl67"]
    /// lower abdomen and lumbosacral region: not needled after the first 3 months
    private static let acuLowerTrunk: Set<String> = ["acu-cv3", "acu-cv4", "acu-cv6", "acu-cv8", "acu-st25", "acu-bl23", "acu-bl25", "acu-bl32", "acu-gv4"]
    /// upper abdomen: avoided in the first 3 months
    private static let acuUpperAbdomen: Set<String> = ["acu-cv12", "acu-lr13", "acu-lr14"]
    /// chest, upper back and base of the neck: the lung lies close under the skin
    private static let acuLung: Set<String> = ["acu-gb21", "acu-lu1", "acu-bl13", "acu-bl15", "acu-bl17", "acu-bl18", "acu-bl20", "acu-lr14", "acu-cv22", "acu-si11"]

    /// Shown with every acupuncture point.
    static let acupunctureSafety: [Bilingual] = [
        Bilingual("Only by a licensed practitioner, with sterile, single-use needles.", "只由有资质的医师操作，使用无菌一次性针具。"),
        Bilingual("Bleeding disorders or blood thinners (anticoagulants): tell the practitioner first — bruising and bleeding are more likely.",
                  "有出血性疾病或服用抗凝药者须事先告知医师——更易淤青出血。"),
        Bilingual("Pacemaker or other implanted electronic device: no electro-acupuncture.", "装有心脏起搏器等植入电子设备者：禁用电针。"),
        Bilingual("Not over broken, infected or swollen skin, varicose veins or tumours; not when very hungry, exhausted or after alcohol.",
                  "避开破损、感染、肿胀的皮肤及静脉曲张、肿瘤处；过饥、过劳或饮酒后不宜针刺。"),
        Bilingual("Fainting during needling can happen — lie down, especially the first time.", "针刺时可能晕针——尤其第一次，宜取卧位。"),
    ]

    /// Warnings for one point or zone id; the first is the most specific.
    static func warnings(_ id: String, for p: Profile) -> [Bilingual] {
        if id.hasPrefix("acu-") { return acupunctureWarnings(id, for: p) }
        var out: [Bilingual] = []
        if p.isPregnant {
            switch id {
            case "hand-hegu", "back-hegu":
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
        case .toddler, .child:
            out.append(Bilingual("Child: light pressure for a few seconds; stop if it hurts.",
                                 "儿童：轻按几秒即可，喊痛就停。"))
        case .senior:
            out.append(Bilingual("65+: go gently — thinner skin, weaker bones, and blood thinners bruise easily. Skip swollen, varicose or numb spots.",
                                 "老人：力度要轻——皮肤薄、骨质疏松，服抗凝药易淤青。避开肿胀、静脉曲张或麻木的部位。"))
        case .adult: break
        }
        return out
    }

    private static func acupunctureWarnings(_ id: String, for p: Profile) -> [Bilingual] {
        var out: [Bilingual] = []
        if p.isPregnant {
            switch id {
            case "acu-li4", "acu-sp6":
                out.append(Bilingual("Pregnant: forbidden. Hegu and Sanyinjiao are traditionally said to bring on contractions — no needles, no strong pressure.",
                                     "孕妇禁用：传统认为合谷、三阴交可诱发宫缩——禁针，也不要重按。"))
            case "acu-gb21":
                out.append(Bilingual("Pregnant: forbidden. Jianjing is traditionally used to hasten labour.", "孕妇禁用：肩井传统用于催产。"))
            case "acu-bl60":
                out.append(Bilingual("Pregnant: forbidden. Kunlun is traditionally used for difficult labour.", "孕妇禁用：昆仑传统用于难产。"))
            case "acu-bl67":
                out.append(Bilingual("Pregnant: no needling. Moxibustion here to turn a breech baby only from about 33 weeks, under your midwife or doctor.",
                                     "孕妇禁针。艾灸至阴矫正胎位仅在约孕 33 周后、在助产士或医生指导下进行。"))
            case _ where acuLowerTrunk.contains(id):
                out.append(Bilingual("Pregnant: lower-abdomen and lower-back points are not needled after the first 3 months — most practitioners avoid them throughout.",
                                     "孕妇：怀孕 3 个月后禁针下腹部及腰骶部穴位——多数医师整个孕期都避开。"))
            case _ where acuUpperAbdomen.contains(id):
                out.append(Bilingual("Pregnant: upper-abdomen points are avoided in the first 3 months; later the womb lies close beneath.",
                                     "孕妇：孕早期（前 3 个月）避免针刺上腹部穴位；此后子宫位置升高，亦需谨慎。"))
            case "acu-pc6":
                out.append(Bilingual("Pregnant: Neiguan is widely used for morning sickness and considered low-risk.", "孕妇：内关常用于缓解孕吐，一般认为风险较低。"))
            default:
                out.append(Bilingual("Pregnant: tell the practitioner. Strong stimulation and electro-acupuncture are avoided in pregnancy.",
                                     "孕妇：请告知医师。孕期避免强刺激与电针。"))
            }
        }
        if acuLung.contains(id) {
            out.append(Bilingual("The lung lies close beneath — deep needling here can collapse it (pneumothorax).", "深部邻近肺脏——深刺可致气胸。"))
        }
        switch p.age {
        case .infant:
            out.append(id == "acu-gv20"
                       ? Bilingual("Infant: Baihui sits over the soft spot (fontanelle) — never needle or press it.", "婴儿：百会正当囟门——禁针，也不要按压。")
                       : Bilingual("Infant: needles are not used on babies — gentle touch only.", "婴儿：不对婴儿施针，只可轻抚。"))
        case .toddler, .child:
            out.append(Bilingual("Child: only by a practitioner trained for children — fewer, shallower needles, or needle-free pressure.",
                                 "儿童：须由擅长小儿针灸的医师操作——取穴少、刺得浅，或改用按压等无针方法。"))
        case .senior:
            out.append(Bilingual("65+: tell the practitioner about blood thinners, diabetes or a pacemaker — bruising and slow healing are more common.",
                                 "老人：请告知是否服用抗凝药、患糖尿病或装有起搏器——更易淤青，愈合较慢。"))
        case .adult: break
        }
        return out
    }

    /// Serious enough to flag the point with ⚠ before it's pressed.
    static func avoid(_ id: String, for p: Profile) -> Bool {
        (p.isPregnant && pregnancyAvoid.contains(id)) || p.age == .infant
    }
}
