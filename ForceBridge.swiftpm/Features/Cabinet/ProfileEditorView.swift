import SwiftUI

/// Редактор профиля из кабинета.
struct ProfileEditorView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ProfileDraft()
    @State private var loaded = false
    @State private var saving = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ProfileForm(draft: $draft)
                    if let errorText {
                        Text(errorText)
                            .font(Typo.footnote)
                            .foregroundStyle(Palette.signal)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Button(saving ? "Сохраняем…" : "Сохранить") {
                        save()
                    }
                    .buttonStyle(.signal)
                    .disabled(saving)
                    Text("После изменения профиля ИИ заново посчитает совместимость с объявлениями.")
                        .font(Typo.footnote)
                        .foregroundStyle(Palette.graphite)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(Metrics.gutter)
                .contentColumn()
            }
            .scrollDismissesKeyboard(.interactively)
            .paperBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .principal) {
                    MonoLabel("Паспорт участника", color: Palette.ink, weight: .semibold)
                }
            }
        }
        .presentationBackground(Palette.paper)
        .onAppear {
            guard !loaded, let me = store.me else { return }
            draft = ProfileDraft(profile: me)
            loaded = true
        }
    }

    private func save() {
        if let message = draft.validationMessage {
            errorText = message
            return
        }
        guard let me = store.me else { return }
        errorText = nil
        saving = true
        Task {
            do {
                try await store.saveProfile(draft.applied(to: me))
                store.showToast("Профиль сохранён")
                dismiss()
            } catch {
                errorText = error.localizedDescription
            }
            saving = false
        }
    }
}
