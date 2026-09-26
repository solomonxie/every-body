import SwiftUI

/// Home page list of illustrations, by group — first aid first.
struct IllustrationsSection: View {
    @Environment(Settings.self) private var settings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(settings.t("Illustrations — watch, then try", "图解 — 先看，再试"))
            ForEach(IllustrationGroup.allCases, id: \.self) { group in
                let items = Illustrations.all.filter { $0.group == group }
                if !items.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(settings.t(group.title)).font(.subheadline.weight(.semibold)).foregroundStyle(group.color)
                        ForEach(items) { scenario in
                            NavigationLink(value: Route.illustration(id: scenario.id)) {
                                HStack {
                                    Text(settings.t(scenario.title)).foregroundStyle(.primary).multilineTextAlignment(.leading)
                                    Spacer()
                                    Text(settings.t("\(scenario.steps.count) steps ›", "\(scenario.steps.count) 步 ›")).foregroundStyle(.secondary)
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
