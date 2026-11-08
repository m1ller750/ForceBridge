import SwiftUI

/// Второй шаг регистрации: паспорт участника.
struct ProfileSetupView: View {
    @EnvironmentObject private var store: AppStore
    @State private var draft = ProfileDraft()
    @State private var saving = false
    @State private var errorText: String?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            MonoLabel("Шаг 2 / 2 · паспорт участника", color: Palette.graphite)
                            Spacer()
                            Button("Выйти") {
                                Task { await store.signOut() }
                            }
                            .font(Typo.mono(11, weight: .semibold))
                            .foregroundStyle(Palette.ink)
                        }
                        Text("Расскажите о себе")
                            .font(Typo.display(30, weight: .heavy))
                            .foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("По этим данным ИИ считает совместимость с объявлениями, а авторы решают, с кем связаться. Резюме можно загрузить потом в кабинете.")
                            .font(Typo.subhead)
                            .foregroundStyle(Palette.graphite)
                            .fixedSize(horizontal: false, vertical: true)
                        Ruler()
                            .padding(.top, 4)
                    }
                    ProfileForm(draft: $draft)
                }
                .padding(.horizontal, Metrics.gutter)
                .padding(.top, 16)
                .padding(.bottom, 32)
                .contentColumn()
            }
            .scrollDismissesKeyboard(.interactively)

            VStack(spacing: 8) {
                Hairline(color: Palette.lineStrong)
                if let errorText {
                    Text(errorText)
                        .font(Typo.footnote)
                        .foregroundStyle(Palette.signal)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Metrics.gutter)
                        .padding(.top, 6)
                }
                Button(saving ? "Сохраняем…" : "Сохранить и начать") {
                    save()
                }
                .buttonStyle(.signal)
                .disabled(saving)
                .padding(.horizontal, Metrics.gutter)
                .padding(.bottom, 10)
                .padding(.top, errorText == nil ? 10 : 0)
            }
            .contentColumn()
            .background(Palette.paper)
        }
        .paperBackground()
    }

    private func save() {
        if let message = draft.validationMessage {
            errorText = message
            return
        }
        guard let userID = store.userID else { return }
        errorText = nil
        saving = true
        Task {
            do {
                try await store.saveProfile(draft.applied(to: Profile.empty(id: userID)))
            } catch {
                errorText = error.localizedDescription
            }
            saving = false
        }
    }
}
