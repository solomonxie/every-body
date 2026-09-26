import SwiftUI

// Temporary screens while the port is in progress (IMPLEMENT_PLAN Phase 0).

struct IllustrationsSection: View {
    var body: some View { EmptyView() }
}

struct ChartScreen: View {
    let chartID: String
    var initialFace: String?
    var initialZone: String?
    var initialSide: Side?
    var body: some View { Text("Chart \(chartID) — porting") }
}

struct IllustrationScreen: View {
    let id: String
    var body: some View { Text("Illustration \(id) — porting") }
}

struct InfoScreen: View {
    let systemID: String
    var body: some View { Text("Info \(systemID) — porting") }
}

struct QuizScreen: View {
    let systemID: String
    var body: some View { Text("Quiz — porting") }
}

struct SearchScreen: View {
    var body: some View { Text("Search — porting") }
}
