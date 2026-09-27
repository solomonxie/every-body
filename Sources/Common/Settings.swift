import SwiftUI

/// One language at a time, never mixed.
enum NameMode: String, CaseIterable {
    case en, zh
}

/// Persisted preferences.
@MainActor
@Observable
final class Settings {
    var names: NameMode { didSet { save() } }
    // view options: not saved, every page starts from these defaults (resetViewOptions)
    var whiteBackground = false
    var autoRotate = true
    // only the language is saved; everything else starts fresh each launch
    var female = false
    var age: AgeGroup = .adult
    var pregnant = false
    /// the 3D figure's face and skin tone
    var heritage: Heritage
    /// adults only; children always wear it
    var showUnderwear = true
    private(set) var recentSearches: [String] = []

    private let store = UserDefaults.standard

    init() {
        names = NameMode(rawValue: store.string(forKey: "names") ?? "")
            ?? (Locale.preferredLanguages.first?.hasPrefix("zh") == true ? .zh : .en)
        heritage = Locale.preferredLanguages.first?.hasPrefix("zh") == true ? .eastAsian : .white
    }

    private func save() {
        store.set(names.rawValue, forKey: "names")
    }

    /// Pages don't remember how they were last viewed.
    func resetViewOptions() {
        whiteBackground = false
        autoRotate = true
        showUnderwear = true
    }

    /// newest first, 6 kept
    func remember(search: String) {
        let q = search.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        recentSearches = Array(([q] + recentSearches.filter { $0.caseInsensitiveCompare(q) != .orderedSame }).prefix(6))
    }

    func clearRecentSearches() { recentSearches = [] }

    var profile: Profile { Profile(age: age, female: female, pregnant: pregnant) }

    /// "Femur" or "股骨"
    func name(_ en: String, _ zh: String) -> String {
        names == .zh && !zh.isEmpty ? zh : en
    }

    var zh: Bool { names == .zh }

    func t(_ en: String, _ zh: String) -> String { name(en, zh) }
    func t(_ b: Bilingual) -> String { name(b.en, b.zh) }

    /// "Volume 血容量" → "Volume" or "血容量"
    func t(mixed: String) -> String { Bilingual.pick(mixed: mixed, zh: zh) }
}
