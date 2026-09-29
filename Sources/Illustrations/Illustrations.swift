import Foundation

enum Illustrations {
    /// Each topic is built for a person type; most ignore it, first aid and pregnancy don't.
    static let builders: [@Sendable (Profile) -> Scenario] = [
        cpr(for:), choking(for:), bleeding(for:), burns(for:), ankleSprain(for:), recoveryPosition(for:),
        shoulder(for:), fracture(for:),
        bloodSugar(for:), bloodPressure(for:), bloodFats(for:),
        stroke(for:), heartAttack(for:), coldFlu(for:), asthma(for:), acidReflux(for:), kidneyStones(for:),
        { _ in fetalGrowth }, { _ in labor }, { _ in pregnancyWarningSigns }, { _ in sleepPosition }, { _ in morningSickness },
    ]

    static let all: [Scenario] = builders.map { $0(.standard) }

    /// adult advice, or no version drawn for little ones
    private static let hiddenFor: [AgeGroup: Set<String>] = [
        .infant: ["stroke", "blood-pressure", "blood-sugar", "asthma", "acid-reflux", "kidney-stones"],
        .toddler: ["stroke", "blood-pressure", "blood-sugar", "asthma", "acid-reflux", "kidney-stones"],
        .child: ["blood-pressure", "asthma", "acid-reflux", "kidney-stones"],
    ]

    static func shown(_ id: String, for profile: Profile) -> Bool {
        !(hiddenFor[profile.age]?.contains(id) ?? false)
    }

    static func all(for profile: Profile) -> [Scenario] {
        all.filter { shown($0.id, for: profile) }
    }

    static func find(_ id: String, for profile: Profile = .standard) -> Scenario? {
        guard shown(id, for: profile) else { return nil }
        return builders.lazy.map { $0(profile) }.first { $0.id == id }
    }
}
