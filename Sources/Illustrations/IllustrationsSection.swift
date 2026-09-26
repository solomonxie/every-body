import SwiftUI

/// Explore's list of illustrations, by group.
struct IllustrationsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ILLUSTRATIONS · 图解 — watch, then try").font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
                .padding(.top, 8)
            ForEach(IllustrationGroup.allCases, id: \.self) { group in
                let items = Illustrations.all.filter { $0.group == group }
                if !items.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(group.title.en) · \(group.title.zh)").font(.subheadline.weight(.semibold)).foregroundStyle(group.color)
                        ForEach(items) { scenario in
                            NavigationLink(value: Route.illustration(id: scenario.id)) {
                                HStack {
                                    Text("\(scenario.title.zh) \(scenario.title.en)").foregroundStyle(.primary).multilineTextAlignment(.leading)
                                    Spacer()
                                    Text("\(scenario.steps.count) steps ›").foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 8)
                            }
                        }
                    }
                    .padding(12)
                    .background(Color.secondary.opacity(0.1), in: .rect(cornerRadius: 14))
                }
            }
        }
    }
}
