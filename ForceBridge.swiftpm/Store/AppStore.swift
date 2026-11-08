import SwiftUI

struct Toast: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
}

/// Состояние приложения. Все данные живут в общей базе Supabase:
/// удалили или изменили карточку — это видно всем пользователям.
@MainActor
final class AppStore: ObservableObject {
    enum Phase: Equatable {
        case launching
        case signedOut
        case needsProfile
        case ready
        case failed(String)
    }

    // Сессия и профиль
    @Published private(set) var phase: Phase = .launching
    @Published private(set) var userID: UUID?
    @Published private(set) var email = ""
    @Published private(set) var me: Profile?

    // Лента
    @Published private(set) var feed: [Card] = []
    @Published private(set) var feedLoading = false
    @Published private(set) var feedError: String?
    @Published var query = ""
    @Published var kindFilter: CardKind?
    @Published var selectedCategories: Set<String> = []
    @Published var sort: FeedSort = .newest

    // Категории
    @Published private(set) var categories: [CategoryInfo] = CategoryInfo.defaults
    @Published private(set) var categoryCounts: [String: Int] = [:]

    // Кабинет
    @Published private(set) var myCards: [Card] = []
    @Published private(set) var favorites: [Profile] = []
    @Published private(set) var favoriteIDs: Set<UUID> = []
    @Published private(set) var myResponses: [ResponseRow] = []
    @Published private(set) var respondedCardIDs: Set<UUID> = []

    // ИИ-совместимость
    @Published private(set) var compat: [UUID: Compatibility] = [:]
    @Published private(set) var compatLoading: Set<UUID> = []
    @Published private(set) var compatErrors: [UUID: String] = [:]

    @Published var toast: Toast?

    let api = SupabaseClient(baseURL: SupabaseConfig.url, apiKey: SupabaseConfig.anonKey)

    // MARK: - Запуск и вход

    func bootstrap() async {
        guard SupabaseConfig.isConfigured else {
            phase = .signedOut
            return
        }
        guard let session = await api.restoreSession() else {
            phase = .signedOut
            return
        }
        userID = session.userId
        email = session.email
        await loadProfileAndRoute()
    }

    func retryLaunch() async {
        phase = .launching
        await bootstrap()
    }

    func signIn(email: String, password: String) async throws {
        let session = try await api.signIn(
            email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            password: password
        )
        userID = session.userId
        self.email = session.email
        await loadProfileAndRoute()
    }

    func register(email: String, password: String) async throws {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        try await api.register(email: cleanEmail, password: password)
        try await signIn(email: cleanEmail, password: password)
    }

    func signOut() async {
        await api.signOut()
        me = nil
        userID = nil
        email = ""
        feed = []
        myCards = []
        favorites = []
        favoriteIDs = []
        myResponses = []
        respondedCardIDs = []
        compat = [:]
        compatErrors = [:]
        selectedCategories = []
        query = ""
        kindFilter = nil
        phase = .signedOut
    }

