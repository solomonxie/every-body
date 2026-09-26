import SwiftUI

// Temporary screens while the port is in progress (IMPLEMENT_PLAN Phase 0).

struct IllustrationsSection: View {
    var body: some View { EmptyView() }
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
