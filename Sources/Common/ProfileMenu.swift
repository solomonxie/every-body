import SwiftUI

/// Toolbar chip on every page: who the content is about.
struct ProfileMenu: View {
    @Environment(Settings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Menu {
            Picker(settings.t("Age", "年龄"), selection: $settings.age) {
                ForEach(AgeGroup.allCases, id: \.self) { Text(settings.t($0.label)).tag($0) }
            }
            Picker(settings.t("Sex", "性别"), selection: $settings.female) {
                Text(settings.t("Male", "男")).tag(false)
                Text(settings.t("Female", "女")).tag(true)
            }
            if settings.female && settings.age == .adult {
                Toggle(settings.t("Pregnant", "怀孕"), isOn: $settings.pregnant)
            }
        } label: {
            Label(label, systemImage: settings.age == .infant || settings.age == .child ? "figure.child" : "figure.stand")
                .labelStyle(.titleAndIcon)
                .font(.footnote.weight(.semibold))
        }
        .accessibilityLabel(settings.t("Person type", "人群"))
    }

    private var label: String {
        let sex = settings.female ? settings.t("F", "女") : settings.t("M", "男")
        let age: String = switch settings.age {
        case .infant: settings.t("Infant", "婴儿")
        case .child: settings.t("Child", "儿童")
        case .adult: settings.t("Adult", "成人")
        case .senior: settings.t("65+", "老人")
        }
        return settings.profile.isPregnant ? settings.t("Pregnant", "孕妇") : "\(age) \(sex)"
    }
}

extension View {
    func profileToolbar() -> some View {
        toolbar { ToolbarItem(placement: .topBarTrailing) { ProfileMenu() } }
    }
}
