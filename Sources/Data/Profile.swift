import Foundation

enum AgeGroup: String, CaseIterable, Sendable {
    case infant, child, adult, senior

    var label: Bilingual {
        switch self {
        case .infant: Bilingual("Infant <1", "婴儿")
        case .child: Bilingual("Toddler / child 1–12", "幼儿 / 儿童")
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
    var isKid: Bool { age == .infant || age == .child }
}
