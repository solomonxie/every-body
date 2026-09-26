import Foundation

enum Illustrations {
    /// Each topic is built for a person type; most ignore it, first aid and pregnancy don't.
    static let builders: [@Sendable (Profile) -> Scenario] = [
        cpr(for:), choking(for:), bleeding(for:), burns(for:), ankleSprain(for:),
        { _ in shoulder }, fracture(for:),
        bloodSugar(for:), bloodPressure(for:), bloodFats(for:),
        stroke(for:), heartAttack(for:), coldFlu(for:), asthma(for:), acidReflux(for:), kidneyStones(for:),
        { _ in fetalGrowth }, { _ in labor },
    ]

    static let all: [Scenario] = builders.map { $0(.standard) }

    static func find(_ id: String, for profile: Profile = .standard) -> Scenario? {
        builders.lazy.map { $0(profile) }.first { $0.id == id }
    }
}
