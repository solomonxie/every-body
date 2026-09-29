import Foundation

extension Scenario {
    /// same scenario with extra base params (and new steps) for a person type
    func rebased(_ extra: Params, steps: [Step]? = nil) -> Scenario {
        Scenario(id: id, group: group, title: title, warning: warning, profileNote: profileNote, params: params.merging(extra) { _, n in n },
                 steps: steps ?? self.steps, draw: draw, onDrag: onDrag, onTap: onTap, sources: sources, keywords: keywords)
    }
}

/// Person-type versions: a note, and the drawing adapted where it matters.
extension Illustrations {
    static func bloodPressure(for p: Profile) -> Scenario {
        var s = bloodPressure
        s.profileNote = switch p.age {
        case .infant, .toddler, .child: Bilingual("Children use a small cuff and age-, sex- and height-based percentile charts, not the adult numbers below. A child's normal is lower.",
                                        "儿童用小号袖带，按年龄、性别、身高的百分位判断，不用下面的成人标准；儿童正常值更低。")
        case .senior: Bilingual("65+: stiffer arteries push the top number up. Stand up slowly — dizziness on standing (orthostatic drop) is common.",
                                "65 岁以上：血管变硬使收缩压升高。起身要慢——站起时头晕（体位性低血压）很常见。")
        case .adult where p.isPregnant: Bilingual("Pregnant: 140/90 or higher after 20 weeks, with headache or swelling, can mean pre-eclampsia — see a doctor the same day.",
                                                  "孕妇：孕 20 周后血压 ≥140/90，并伴头痛或水肿，可能是子痫前期——当天就医。")
        case .adult: nil
        }
        return s.rebased(["kid": p.isKid ? 1 : 0, "senior": p.age == .senior ? 1 : 0, "pregnant": p.isPregnant ? 1 : 0, "female": p.female ? 1 : 0])
    }

    static func heartAttack(for p: Profile) -> Scenario {
        var s = heartAttack
        if p.isKid {
            s.profileNote = Bilingual("Heart attacks are very rare in children, so the scene shows an adult. Chest pain in a child is usually harmless — but fainting during exercise needs a doctor.",
                                      "儿童极少发生心梗，所以图中是成人。儿童胸痛大多无害——但运动时晕倒需要就医。")
        } else if p.isPregnant {
            s.profileNote = Bilingual("Pregnant: rare but real, and easy to blame on the pregnancy. Chest pain, breathlessness or back or jaw pain — call 911 and say she is pregnant.",
                                      "孕妇：少见但会发生，容易被误以为是孕期不适。胸痛、气短、背痛或下颌痛——拨打 120，并说明她怀孕了。")
        } else if p.female {
            s.profileNote = Bilingual("Women more often feel breathlessness, nausea, back or jaw pain and unusual tiredness — sometimes with little chest pain. Still call 911.",
                                      "女性更常出现气短、恶心、背痛或下颌痛、异常疲乏，胸痛可能不明显。同样立即拨打 120。")
        } else if p.age == .senior {
            s.profileNote = Bilingual("65+ and people with diabetes may have a 'silent' attack: breathlessness, confusion or collapse without chest pain.",
                                      "老人和糖尿病患者可能出现“无痛性”心梗：只有气短、意识混乱或晕倒。")
        }
        return s.rebased(["female": p.female ? 1 : 0, "senior": p.age == .senior ? 1 : 0, "pregnant": p.isPregnant ? 1 : 0])
    }
}
