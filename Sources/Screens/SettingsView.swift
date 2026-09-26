import SwiftUI

struct SettingsView: View {
    @Environment(Settings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section("Names 名称") {
                Picker("Names", selection: $settings.names) {
                    Text("English").tag(NameMode.en)
                    Text("中文").tag(NameMode.zh)
                    Text("Both 双语").tag(NameMode.both)
                }
                .pickerStyle(.segmented)
            }
            Section("Viewer 3D 视图") {
                Picker("Body 体型", selection: $settings.female) {
                    Text("Male 男").tag(false)
                    Text("Female 女").tag(true)
                }
                Toggle("White background 白色背景", isOn: $settings.whiteBackground)
                Toggle("Auto-rotate on open 自动旋转", isOn: $settings.autoRotate)
            }
            Section("About 关于") {
                Text("Body Atlas is for learning. It isn’t medical advice. Reflex and acupoint effects describe traditional practice, not proven treatment. In an emergency call 120 / 911.\n本应用仅供学习，不构成医疗建议。穴位与反射区功效为传统说法。紧急情况请拨打 120。")
                    .font(.footnote)
                Text("Ear points: GB/T 13734-2008. Acupoints: WHO Standard Acupuncture Point Locations (2008). First aid: ILCOR / Red Cross. All drawings are schematic, built from simple geometry.")
                    .font(.footnote).foregroundStyle(.secondary)
                LabeledContent("Version 版本", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
            }
        }
        .navigationTitle("Settings")
    }
}
