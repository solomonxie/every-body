import Foundation

/// Person-type notes for topics whose drawing stays the same.
extension Illustrations {
    static func bloodPressure(for p: Profile) -> Scenario {
        var s = bloodPressure
        s.profileNote = switch p.age {
        case .infant, .child: Bilingual("Children use age-, sex- and height-based percentile charts, not the adult numbers below. A child's normal is lower.",
                                        "儿童血压按年龄、性别、身高的百分位判断，不用下面的成人标准；儿童正常值更低。")
        case .senior: Bilingual("65+: stiffer arteries push the top number up. Stand up slowly — dizziness on standing (orthostatic drop) is common.",
                                "65 岁以上：血管变硬使收缩压升高。起身要慢——站起时头晕（体位性低血压）很常见。")
        case .adult where p.isPregnant: Bilingual("Pregnant: 140/90 or higher after 20 weeks, with headache or swelling, can mean pre-eclampsia — see a doctor the same day.",
                                                  "孕妇：孕 20 周后血压 ≥140/90，并伴头痛或水肿，可能是子痫前期——当天就医。")
        case .adult: nil
        }
        return s
    }

    static func heartAttack(for p: Profile) -> Scenario {
        var s = heartAttack
        if p.female {
            s.profileNote = Bilingual("Women more often feel breathlessness, nausea, back or jaw pain and unusual tiredness — sometimes with little chest pain. Still call 120.",
                                      "女性更常出现气短、恶心、背痛或下颌痛、异常疲乏，胸痛可能不明显。同样立即拨打 120。")
        } else if p.age == .senior {
            s.profileNote = Bilingual("65+ and people with diabetes may have a 'silent' attack: breathlessness, confusion or collapse without chest pain.",
                                      "老人和糖尿病患者可能出现“无痛性”心梗：只有气短、意识混乱或晕倒。")
        }
        return s
    }
}