    private func loadProfileAndRoute() async {
        guard let userID else {
            phase = .signedOut
            return
        }
        do {
            let rows = try await api.select(
                "profiles",
                query: [URLQueryItem(name: "id", value: "eq.\(userID.lower)")],
                as: [Profile].self
            )
            if let profile = rows.first {
                me = profile
                phase = .ready
                await afterLogin()
            } else {
                phase = .needsProfile
            }
        } catch APIError.unauthorized {
            await signOut()
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private func afterLogin() async {
        async let categoriesTask: Void = loadCategories()
        async let favoritesTask: Void = loadFavorites()
        async let responsesTask: Void = loadMyResponses()
        async let cardsTask: Void = loadMyCards()
        _ = await (categoriesTask, favoritesTask, responsesTask, cardsTask)
        await kickClassification()
    }

    // MARK: - Профиль

    func saveProfile(_ profile: Profile) async throws {
        let saved = try await api.upsert("profiles", body: profile, onConflict: "id", as: [Profile].self)
        me = saved.first ?? profile
        compat = [:]
        compatErrors = [:]
        if phase == .needsProfile {
            phase = .ready
            await afterLogin()
        }
    }

    func profile(id: UUID) async throws -> Profile {
        if let me, me.id == id { return me }
        let rows = try await api.select(
            "profiles",
            query: [URLQueryItem(name: "id", value: "eq.\(id.lower)")],
            as: [Profile].self
        )
        guard let first = rows.first else {
            throw APIError.server(status: 404, message: "Профиль не найден")
        }
        return first
    }

    func uploadResume(from url: URL) async throws {
        guard var profile = me else { return }
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing { url.stopAccessingSecurityScopedResource() }
        }
        let data = try Data(contentsOf: url)
        guard data.count <= 10_000_000 else {
            throw APIError.server(status: 413, message: "Файл больше 10 МБ. Сожмите резюме или сохраните его в PDF.")
        }
        let ext = url.pathExtension.lowercased()
        let safeExt = ext.isEmpty ? "pdf" : ext
        let path = "\(profile.id.lower)/resume.\(safeExt)"
        try await api.upload(bucket: "resumes", path: path, data: data, contentType: Self.mimeType(for: safeExt))
        profile.resumePath = path
        profile.resumeName = url.lastPathComponent
        try await saveProfile(profile)
        showToast("Резюме загружено", url.lastPathComponent)
    }

    func resumeFile(for profile: Profile) async throws -> URL {
        guard let path = profile.resumePath else {
            throw APIError.server(status: 404, message: "Резюме не загружено")
        }
        let data = try await api.download(bucket: "resumes", path: path)
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let name = profile.resumeName ?? "Резюме.\((path as NSString).pathExtension)"
        let file = folder.appendingPathComponent(name)
        try data.write(to: file)
        return file
    }

    private static func mimeType(for ext: String) -> String {
        switch ext {
        case "pdf": return "application/pdf"
        case "doc": return "application/msword"
        case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        default: return "application/octet-stream"
        }
    }

    // MARK: - Лента

    var formatCategories: [CategoryInfo] { categories.filter { $0.isFormat } }
    var fieldCategories: [CategoryInfo] { categories.filter { !$0.isFormat } }

    func category(_ key: String) -> CategoryInfo? {
        categories.first { $0.key == key }
    }

    /// Лента с учётом сортировки по совместимости (оценки считает ИИ).
    var displayedFeed: [Card] {
        guard sort == .match else { return feed }
        let indexed = Array(feed.enumerated())
        return indexed.sorted { left, right in
            let a = compat[left.element.id]?.score ?? -1
            let b = compat[right.element.id]?.score ?? -1
            if a != b { return a > b }
            return left.offset < right.offset
        }.map { $0.element }
    }

    var activeFilterCount: Int {
        selectedCategories.count + (kindFilter == nil ? 0 : 1)
    }

    func refreshFeed() async {
        guard me != nil else { return }
        feedLoading = true
        defer { feedLoading = false }
        let formatKeys = Set(formatCategories.map { $0.key })
        let formats = selectedCategories.filter { formatKeys.contains($0) }.sorted()
        let fields = selectedCategories.filter { !formatKeys.contains($0) }.sorted()
        let params = SearchParams(
            pFormats: formats,
            pFields: fields,
            pQuery: query.trimmingCharacters(in: .whitespacesAndNewlines),
            pKind: kindFilter?.rawValue ?? "",
            pSort: sort.rpcValue
        )
        do {
            feed = try await api.rpc("search_cards", params: params, as: [Card].self)
            feedError = nil
        } catch {
            feedError = error.localizedDescription
        }
        if sort == .match {
            await prefetchCompatibility(for: Array(feed.prefix(24)))
        }
    }

    func toggleCategory(_ key: String) {
        if selectedCategories.contains(key) {
            selectedCategories.remove(key)
        } else {
            selectedCategories.insert(key)
        }
    }

    func clearFilters() {
        selectedCategories = []
        kindFilter = nil
    }

    func loadCategories() async {
        if let list = try? await api.select(
            "categories",
            query: [URLQueryItem(name: "order", value: "sort")],
            as: [CategoryInfo].self
        ), !list.isEmpty {
            categories = list
        }
        await loadCategoryCounts()
    }

    func loadCategoryCounts() async {
        guard let rows = try? await api.rpc("category_counts", params: EmptyParams(), as: [CategoryCount].self) else { return }
        var counts: [String: Int] = [:]
        for row in rows {
            counts[row.key] = row.total
        }
        categoryCounts = counts
    }

    /// Просит сервер доразобрать карточки, которые ИИ ещё не классифицировал.
    func kickClassification() async {
        _ = try? await api.invoke("classify-card", body: PendingRequest(pending: true), as: IgnoredResponse.self)
    }

    // MARK: - Карточки

    func card(id: UUID) -> Card? {
        feed.first { $0.id == id } ?? myCards.first { $0.id == id } ?? myResponses.first { $0.cardId == id }?.card
    }

    func fetchCard(id: UUID) async throws -> Card {
        let rows = try await api.select(
            "card_feed",
            query: [URLQueryItem(name: "id", value: "eq.\(id.lower)")],
            as: [Card].self
        )
        guard let first = rows.first else {
            throw APIError.server(status: 404, message: "Объявление удалено автором")
        }
        replaceCard(first)
        return first
    }

    func isMine(_ card: Card) -> Bool {
        card.authorId == me?.id
    }

    func loadMyCards() async {
        guard let me else { return }
        do {
            myCards = try await api.select(
                "card_feed",
                query: [
                    URLQueryItem(name: "author_id", value: "eq.\(me.id.lower)"),
                    URLQueryItem(name: "order", value: "created_at.desc")
                ],
                as: [Card].self
            )
        } catch {
            showError(error)
        }
    }

    @discardableResult
    func saveCard(_ draft: CardDraft, editing original: Card?) async throws -> Card {
        let rows: [Card]
        if let original {
            rows = try await api.update(
                "cards",
                filters: [URLQueryItem(name: "id", value: "eq.\(original.id.lower)")],
                body: draft,
                as: [Card].self
            )
        } else {
            rows = try await api.insert("cards", body: draft, as: [Card].self)
        }
        guard let saved = rows.first else {
            throw APIError.server(status: 0, message: "Сервер не вернул объявление")
        }
        compat[saved.id] = nil
        await loadMyCards()
        await refreshFeed()
        watchClassification(of: saved.id)
        return saved
    }

    func deleteCard(_ card: Card) async throws {
        try await api.delete("cards", filters: [URLQueryItem(name: "id", value: "eq.\(card.id.lower)")])
        myCards.removeAll { $0.id == card.id }
        feed.removeAll { $0.id == card.id }
        compat[card.id] = nil
        await loadCategoryCounts()
        showToast("Объявление удалено", "Оно исчезло из ленты у всех пользователей.")
    }

    private func replaceCard(_ card: Card) {
        if let index = feed.firstIndex(where: { $0.id == card.id }) {
            feed[index] = card
        }
        if let index = myCards.firstIndex(where: { $0.id == card.id }) {
            myCards[index] = card
        }
    }

    /// Ждёт, пока ИИ разложит карточку по категориям, и обновляет её на экране.
    private func watchClassification(of id: UUID) {
        Task { [weak self] in
            for _ in 0..<12 {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                guard let self else { return }
                guard let card = try? await self.fetchCard(id: id) else { return }
                if card.aiStatus != "pending" {
                    await self.loadCategoryCounts()
                    return
                }
            }
            await self?.kickClassification()
        }
    }

    // MARK: - Отклики

    func hasResponded(to card: Card) -> Bool {
        respondedCardIDs.contains(card.id)
    }

    func myResponse(to card: Card) -> ResponseRow? {
        myResponses.first { $0.cardId == card.id }
    }

    func respond(to card: Card, message: String) async throws {
        guard let me else { return }
        let body = NewResponse(cardId: card.id, userId: me.id, message: message.trimmingCharacters(in: .whitespacesAndNewlines))
        try await api.insertMinimal("responses", body: body)
        respondedCardIDs.insert(card.id)
        await loadMyResponses()
        showToast("Отклик отправлен", "Автор увидит ваш профиль и контакты.")
    }

    func withdrawResponse(to card: Card) async throws {
        guard let me else { return }
        try await api.delete(
            "responses",
            filters: [
                URLQueryItem(name: "card_id", value: "eq.\(card.id.lower)"),
                URLQueryItem(name: "user_id", value: "eq.\(me.id.lower)")
            ]
        )
        respondedCardIDs.remove(card.id)
        myResponses.removeAll { $0.cardId == card.id }
    }

    func responses(for card: Card) async throws -> [ResponseRow] {
        try await api.select(
            "responses",
            query: [
                URLQueryItem(name: "select", value: "*,profile:profiles(*)"),
                URLQueryItem(name: "card_id", value: "eq.\(card.id.lower)"),
                URLQueryItem(name: "hidden", value: "is.false"),
                URLQueryItem(name: "order", value: "created_at.desc")
            ],
            as: [ResponseRow].self
        )
    }

    /// Убирает человека из списка откликнувшихся (для автора карточки).
    func removeResponse(_ response: ResponseRow) async throws {
        try await api.updateMinimal(
            "responses",
            filters: [URLQueryItem(name: "id", value: "eq.\(response.id.lower)")],
            body: HiddenPatch(hidden: true)
        )
        if let index = myCards.firstIndex(where: { $0.id == response.cardId }), let count = myCards[index].responsesCount {
            myCards[index].responsesCount = max(0, count - 1)
        }
    }

    func loadMyResponses() async {
        guard let me else { return }
        do {
            let rows = try await api.select(
                "responses",
                query: [
                    URLQueryItem(name: "select", value: "*,card:cards(*)"),
                    URLQueryItem(name: "user_id", value: "eq.\(me.id.lower)"),
                    URLQueryItem(name: "order", value: "created_at.desc")
                ],
                as: [ResponseRow].self
            )
            myResponses = rows
            respondedCardIDs = Set(rows.map { $0.cardId })
        } catch {
            showError(error)
        }
    }

    // MARK: - Избранное

    func isFavorite(_ profile: Profile) -> Bool {
        favoriteIDs.contains(profile.id)
    }

    func toggleFavorite(_ profile: Profile) async {
        guard let me, me.id != profile.id else { return }
        if favoriteIDs.contains(profile.id) {
            favoriteIDs.remove(profile.id)
            favorites.removeAll { $0.id == profile.id }
            do {
                try await api.delete(
                    "favorites",
                    filters: [
                        URLQueryItem(name: "owner_id", value: "eq.\(me.id.lower)"),
                        URLQueryItem(name: "profile_id", value: "eq.\(profile.id.lower)")
                    ]
                )
            } catch {
                favoriteIDs.insert(profile.id)
                favorites.insert(profile, at: 0)
                showError(error)
            }
        } else {
            favoriteIDs.insert(profile.id)
            favorites.insert(profile, at: 0)
            do {
                try await api.insertMinimal("favorites", body: NewFavorite(ownerId: me.id, profileId: profile.id))
                showToast("Добавлено в избранное", profile.fullName)
            } catch {
                favoriteIDs.remove(profile.id)
                favorites.removeAll { $0.id == profile.id }
                showError(error)
            }
        }
    }

    func loadFavorites() async {
        do {
            let rows = try await api.select(
                "favorites",
                query: [
                    URLQueryItem(name: "select", value: "profile_id,created_at,profile:profiles!favorites_profile_id_fkey(*)"),
                    URLQueryItem(name: "order", value: "created_at.desc")
                ],
                as: [FavoriteRow].self
            )
            favorites = rows.compactMap { $0.profile }
            favoriteIDs = Set(rows.map { $0.profileId })
        } catch {
            showError(error)
        }
    }

    // MARK: - ИИ-совместимость

    func compatibility(for card: Card, force: Bool = false) async {
        guard let me, card.authorId != me.id else { return }
        if !force, compat[card.id] != nil { return }
        await requestCompatibility(ids: [card.id], force: force)
    }

    func prefetchCompatibility(for cards: [Card]) async {
        guard let me else { return }
        let ids = cards
            .filter { $0.authorId != me.id && compat[$0.id] == nil && !compatLoading.contains($0.id) }
            .map { $0.id }
        for chunk in ids.chunked(into: 6) {
            await requestCompatibility(ids: chunk, force: false)
        }
    }

    private func requestCompatibility(ids: [UUID], force: Bool) async {
        guard !ids.isEmpty else { return }
        for id in ids {
            compatLoading.insert(id)
            compatErrors[id] = nil
        }
        defer {
            for id in ids {
                compatLoading.remove(id)
            }
        }
        do {
            let response = try await api.invoke(
                "compatibility",
                body: CompatibilityRequest(cardIds: ids.map { $0.lower }, force: force),
                as: CompatibilityResponse.self
            )
            for (key, value) in response.results {
                if let id = UUID(uuidString: key) {
                    compat[id] = value
                }
            }
            if let message = response.error {
                for id in ids where compat[id] == nil {
                    compatErrors[id] = message
                }
            }
        } catch {
            for id in ids {
                compatErrors[id] = error.localizedDescription
            }
        }
    }

    // MARK: - Уведомления

    func showToast(_ title: String, _ message: String = "") {
        let next = Toast(title: title, message: message)
        toast = next
        let nextID = next.id
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_400_000_000)
            if self?.toast?.id == nextID {
                self?.toast = nil
            }
        }
    }

    func showError(_ error: Error) {
        showToast("Не получилось", error.localizedDescription)
    }
}
