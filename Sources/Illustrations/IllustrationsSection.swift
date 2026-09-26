import SwiftUI

extension IllustrationGroup {
    var symbol: String {
        switch self {
        case .firstAid: "cross.case.fill"
        case .bones: "bandage.fill"
        case .blood: "drop.fill"
        case .illness: "thermometer.medium"
        case .pregnancy: "figure.and.child.holdinghands"
        }
    }
}

/// Home page list of illustrations, by group — first aid first.
struct IllustrationsSection: View {
    @Environment(Settings.self) private var settings

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            VStack(alignment: .leading, spacing: Space.xxs) {
                SectionHeader(settings.t("Illustrations", "图解"))
                Text(settings.t("Watch each step, then try it yourself.", "先看每一步，再动手试一试。"))
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(IllustrationGroup.allCases, id: \.self) { group in
                let items = Illustrations.all.filter { $0.group == group }
                if !items.isEmpty { GroupCard(group: group, items: items) }
            }
        }
    }
}

private struct GroupCard: View {
    let group: IllustrationGroup
    let items: [Scenario]
    @Environment(Settings.self) private var settings
    @State private var expanded = false
    private let limit = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Space.m) {
                IconBadge(symbol: group.symbol, color: group.color)
                Text(settings.t(group.title)).font(.headline)
                Spacer(minLength: Space.s)
                Text("\(items.count)").font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
            }
            .padding(.horizontal, Space.l)
            .padding(.vertical, Space.m)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            let shown = expanded || items.count <= limit + 1 ? items : Array(items.prefix(limit))
            ForEach(shown) { scenario in
                Divider().padding(.leading, Space.l)
                NavigationLink(value: Route.illustration(id: scenario.id)) { row(scenario) }
                    .buttonStyle(RowButtonStyle())
            }
            if items.count > limit + 1 {
                Divider().padding(.leading, Space.l)
                Button {
                    withAnimation(.snappy) { expanded.toggle() }
                } label: {
                    HStack(spacing: Space.xs) {
                        Text(expanded ? settings.t("Show less", "收起") : settings.t("Show all \(items.count)", "全部 \(items.count) 个"))
                        Image(systemName: "chevron.down").rotationEffect(.degrees(expanded ? 180 : 0))
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.brand)
                    .frame(maxWidth: .infinity, minHeight: minTap)
                    .contentShape(.rect)
                }
                .buttonStyle(RowButtonStyle())
                .sensoryFeedback(.selection, trigger: expanded)
            }
        }
        .background(Color.card, in: .rect(cornerRadius: Radius.card, style: .continuous))
        .clipShape(.rect(cornerRadius: Radius.card, style: .continuous))
    }

    private func row(_ scenario: Scenario) -> some View {
        let steps = scenario.steps.count
        return HStack(spacing: Space.m) {
            VStack(alignment: .leading, spacing: Space.xxs) {
                Text(settings.t(scenario.title)).font(.body).foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                Text(settings.t("\(steps) steps", "\(steps) 步")).font(.footnote).foregroundStyle(.secondary)
            }
            Spacer(minLength: Space.s)
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, Space.l)
        .padding(.vertical, Space.m)
        .frame(minHeight: minTap)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}
