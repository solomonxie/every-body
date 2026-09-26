import Foundation

enum AgeGroup: String, CaseIterable, Sendable {
    case infant, toddler, child, adult, senior

    /// toddlers follow child first-aid and caution rules; only the body differs
    var isChild: Bool { self == .child || self == .toddler }

    var label: Bilingual {
        switch self {
        case .infant: Bilingual("Infant <1", "婴儿")
        case .toddler: Bilingual("Toddler 1–3", "幼儿")
        case .child: Bilingual("Child 4–12", "儿童")
        case .adult: Bilingual("Adult", "成人")
        case .senior: Bilingual("Senior 65+", "老人")
        }
    }
}

/// Who the content is about; topics that differ by age or sex adapt to it.
struct Profile: Sendable, Hashable {
    var age: AgeGroup = .adult
    var female = false
    var pregnant = false
    static let standard = Profile()

    var isPregnant: Bool { female && pregnant && age == .adult }
    var isKid: Bool { age == .infant || age.isChild }
}
