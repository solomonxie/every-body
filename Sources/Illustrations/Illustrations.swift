import Foundation

enum Illustrations {
    /// Each topic is built for a person type; most ignore it, first aid and pregnancy don't.
    static let builders: [@Sendable (Profile) -> Scenario] = [
        cpr(for:), choking(for:), { _ in bleeding }, { _ in burns }, ankleSprain(for:),
        { _ in shoulder }, fracture(for:),
        { _ in bloodSugar }, bloodPressure(for:), { _ in bloodFats },
        { _ in stroke }, heartAttack(for:), { _ in coldFlu }, { _ in asthma }, { _ in acidReflux }, kidneyStones(for:),
        { _ in fetalGrowth }, { _ in labor },
    ]

    static let all: [Scenario] = builders.map { $0(.standard) }

    static func find(_ id: String, for profile: Profile = .standard) -> Scenario? {
        builders.lazy.map { $0(profile) }.first { $0.id == id }
    }
}
