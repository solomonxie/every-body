import Foundation

enum Illustrations {
    static let all: [Scenario] = [
        shoulder, fracture,
        cpr, choking, bleeding, burns, ankleSprain,
        bloodSugar, bloodPressure, bloodFats,
        stroke, heartAttack, coldFlu, asthma, acidReflux, kidneyStones,
        fetalGrowth, labor,
    ]

    static func find(_ id: String) -> Scenario? { all.first { $0.id == id } }
}
