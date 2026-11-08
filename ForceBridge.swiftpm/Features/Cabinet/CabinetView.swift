import SwiftUI
import UniformTypeIdentifiers

/// Личный кабинет: профиль, мои объявления, избранное и мои отклики.
struct CabinetView: View {
    @EnvironmentObject private var store: AppStore
    @State private var section: Pane = .profile
    @State private var showProfileEditor = false
    @State private var showNewCard = false
    @State private var editingCard: Card?
    @State private var deletingCard: Card?
    @State private var confirmSignOut = false
    @State private var showImporter = false
    @State private var uploading = false

    enum Pane: String, CaseIterable, Identifiable {
        case profile, cards, favorites, responses

        var id: String { rawValue }

        var title: String {
            switch self {
            case .profile: return "Профиль"
            case .cards: return "Мои объявления"
            case .favorites: return "Избранное"
            case .responses: return "Мои отклики"
            }
        }
    }

    private var resumeTypes: [UTType] {
        var types: [UTType] = [.pdf, .jpeg, .png]
        if let docx = UTType("org.openxmlformats.wordprocessingml.document") { types.append(docx) }
        if let doc = UTType("com.microsoft.word.doc") { types.append(doc) }
        return types
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenHeader(
                    index: "03",
                    title: "Кабинет",
                    subtitle: "Ваш паспорт участника, объявления, избранные профили и отклики."
                ) {
                    Button {
                        showProfileEditor = true
                    } label: {
                        Text("ИЗМЕНИТЬ")
                            .font(Typo.mono(11, weight: .bold))
                            .foregroundStyle(Palette.ink)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .overlay { Rectangle().strokeBorder(Palette.ink, lineWidth: 1) }
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Изменить профиль")
                }
                .padding(.bottom, 16)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Pane.allCases) { item in
                            Chip(title: chipTitle(item), isOn: section == item) {
                                section = item
                            }
                        }
                    }
                }
                .sensoryFeedback(.selection, trigger: section)
                .padding(.bottom, 22)

                switch section {
                case .profile:
                    profileSection
                case .cards:
                    cardsSection
                case .favorites:
                    favoritesSection
                case .responses:
                    responsesSection
                }
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.top, 12)
            .padding(.bottom, 32)
            .contentColumn()
        }
        .scrollIndicators(.hidden)
        .refreshable {
            await store.loadMyCards()
            await store.loadFavorites()
            await store.loadMyResponses()
        }
        .paperBackground()
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showProfileEditor) {
            ProfileEditorView()
        }
        .sheet(isPresented: $showNewCard) {
            CardEditorView(editing: nil)
        }
        .sheet(item: $editingCard) { card in
            CardEditorView(editing: card)
        }
        .confirmationDialog(
            "Удалить объявление?",
            isPresented: Binding(get: { deletingCard != nil }, set: { if !$0 { deletingCard = nil } }),
            titleVisibility: .visible,
            presenting: deletingCard
        ) { card in
            Button("Удалить", role: .destructive) {
                Task {
                    do {
                        try await store.deleteCard(card)
                    } catch {
                        store.showError(error)
                    }
                }
            }
            Button("Отмена", role: .cancel) {}
        } message: { _ in
            Text("Оно исчезнет из ленты у всех пользователей, отклики тоже удалятся.")
        }
        .confirmationDialog("Выйти из аккаунта?", isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button("Выйти", role: .destructive) {
                Task { await store.signOut() }
            }
            Button("Отмена", role: .cancel) {}
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: resumeTypes) { result in
            switch result {
            case .success(let url):
                upload(url)
            case .failure(let error):
                store.showError(error)
            }
        }
        .task {
            await store.loadMyCards()
        }
    }

    private func chipTitle(_ item: Pane) -> String {
        switch item {
        case .cards: return store.myCards.isEmpty ? item.title : "\(item.title) · \(store.myCards.count)"
        case .favorites: return store.favorites.isEmpty ? item.title : "\(item.title) · \(store.favorites.count)"
        case .responses: return store.myResponses.isEmpty ? item.title : "\(item.title) · \(store.myResponses.count)"
        case .profile: return item.title
        }
    }

    // MARK: Профиль

    @ViewBuilder
    private var profileSection: some View {
        if let me = store.me {
            VStack(alignment: .leading, spacing: 24) {
                TitleBlock(profile: me, isMe: true)

                VStack(alignment: .leading, spacing: 8) {
                    SectionTitle(number: "→", title: "Связь")
                    HStack(spacing: 10) {
                        CodeTag(text: me.messenger.code, style: .filled, label: me.messenger.title)
                        Text(me.contact)
                            .font(Typo.mono(14, weight: .semibold))
                            .foregroundStyle(Palette.ink)
                        Spacer()
                    }
                    MonoLabel(store.email, color: Palette.faint, size: 10)
                }

                if !me.about.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionTitle(number: "01", title: "О себе")
                        Text(me.about)
                            .font(Typo.serif(17))
                            .foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if !me.skills.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle(number: "02", title: "Навыки", trailing: "\(me.skills.count)")
                        TagList(tags: me.skills)
                    }
                }
                if !me.projects.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        SectionTitle(number: "03", title: "Проекты", trailing: "\(me.projects.count)")
                        NumberedList(items: me.projects)
                    }
                }
                if !me.achievements.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        SectionTitle(number: "04", title: "Достижения", trailing: "\(me.achievements.count)")
                        NumberedList(items: me.achievements)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    SectionTitle(number: "05", title: "Резюме")
                    Text(me.hasResume
                         ? "Загружено: \(me.resumeName ?? "резюме"). Его увидят авторы объявлений, на которые вы откликнетесь."
                         : "PDF, Word или фото до 10 МБ. Авторы объявлений смогут открыть его из вашего отклика.")
                        .font(Typo.footnote)
                        .foregroundStyle(Palette.graphite)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(uploading ? "Загружаем…" : (me.hasResume ? "Заменить резюме" : "Загрузить резюме")) {
                        showImporter = true
                    }
                    .buttonStyle(.outline)
                    .disabled(uploading)
                }

                VStack(spacing: 10) {
                    Button("Изменить профиль") {
                        showProfileEditor = true
                    }
                    .buttonStyle(.ink)
                    Button("Выйти из аккаунта") {
                        confirmSignOut = true
                    }
                    .buttonStyle(.outline)
                }
            }
        }
    }

    // MARK: Мои объявления

    private var cardsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button("Новое объявление") {
                showNewCard = true
            }
            .buttonStyle(.signal)
            .padding(.bottom, 18)

            SectionTitle(number: "01", title: "Мои объявления", trailing: "\(store.myCards.count)")
            if store.myCards.isEmpty {
                EmptyNote(
                    title: "Объявлений пока нет",
                    message: "Опубликуйте карточку — её увидят все пользователи, а ИИ отнесёт её к нужным категориям."
                )
                .padding(.top, 14)
            }
            ForEach(store.myCards) { card in
                VStack(spacing: 0) {
                    NavigationLink(value: Route.card(card.id)) {
                        CardRow(card: card, isMine: true)
                    }
                    .buttonStyle(.plain)
                    HStack(spacing: 8) {
                        Button("Изменить") {
                            editingCard = card
                        }
                        .buttonStyle(.outlineCompact)
                        Button("Удалить") {
                            deletingCard = card
                        }
                        .buttonStyle(.outlineCompact)
                        Spacer()
                        NavigationLink(value: Route.card(card.id)) {
                            MonoLabel("Отклики: \(card.responsesCount ?? 0)", color: Palette.signal, size: 10.5, weight: .bold)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 12)
                    Hairline(color: Palette.lineStrong)
                }
            }
        }
    }

    // MARK: Избранное

    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle(number: "01", title: "Избранные профили", trailing: "\(store.favorites.count)")
            if store.favorites.isEmpty {
                EmptyNote(
                    title: "Здесь пока пусто",
                    message: "Открывайте профили откликнувшихся и нажимайте «В избранное», чтобы не потерять сильных кандидатов."
                )
                .padding(.top, 14)
            }
            ForEach(store.favorites) { profile in
                HStack(alignment: .top, spacing: 6) {
                    NavigationLink(value: Route.profile(profile.id)) {
                        ProfileRow(profile: profile)
                    }
                    .buttonStyle(.plain)
                    Button {
                        Task { await store.toggleFavorite(profile) }
                    } label: {
                        Image(systemName: "star.slash")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Palette.graphite)
                            .frame(width: 36, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Убрать \(profile.fullName) из избранного")
                }
            }
        }
    }

    // MARK: Мои отклики

    private var responsesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle(number: "01", title: "Куда я откликнулся", trailing: "\(store.myResponses.count)")
            if store.myResponses.isEmpty {
                EmptyNote(
                    title: "Откликов пока нет",
                    message: "Найдите объявление в ленте и нажмите «Откликнуться» — автор увидит ваш профиль."
                )
                .padding(.top, 14)
            }
            ForEach(store.myResponses) { response in
                NavigationLink(value: Route.card(response.cardId)) {
                    HStack(alignment: .top, spacing: 12) {
                        Rectangle()
                            .fill(response.hidden ? Palette.line : Palette.signal)
                            .frame(width: 10, height: 10)
                            .padding(.top, 5)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(response.card?.title ?? "Объявление")
                                .font(Typo.subhead.weight(.semibold))
                                .foregroundStyle(Palette.ink)
                                .multilineTextAlignment(.leading)
                            MonoLabel(
                                response.hidden ? "Автор убрал отклик" : "Отклик отправлен",
                                color: response.hidden ? Palette.faint : Palette.signal,
                                size: 10
                            )
                        }
                        Spacer()
                        MonoLabel(Fmt.created(response.createdAt), color: Palette.faint, size: 10)
                    }
                    .padding(.vertical, 13)
                    .overlay(alignment: .bottom) { Hairline() }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Резюме

    private func upload(_ url: URL) {
        uploading = true
        Task {
            do {
                try await store.uploadResume(from: url)
            } catch {
                store.showError(error)
            }
            uploading = false
        }
    }
}
