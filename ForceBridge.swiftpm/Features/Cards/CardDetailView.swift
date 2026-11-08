import SwiftUI

/// Подробная карточка: описание, категории и процент совместимости от ИИ.
/// Автор видит здесь же список откликнувшихся.
struct CardDetailView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let cardID: UUID

    @State private var fetched: Card?
    @State private var loadError: String?
    @State private var responses: [ResponseRow] = []
    @State private var responsesLoaded = false
    @State private var showRespond = false
    @State private var showEditor = false
    @State private var confirmDelete = false
    @State private var confirmWithdraw = false
    @State private var shownScore = 0

    private var card: Card? {
        store.card(id: cardID) ?? fetched
    }

    var body: some View {
        Group {
            if let card {
                content(card)
            } else if let loadError {
                EmptyNote(title: "Объявление недоступно", message: loadError)
                    .padding(Metrics.gutter)
                    .frame(maxHeight: .infinity, alignment: .top)
            } else {
                LoadingNote(text: "Открываем объявление…")
                    .padding(Metrics.gutter)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .paperBackground()
        .detailNavigation("Объявление")
        .task {
            await load()
        }
        .sheet(isPresented: $showRespond) {
            if let card {
                RespondSheet(card: card)
            }
        }
        .sheet(isPresented: $showEditor) {
            if let card {
                CardEditorView(editing: card)
            }
        }
        .confirmationDialog("Удалить объявление?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Удалить", role: .destructive) {
                delete()
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Оно исчезнет из ленты у всех пользователей, отклики тоже удалятся.")
        }
        .confirmationDialog("Отозвать отклик?", isPresented: $confirmWithdraw, titleVisibility: .visible) {
            Button("Отозвать", role: .destructive) {
                withdraw()
            }
            Button("Отмена", role: .cancel) {}
        }
    }

    // MARK: Содержимое

    private func content(_ card: Card) -> some View {
        let mine = store.isMine(card)
        return ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                header(card)
                if !mine {
                    compatibilityPanel(card)
                }
                Text(card.description)
                    .font(Typo.serif(18))
                    .foregroundStyle(Palette.ink)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                specs(card)
                categoriesBlock(card)
                actions(card, mine: mine)
                if mine {
                    responsesSection(card)
                }
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.top, 16)
            .padding(.bottom, 40)
            .contentColumn()
        }
        .scrollIndicators(.hidden)
        .refreshable {
            await load(force: true)
        }
    }

    private func header(_ card: Card) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                KindTag(kind: card.kind)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    MonoLabel("Создано", color: Palette.faint, size: 9)
                    Text(Fmt.created(card.createdAt))
                        .font(Typo.mono(11, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                }
            }
            Text(card.title)
                .font(Typo.display(27, weight: .heavy))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if !card.eventName.isEmpty {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    MonoLabel("Событие", color: Palette.faint, size: 10)
                    Text(card.eventName)
                        .font(Typo.subhead.weight(.semibold))
                        .foregroundStyle(Palette.ink)
                }
            }
            NavigationLink(value: Route.profile(card.authorId)) {
                HStack(spacing: 10) {
                    Monogram(initials: initials(card.authorName ?? ""), size: 30, emphasized: store.isMine(card))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(store.isMine(card) ? "Вы автор" : (card.authorName ?? "Автор"))
                            .font(Typo.subhead.weight(.semibold))
                            .foregroundStyle(Palette.ink)
                        if let occupation = card.authorOccupation, !occupation.isEmpty {
                            Text(occupation)
                                .font(Typo.footnote)
                                .foregroundStyle(Palette.graphite)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.faint)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Ruler()
        }
    }

    // MARK: ИИ-совместимость

    private func compatibilityPanel(_ card: Card) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                MonoLabel("Совместимость с вами", color: Palette.ink, size: 11, weight: .semibold)
                AIBadge()
                Spacer()
                if store.compat[card.id] != nil {
                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        Text("\(shownScore)")
                            .font(Typo.display(36, weight: .heavy))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Text("%")
                            .font(Typo.mono(15, weight: .bold))
                    }
                    .foregroundStyle(Palette.signal)
                }
            }

            if let result = store.compat[card.id] {
                SegmentBar(value: Double(shownScore) / 100, segments: 25, color: Palette.signal)
                    .frame(height: 8)
                if !result.summary.isEmpty {
                    Text(result.summary)
                        .font(Typo.subhead)
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !result.strengths.isEmpty || !result.gaps.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(result.strengths, id: \.self) { item in
                            reasonLine(mark: "+", text: item, color: Palette.ink)
                        }
                        ForEach(result.gaps, id: \.self) { item in
                            reasonLine(mark: "−", text: item, color: Palette.graphite)
                        }
                    }
                }
                Button {
                    Task { await store.compatibility(for: card, force: true) }
                } label: {
                    MonoLabel("Пересчитать", color: Palette.graphite, size: 10, weight: .semibold)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .disabled(store.compatLoading.contains(card.id))
            } else if store.compatLoading.contains(card.id) {
                TrussScanner()
                    .frame(height: 24)
                Text("ИИ сравнивает ваш профиль с объявлением: навыки, проекты, достижения, город и формат.")
                    .font(Typo.footnote)
                    .foregroundStyle(Palette.graphite)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let error = store.compatErrors[card.id] {
                Text(error)
                    .font(Typo.footnote)
                    .foregroundStyle(Palette.signal)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Повторить") {
                    Task { await store.compatibility(for: card, force: true) }
                }
                .buttonStyle(.outlineCompact)
            } else {
                Button("Рассчитать совместимость") {
                    Task { await store.compatibility(for: card) }
                }
                .buttonStyle(.outlineCompact)
            }
        }
        .padding(16)
        .background(Palette.surface)
        .overlay { Rectangle().strokeBorder(Palette.ink, lineWidth: 1.2) }
        .onAppear {
            shownScore = store.compat[card.id]?.score ?? 0
        }
        .onChange(of: store.compat[card.id]?.score) { _, newValue in
            withAnimation(.easeOut(duration: 0.8)) {
                shownScore = newValue ?? 0
            }
        }
    }

    private func reasonLine(mark: String, text: String, color: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(mark)
                .font(Typo.mono(13, weight: .bold))
                .foregroundStyle(mark == "+" ? Palette.signal : Palette.faint)
                .frame(width: 12)
            Text(text)
                .font(Typo.footnote)
                .foregroundStyle(color)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Детали

    private func specs(_ card: Card) -> some View {
        VStack(spacing: 0) {
            Hairline()
            if !card.roles.isEmpty {
                SpecRow(label: "Кого ищут", value: card.roles.joined(separator: ", "), accent: true)
            }
            SpecRow(label: "Формат", value: card.placeText)
            if let deadline = card.deadline {
                SpecRow(
                    label: "Дедлайн",
                    value: "\(Fmt.dayMonth(deadline)) — \(Fmt.countdown(deadline))",
                    accent: Fmt.daysUntil(deadline) <= 7
                )
            }
            SpecRow(label: "Создано", value: Fmt.numericFull(card.createdAt))
            if abs(card.updatedAt.timeIntervalSince(card.createdAt)) > 60 {
                SpecRow(label: "Изменено", value: Fmt.created(card.updatedAt))
            }
        }
    }

    private func categoriesBlock(_ card: Card) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                MonoLabel("Категории", color: Palette.ink, size: 11, weight: .semibold)
                AIBadge()
                Spacer()
            }
            CategoryStrip(card: card, compact: false)
        }
    }

    @ViewBuilder
    private func actions(_ card: Card, mine: Bool) -> some View {
        if mine {
            HStack(spacing: 8) {
                Button("Изменить") {
                    showEditor = true
                }
                .buttonStyle(.ink)
                Button("Удалить") {
                    confirmDelete = true
                }
                .buttonStyle(.outline)
            }
        } else if store.hasResponded(to: card) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Rectangle()
                        .fill(Palette.signal)
                        .frame(width: 10, height: 10)
                    Text(store.myResponse(to: card)?.hidden == true
                         ? "Автор убрал ваш отклик из списка"
                         : "Вы откликнулись — автор видит ваш профиль и контакты")
                        .font(Typo.mono(11.5, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay { Rectangle().strokeBorder(Palette.lineStrong, lineWidth: 1) }
                Button("Отозвать отклик") {
                    confirmWithdraw = true
                }
                .buttonStyle(.outline)
            }
        } else {
            Button("Откликнуться") {
                showRespond = true
            }
            .buttonStyle(.signal)
        }
    }

    // MARK: Отклики (видит только автор)

    private func responsesSection(_ card: Card) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle(number: "01", title: "Откликнулись", trailing: responsesLoaded ? "\(responses.count)" : nil)
            if !responsesLoaded {
                LoadingNote(text: "Загружаем отклики…")
            } else if responses.isEmpty {
                EmptyNote(
                    title: "Пока никто не откликнулся",
                    message: "Когда кто-то откликнется, здесь появится его профиль, резюме и контакты."
                )
                .padding(.top, 14)
            } else {
                ForEach(responses) { response in
                    if let profile = response.profile {
                        responseRow(response, profile: profile)
                    }
                }
            }
        }
    }

    private func responseRow(_ response: ResponseRow, profile: Profile) -> some View {
        HStack(alignment: .top, spacing: 6) {
            NavigationLink(value: Route.respondent(response)) {
                ProfileRow(
                    profile: profile,
                    note: response.message.isEmpty ? profile.occupation : "«\(response.message)»",
                    isFavorite: store.isFavorite(profile)
                )
            }
            .buttonStyle(.plain)
            Menu {
                Button(store.isFavorite(profile) ? "Убрать из избранного" : "В избранное") {
                    Task { await store.toggleFavorite(profile) }
                }
                Button("Убрать из откликов", role: .destructive) {
                    remove(response)
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 36, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Действия с откликом")
        }
    }

    // MARK: Действия

    private func load(force: Bool = false) async {
        do {
            let fresh = try await store.fetchCard(id: cardID)
            fetched = fresh
            loadError = nil
            if store.isMine(fresh) {
                await loadResponses(fresh)
            } else {
                await store.compatibility(for: fresh, force: false)
            }
        } catch {
            if card == nil || force {
                loadError = error.localizedDescription
                fetched = nil
            }
        }
    }

    private func loadResponses(_ card: Card) async {
        do {
            responses = try await store.responses(for: card)
        } catch {
            store.showError(error)
        }
        responsesLoaded = true
    }

    private func remove(_ response: ResponseRow) {
        Task {
            do {
                try await store.removeResponse(response)
                withAnimation {
                    responses.removeAll { $0.id == response.id }
                }
            } catch {
                store.showError(error)
            }
        }
    }

    private func delete() {
        guard let card else { return }
        Task {
            do {
                try await store.deleteCard(card)
                dismiss()
            } catch {
                store.showError(error)
            }
        }
    }

    private func withdraw() {
        guard let card else { return }
        Task {
            do {
                try await store.withdrawResponse(to: card)
            } catch {
                store.showError(error)
            }
        }
    }

    private func initials(_ name: String) -> String {
        let letters = name.split(separator: " ").prefix(2).compactMap { $0.first }.map { String($0) }
        let result = letters.joined().uppercased()
        return result.isEmpty ? "?" : result
    }
}

/// Отклик с сообщением автору.
struct RespondSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let card: Card
    @State private var message = ""
    @State private var sending = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        MonoLabel("Отклик на объявление")
                        Text(card.title)
                            .font(Typo.display(22, weight: .heavy))
                            .foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let me = store.me {
                        Text("Автор увидит ваш профиль, резюме и контакт: \(me.messenger.title) \(me.contact).")
                            .font(Typo.footnote)
                            .foregroundStyle(Palette.graphite)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    FieldBox(label: "Сообщение автору", hint: "\(message.count)/500") {
                        TextField("Почему вы и что готовы делать", text: $message, axis: .vertical)
                            .lineLimit(4...8)
                    }
                    .onChange(of: message) { _, newValue in
                        if newValue.count > 500 {
                            message = String(newValue.prefix(500))
                        }
                    }
                    if let errorText {
                        Text(errorText)
                            .font(Typo.footnote)
                            .foregroundStyle(Palette.signal)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Button(sending ? "Отправляем…" : "Откликнуться") {
                        send()
                    }
                    .buttonStyle(.signal)
                    .disabled(sending)
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
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Palette.paper)
    }

    private func send() {
        sending = true
        errorText = nil
        Task {
            do {
                try await store.respond(to: card, message: message)
                dismiss()
            } catch {
                errorText = error.localizedDescription
            }
            sending = false
        }
    }
}
