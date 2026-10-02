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

/// Look of the 3D figure's outer skin (face and skin tone); the anatomy inside never changes.
enum Heritage: String, CaseIterable, Sendable {
    case white, black, hispanic, southAsian = "south-asian", southeastAsian = "southeast-asian"

    var label: Bilingual {
        switch self {
        case .southeastAsian: Bilingual("Southeast Asian", "东南亚")
        case .southAsian: Bilingual("South Asian", "南亚")
        case .hispanic: Bilingual("Hispanic / Latino", "拉丁裔")
        case .white: Bilingual("White", "白人")
        case .black: Bilingual("Black", "黑人")
        }
    }
}

/// Adult female body shape: the chest size, with the lower body following it.
enum BodySize: String, CaseIterable, Sendable {
    case small, medium, large, xlarge, xxlarge

    /// the lower body that goes with each shape (it has three sizes)
    var lower: BodySize {
        switch self {
        case .small: .small
        case .medium: .medium
        default: .large
        }
    }

    var label: Bilingual {
        switch self {
        case .small: Bilingual("Small build", "小尺寸")
        case .medium: Bilingual("Medium build", "中尺寸")
        case .large: Bilingual("Large build", "大尺寸")
        case .xlarge: Bilingual("Extra large build", "特大尺寸")
        case .xxlarge: Bilingual("Extra extra large build", "超大尺寸")
        }
    }

    /// sizes as letters: S … XXL
    var letter: Bilingual {
        switch self {
        case .small: Bilingual("S", "S")
        case .medium: Bilingual("M", "M")
        case .large: Bilingual("L", "L")
        case .xlarge: Bilingual("XL", "XL")
        case .xxlarge: Bilingual("XXL", "XXL")
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
