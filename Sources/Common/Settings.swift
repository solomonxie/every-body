import SwiftUI

/// One language at a time, never mixed.
enum NameMode: String, CaseIterable {
    case en, zh
}

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

/// Persisted preferences.
@MainActor
@Observable
final class Settings {
    var names: NameMode { didSet { save() } }
    var whiteBackground: Bool { didSet { save() } }
    var autoRotate: Bool { didSet { save() } }
    var female: Bool { didSet { save() } }
    var age: AgeGroup { didSet { save() } }
    var pregnant: Bool { didSet { save() } }

    private let store = UserDefaults.standard

    init() {
        names = NameMode(rawValue: store.string(forKey: "names") ?? "")
            ?? (Locale.preferredLanguages.first?.hasPrefix("zh") == true ? .zh : .en)
        whiteBackground = store.bool(forKey: "whiteBackground")
        autoRotate = store.object(forKey: "autoRotate") as? Bool ?? true
        female = store.bool(forKey: "female")
        age = AgeGroup(rawValue: store.string(forKey: "age") ?? "") ?? .adult
        pregnant = store.bool(forKey: "pregnant")
    }

    private func save() {
        store.set(names.rawValue, forKey: "names")
        store.set(whiteBackground, forKey: "whiteBackground")
        store.set(autoRotate, forKey: "autoRotate")
        store.set(female, forKey: "female")
        store.set(age.rawValue, forKey: "age")
        store.set(pregnant, forKey: "pregnant")
    }

    var profile: Profile { Profile(age: age, female: female, pregnant: pregnant) }

    /// "Femur" or "股骨"
    func name(_ en: String, _ zh: String) -> String {
        names == .zh && !zh.isEmpty ? zh : en
    }

    var zh: Bool { names == .zh }

    func t(_ en: String, _ zh: String) -> String { name(en, zh) }
    func t(_ b: Bilingual) -> String { name(b.en, b.zh) }

    /// "Volume 血容量" → "Volume" or "血容量"
    func t(mixed: String) -> String {
        guard let i = mixed.firstIndex(where: { $0.unicodeScalars.first.map { (0x4E00...0x9FFF).contains($0.value) } ?? false }) else { return mixed }
        let en = mixed[..<i].trimmingCharacters(in: .whitespaces), zh = mixed[i...].trimmingCharacters(in: .whitespaces)
        return name(en.isEmpty ? zh : en, zh)
    }
}
