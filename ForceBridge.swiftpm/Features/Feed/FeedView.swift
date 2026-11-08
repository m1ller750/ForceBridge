import SwiftUI

struct FeedView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showEditor = false
    @State private var showFilters = false

    /// Меняется при любом изменении поиска, фильтра или сортировки.
    private var filterKey: String {
        [
            store.query,
            store.kindFilter?.rawValue ?? "",
            store.selectedCategories.sorted().joined(separator: ","),
            store.sort.rawValue
        ].joined(separator: "|")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenHeader(
                    index: "01",
                    title: "Объявления",
                    subtitle: "Ищут сокомандников на конкурсы и людей для исследований. Категории расставляет ИИ."
                ) {
                    Button {
                        showEditor = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 11, weight: .bold))
                            Text("НОВОЕ")
                                .font(Typo.mono(11, weight: .bold))
                        }
                        .foregroundStyle(Palette.onSignal)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(Palette.signal)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Новое объявление")
                }
                .padding(.bottom, 16)

                searchField
                    .padding(.bottom, 12)

                kindChips
                    .padding(.bottom, 10)

                controls
                    .padding(.bottom, 10)

                if !store.selectedCategories.isEmpty {
                    activeFilters
                        .padding(.bottom, 10)
                }

                content
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.top, 12)
            .padding(.bottom, 32)
            .contentColumn()
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .refreshable {
            await store.refreshFeed()
            await store.loadCategoryCounts()
        }
        .paperBackground()
        .toolbar(.hidden, for: .navigationBar)
        .task(id: filterKey) {
            try? await Task.sleep(nanoseconds: 280_000_000)
            guard !Task.isCancelled else { return }
            await store.refreshFeed()
        }
        .sheet(isPresented: $showEditor) {
            CardEditorView(editing: nil)
        }
        .sheet(isPresented: $showFilters) {
            FilterSheet()
        }
    }

    // MARK: Поиск и фильтры

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.graphite)
            TextField("Конкурс, роль, навык, автор", text: $store.query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .font(Typo.body)
            if !store.query.isEmpty {
                Button {
                    store.query = ""
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Palette.graphite)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Очистить поиск")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Palette.surface)
        .overlay { Rectangle().strokeBorder(Palette.lineStrong, lineWidth: 1) }
    }

    private var kindChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Chip(title: "Все", isOn: store.kindFilter == nil) {
                    store.kindFilter = nil
                }
                ForEach(CardKind.allCases) { kind in
                    Chip(title: kind.shortTitle, isOn: store.kindFilter == kind) {
                        store.kindFilter = store.kindFilter == kind ? nil : kind
                    }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: store.kindFilter)
    }

    private var controls: some View {
        HStack(spacing: 8) {
            Button {
                showFilters = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 11, weight: .bold))
                    Text("КАТЕГОРИИ")
                        .font(Typo.mono(11, weight: .bold))
                    if !store.selectedCategories.isEmpty {
                        Text("\(store.selectedCategories.count)")
                            .font(Typo.mono(10, weight: .bold))
                            .foregroundStyle(Palette.onSignal)
                            .padding(.horizontal, 4)
                            .background(Palette.signal)
                    }
                }
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .overlay { Rectangle().strokeBorder(Palette.ink, lineWidth: 1) }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Menu {
                Picker("Сортировка", selection: $store.sort) {
                    ForEach(FeedSort.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 11, weight: .bold))
                    Text(store.sort.title.uppercased())
                        .font(Typo.mono(11, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .overlay { Rectangle().strokeBorder(Palette.ink, lineWidth: 1) }
                .contentShape(Rectangle())
            }

            Spacer(minLength: 4)
            MonoLabel("\(store.feed.count)", color: Palette.graphite)
        }
    }

    private var activeFilters: some View {
        FlowLayout(spacing: 6, lineSpacing: 6) {
            ForEach(store.selectedCategories.sorted(), id: \.self) { key in
                Button {
                    store.toggleCategory(key)
                } label: {
                    HStack(spacing: 6) {
                        Text(store.category(key)?.title ?? key)
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .font(Typo.mono(11, weight: .medium))
                    .foregroundStyle(Palette.paper)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Palette.ink)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Убрать фильтр \(store.category(key)?.title ?? key)")
            }
        }
    }

    // MARK: Список

    @ViewBuilder
    private var content: some View {
        if store.feedLoading && store.feed.isEmpty {
            LoadingNote(text: "Загружаем объявления…")
        } else if let error = store.feedError, store.feed.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                EmptyNote(title: "Лента не загрузилась", message: error)
                Button("Повторить") {
                    Task { await store.refreshFeed() }
                }
                .buttonStyle(.outline)
            }
        } else if store.displayedFeed.isEmpty {
            EmptyNote(
                title: store.activeFilterCount > 0 || !store.query.isEmpty ? "Ничего не нашлось" : "Пока нет объявлений",
                message: store.activeFilterCount > 0 || !store.query.isEmpty
                    ? "Уберите часть фильтров или измените запрос."
                    : "Опубликуйте первое: «ищу сокомандника на конкурс» или «нужен человек для исследования»."
            )
        } else {
            if store.sort == .match {
                HStack(spacing: 8) {
                    AIBadge()
                    Text("Порядок — по оценке ИИ: насколько объявление подходит вашему профилю.")
                        .font(Typo.footnote)
                        .foregroundStyle(Palette.graphite)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 8)
            }
            Hairline(color: Palette.lineStrong)
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(store.displayedFeed) { card in
                    NavigationLink(value: Route.card(card.id)) {
                        CardRow(
                            card: card,
                            compatibility: store.compat[card.id],
                            compatibilityLoading: store.compatLoading.contains(card.id),
                            isMine: store.isMine(card),
                            responded: store.hasResponded(to: card)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

/// Категории для фильтра. Их расставляет ИИ, поэтому фильтр точный и быстрый.
struct FilterSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    HStack(alignment: .top, spacing: 10) {
                        AIBadge()
                        Text("ИИ читает каждое новое объявление и относит его к одной или нескольким категориям. Изменили объявление — ИИ разберёт его заново, удалили — оно пропадёт из всех категорий.")
                            .font(Typo.footnote)
                            .foregroundStyle(Palette.graphite)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    group(number: "A", title: "Формат", items: store.formatCategories)
                    group(number: "B", title: "Область", items: store.fieldCategories)

                    Text("Внутри группы подходит любая из выбранных категорий, между группами — обе сразу. Например, «Хакатоны» + «ИИ и данные» покажет хакатоны по ИИ.")
                        .font(Typo.footnote)
                        .foregroundStyle(Palette.graphite)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(Metrics.gutter)
                .contentColumn()
            }
            .paperBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Сбросить") {
                        store.selectedCategories = []
                    }
                    .disabled(store.selectedCategories.isEmpty)
                }
                ToolbarItem(placement: .principal) {
                    MonoLabel("Категории", color: Palette.ink, weight: .semibold)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Palette.paper)
        .task {
            await store.loadCategoryCounts()
        }
    }

    private func group(number: String, title: String, items: [CategoryInfo]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(number: number, title: title)
            FlowLayout(spacing: 6, lineSpacing: 6) {
                ForEach(items) { category in
                    let count = store.categoryCounts[category.key] ?? 0
                    Chip(title: "\(category.title) · \(count)", isOn: store.selectedCategories.contains(category.key)) {
                        store.toggleCategory(category.key)
                    }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: store.selectedCategories)
    }
}
