import SwiftUI

struct ProfileEditorView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ProfileDraft()
    @State private var newTrackItem = ""
    @State private var loaded = false

    private var isValid: Bool {
        draft.isIdentityValid && !draft.roles.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 14) {
                        SectionTitle(number: "01", title: "Кто вы")
                        IdentityFields(draft: $draft)
                    }
                    VStack(alignment: .leading, spacing: 14) {
                        SectionTitle(number: "02", title: "Роли", trailing: "\(draft.roles.count)/3")
                        RolePicker(selection: $draft.roles)
                    }
                    VStack(alignment: .leading, spacing: 14) {
                        SectionTitle(number: "03", title: "Темы", trailing: "\(draft.interests.count)")
                        TopicPicker(selection: $draft.interests)
                    }
                    VStack(alignment: .leading, spacing: 14) {
                        SectionTitle(number: "04", title: "Навыки", trailing: "\(draft.skills.count)")
                        SkillEditor(skills: $draft.skills, suggestions: draft.suggestedSkills)
                    }
                    VStack(alignment: .leading, spacing: 14) {
                        SectionTitle(number: "05", title: "Нагрузка и формат")
                        HoursRuler(value: $draft.hours)
                        FormatPicker(selection: $draft.format)
                    }
                    trackSection
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
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { save() }
                        .disabled(!isValid)
                }
            }
        }
        .presentationBackground(Palette.paper)
        .onAppear {
            guard !loaded, let me = store.me else { return }
            draft = ProfileDraft(person: me)
            loaded = true
        }
    }

    private var trackSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle(number: "06", title: "Послужной список", trailing: "\(draft.track.count)")
            ForEach(Array(draft.track.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(String(format: "%02d", index + 1))
                        .font(Typo.mono(11, weight: .semibold))
                        .foregroundStyle(Palette.faint)
                    Text(item)
                        .font(Typo.subhead)
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Button {
                        draft.track.remove(at: index)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Palette.graphite)
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Удалить запись")
                }
                .padding(.vertical, 8)
                .overlay(alignment: .bottom) { Hairline() }
            }
            HStack(spacing: 8) {
                TextField("Например: финал хакатона, 2026", text: $newTrackItem)
                    .submitLabel(.done)
                    .onSubmit(addTrackItem)
                    .font(Typo.body)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 11)
                    .background(Palette.surface)
                    .overlay { Rectangle().strokeBorder(Palette.lineStrong, lineWidth: 1) }
                Button("Добавить", action: addTrackItem)
                    .buttonStyle(.outlineCompact)
                    .disabled(newTrackItem.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.top, 12)
        }
    }

    private func addTrackItem() {
        let value = newTrackItem.trimmingCharacters(in: .whitespacesAndNewlines)
        newTrackItem = ""
        guard !value.isEmpty else { return }
        draft.track.append(value)
    }

    private func save() {
        guard let me = store.me else { return }
        store.updateProfile(draft.makePerson(id: me.id))
        dismiss()
    }
}
