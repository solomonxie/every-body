import SwiftUI

// Temporary screens while the port is in progress (IMPLEMENT_PLAN Phase 0).


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
