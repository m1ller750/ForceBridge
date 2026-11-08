import SwiftUI
import QuickLook
import UIKit

/// Профиль участника. Если открыт из списка откликов — с действиями автора:
/// убрать из откликов и добавить в избранное.
struct ProfileDetailView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let profileID: UUID
    var response: ResponseRow? = nil

    @State private var loaded: Profile?
    @State private var loadError: String?
    @State private var resumeURL: URL?
    @State private var resumeLoading = false
    @State private var confirmRemove = false
    @State private var copied = false

    private var profile: Profile? {
        loaded ?? response?.profile
    }

    var body: some View {
        Group {
            if let profile {
                content(profile)
            } else if let loadError {
                EmptyNote(title: "Профиль недоступен", message: loadError)
                    .padding(Metrics.gutter)
                    .frame(maxHeight: .infinity, alignment: .top)
            } else {
                LoadingNote(text: "Открываем профиль…")
                    .padding(Metrics.gutter)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .paperBackground()
        .detailNavigation(response == nil ? "Профиль" : "Отклик")
        .task {
            await load()
        }
        .quickLookPreview($resumeURL)
        .confirmationDialog("Убрать из откликов?", isPresented: $confirmRemove, titleVisibility: .visible) {
            Button("Убрать", role: .destructive) {
                removeResponse()
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Человек исчезнет из списка откликнувшихся на ваше объявление.")
        }
    }

    private func content(_ profile: Profile) -> some View {
        let isMe = profile.id == store.me?.id
        return ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                if let response {
                    responseNote(response)
                }
                TitleBlock(profile: profile, isMe: isMe)
                contacts(profile)
                if !profile.about.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionTitle(number: "01", title: "О себе")
                        Text(profile.about)
                            .font(Typo.serif(17))
                            .foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }
                }
                if !profile.skills.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle(number: "02", title: "Навыки", trailing: "\(profile.skills.count)")
                        TagList(tags: profile.skills)
                    }
                }
                if !profile.projects.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        SectionTitle(number: "03", title: "Проекты", trailing: "\(profile.projects.count)")
                        NumberedList(items: profile.projects)
                    }
                }
                if !profile.achievements.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        SectionTitle(number: "04", title: "Достижения", trailing: "\(profile.achievements.count)")
                        NumberedList(items: profile.achievements)
                    }
                }
                resume(profile)
                if !isMe {
                    actions(profile)
                }
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.top, 16)
            .padding(.bottom, 40)
            .contentColumn()
        }
        .scrollIndicators(.hidden)
    }

    private func responseNote(_ response: ResponseRow) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                MonoLabel("Откликнулся на ваше объявление", color: Palette.signal, size: 10, weight: .bold)
                Spacer()
                MonoLabel(Fmt.created(response.createdAt), color: Palette.faint, size: 10)
            }
            if !response.message.isEmpty {
                Text("«\(response.message)»")
                    .font(Typo.serif(17))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(Palette.signalSoft)
        .overlay { Rectangle().strokeBorder(Palette.signal, lineWidth: 1) }
    }

    private func contacts(_ profile: Profile) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(number: "→", title: "Связь")
            HStack(alignment: .center, spacing: 12) {
                CodeTag(text: profile.messenger.code, style: .filled, label: profile.messenger.title)
                VStack(alignment: .leading, spacing: 2) {
                    MonoLabel(profile.messenger.title, color: Palette.faint, size: 9.5)
                    Text(profile.contact)
                        .font(Typo.mono(15, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                        .textSelection(.enabled)
                }
                Spacer()
            }
            HStack(spacing: 8) {
                if let url = profile.messenger.url(for: profile.contact) {
                    Link(destination: url) {
                        Text(profile.messenger == .phone ? "Позвонить" : "Написать")
                            .font(Typo.mono(12, weight: .bold))
                            .textCase(.uppercase)
                            .foregroundStyle(Palette.onSignal)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Palette.signal)
                    }
                }
                Button(copied ? "Скопировано" : "Скопировать") {
                    UIPasteboard.general.string = profile.contact
                    copied = true
                    Task {
                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                        copied = false
                    }
                }
                .buttonStyle(.outline)
            }
        }
    }

    private func resume(_ profile: Profile) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(number: "→", title: "Резюме")
            if profile.hasResume {
                Button {
                    openResume(profile)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 18, weight: .semibold))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(profile.resumeName ?? "Резюме")
                                .font(Typo.subhead.weight(.semibold))
                                .lineLimit(1)
                            MonoLabel(resumeLoading ? "Загружаем…" : "Открыть", color: Palette.graphite, size: 10)
                        }
                        Spacer()
                        Image(systemName: "arrow.down.to.line")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(Palette.ink)
                    .padding(14)
                    .overlay { Rectangle().strokeBorder(Palette.ink, lineWidth: 1.2) }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(resumeLoading)
            } else {
                Text("Резюме не загружено.")
                    .font(Typo.footnote)
                    .foregroundStyle(Palette.graphite)
            }
        }
    }

    @ViewBuilder
    private func actions(_ profile: Profile) -> some View {
        VStack(spacing: 10) {
            Button(store.isFavorite(profile) ? "В избранном — убрать" : "В избранное") {
                Task { await store.toggleFavorite(profile) }
            }
            .buttonStyle(.ink)
            if response != nil {
                Button("Убрать из откликов") {
                    confirmRemove = true
                }
                .buttonStyle(.outline)
            }
        }
    }

    // MARK: Действия

    private func load() async {
        do {
            loaded = try await store.profile(id: profileID)
            loadError = nil
        } catch {
            if profile == nil {
                loadError = error.localizedDescription
            }
        }
    }

    private func openResume(_ profile: Profile) {
        resumeLoading = true
        Task {
            do {
                resumeURL = try await store.resumeFile(for: profile)
            } catch {
                store.showError(error)
            }
            resumeLoading = false
        }
    }

    private func removeResponse() {
        guard let response else { return }
        Task {
            do {
                try await store.removeResponse(response)
                store.showToast("Убрано из откликов", response.profile?.fullName ?? "")
                dismiss()
            } catch {
                store.showError(error)
            }
        }
    }
}
