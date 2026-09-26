import SwiftUI

typealias Params = [String: Double]

struct Bilingual: Sendable {
    let en: String
    let zh: String
    init(_ en: String, _ zh: String) { self.en = en; self.zh = zh }

    /// Legacy "breastbone 胸骨" labels: English before the first Chinese character, Chinese from it on.
    static func pick(mixed: String, zh: Bool) -> String {
        let isHan: (Character) -> Bool = { $0.unicodeScalars.first.map { (0x4E00...0x9FFF).contains($0.value) } ?? false }
        guard let i = mixed.firstIndex(where: isHan), mixed.contains(where: { $0.isASCII && $0.isLetter }) else { return mixed }
        let en = mixed[..<i].trimmingCharacters(in: .whitespaces), cn = mixed[i...].trimmingCharacters(in: .whitespaces)
        return zh || en.isEmpty ? cn : en
    }
}

struct Scrub: Sendable {
    let param: String
    let label: String
    let min: Double
    let max: Double
    var unit: String? = nil
    /// nil = show as percent of range
    var digits: Int? = nil
}

enum TryMode: Sendable {
    case scrub([Scrub])
    case rhythm(target: Int, minRate: Double, maxRate: Double, label: String = "PUSH 按压")
    /// hold the button: `param` → 1 while held; `progress` fills over `seconds` of total hold
    case hold(param: String, progress: String, seconds: Double, label: String)
    case compare(param: String, options: [(label: String, value: Double)])
    case drag
}

struct TryStep: Sendable {
    let mode: TryMode
    let success: @Sendable (Params) -> Bool
    let ok: Bilingual
    var demo: Params? = nil
}

struct Step: Sendable {
    enum Kind: Sendable { case watch, `try` }
    let kind: Kind
    let caption: Bilingual
    var set: Params = [:]
    var `try`: TryStep? = nil

    static func watch(_ en: String, _ zh: String, set: Params = [:]) -> Step {
        Step(kind: .watch, caption: Bilingual(en, zh), set: set)
    }

    static func tryIt(_ en: String, _ zh: String, set: Params = [:], _ t: TryStep) -> Step {
        Step(kind: .try, caption: Bilingual(en, zh), set: set, try: t)
    }
}

enum IllustrationGroup: String, CaseIterable, Sendable {
    case firstAid, bones, blood, illness, pregnancy

    var title: Bilingual {
        switch self {
        case .bones: Bilingual("Bones & setting", "骨折与接骨")
        case .firstAid: Bilingual("First aid", "急救")
        case .blood: Bilingual("Blood sugar, pressure & fats", "三高")
        case .illness: Bilingual("Common illnesses", "常见病")
        case .pregnancy: Bilingual("Pregnancy & birth", "孕产")
        }
    }

    var color: Color {
        switch self {
        case .bones: Color(hex: "#8F7E63")
        case .firstAid: Color(hex: "#D8434B")
        case .blood: Color(hex: "#E39B4B")
        case .illness: Color(hex: "#6C4F9E")
        case .pregnancy: Color(hex: "#C77DA0")
        }
    }
}

/// One illustration: data steps + a scene drawn from params each frame (viewBox 360 × 300).
struct Scenario: Sendable, Identifiable {
    let id: String
    let group: IllustrationGroup
    let title: Bilingual
    var warning: Bilingual? = nil
    /// how this version differs for the chosen person type
    var profileNote: Bilingual? = nil
    let params: Params
    let steps: [Step]
    let draw: @MainActor @Sendable (inout Sketch, Params, Double) -> Void
    /// finger in viewBox units → param changes
    var onDrag: (@Sendable (CGPoint, Params) -> Params)? = nil
    /// extra param changes on each rhythm tap
    var onTap: (@Sendable (Params) -> Params)? = nil
    let sources: [String]
    /// extra search words: everyday names, symptoms
    var keywords: [String] = []

    /// base values plus every step's targets up to `index`, so Prev is deterministic
    func targets(at index: Int) -> Params {
        steps.prefix(index + 1).reduce(params) { $0.merging($1.set) { _, new in new } }
    }
}

let sceneSize = CGSize(width: 360, height: 300)
