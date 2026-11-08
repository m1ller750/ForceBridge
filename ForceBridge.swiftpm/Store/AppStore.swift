import SwiftUI
import UIKit

struct Toast: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
}

/// Состояние приложения. Все данные живут на сервере ForceBridge (Cloudflare Worker + D1):
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

    let api = APIClient(baseURL: ServerConfig.baseURL)

    // MARK: - Запуск и вход

    func bootstrap() async {
        guard ServerConfig.isConfigured, let session = await api.currentSession() else {
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
        let session = try await api.signIn(email: clean(email), password: password)
        userID = session.userId
        self.email = session.email
        await loadProfileAndRoute()
    }

    func register(email: String, password: String) async throws {
        let session = try await api.register(email: clean(email), password: password)
        userID = session.userId
        self.email = session.email
        await loadProfileAndRoute()
    }

    func signOut() async {
        await api.signOut()
        resetState()
        phase = .signedOut
    }

    private func clean(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func resetState() {
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
    }

    private func loadProfileAndRoute() async {
        do {
            let response = try await api.get("me", as: MeResponse.self)
            userID = response.userId
            email = response.email
            if let profile = response.profile {
                me = profile
                phase = .ready
                await afterLogin()
            } else {
                phase = .needsProfile
            }
        } catch APIError.unauthorized {
            resetState()
            phase = .signedOut
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

    /// Ошибка «сессия истекла» возвращает на экран входа.
    private func handle(_ error: Error) {
        if case APIError.unauthorized = error {
            resetState()
            phase = .signedOut
            showToast("Сессия истекла", "Войдите снова.")
        } else {
            showError(error)
        }
    }

    // MARK: - Профиль

    func saveProfile(_ profile: Profile) async throws {
        let saved = try await api.send("PUT", "profile", body: profile, as: Profile.self)
        me = saved
        compat = [:]
        compatErrors = [:]
        if phase == .needsProfile {
            phase = .ready
            await afterLogin()
        }
    }

    func profile(id: UUID) async throws -> Profile {
        if let me, me.id == id { return me }
        return try await api.get("profiles/\(id.lower)", as: Profile.self)
    }

    func uploadResume(from url: URL) async throws {
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing { url.stopAccessingSecurityScopedResource() }
        }
        var data = try Data(contentsOf: url)
        var fileName = url.lastPathComponent
        var ext = url.pathExtension.lowercased()

        // Фото сжимаем, чтобы уложиться в лимит сервера.
        if ["jpg", "jpeg", "png", "heic"].contains(ext), data.count > 1_500_000, let image = UIImage(data: data) {
            if let compressed = Self.compressedJPEG(image, limit: 1_500_000) {
                data = compressed
                ext = "jpg"
                fileName = (fileName as NSString).deletingPathExtension + ".jpg"
            }
        }
        guard data.count <= 1_800_000 else {
            throw APIError.server(status: 413, message: "Файл больше 1,8 МБ. Сожмите PDF или загрузите фото резюме.")
        }
        let saved = try await api.upload(
            "profile/resume",
            data: data,
            contentType: Self.mimeType(for: ext),
            fileName: fileName,
            as: Profile.self
        )
        me = saved
        showToast("Резюме загружено", fileName)
    }

    func resumeFile(for profile: Profile) async throws -> URL {
        let data = try await api.download("profiles/\(profile.id.lower)/resume")
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appendingPathComponent(profile.resumeName ?? "Резюме.pdf")
        try data.write(to: file)
        return file
    }

    private static func compressedJPEG(_ image: UIImage, limit: Int) -> Data? {
        var quality: CGFloat = 0.8
        var current = image
        for _ in 0..<6 {
            if let data = current.jpegData(compressionQuality: quality), data.count <= limit {
                return data
            }
            quality -= 0.12
            if quality < 0.35 {
                let size = CGSize(width: current.size.width * 0.75, height: current.size.height * 0.75)
                let renderer = UIGraphicsImageRenderer(size: size)
                current = renderer.image { _ in current.draw(in: CGRect(origin: .zero, size: size)) }
                quality = 0.7
            }
        }
        return current.jpegData(compressionQuality: 0.5)
    }

    private static func mimeType(for ext: String) -> String {
        switch ext {
        case "pdf": return "application/pdf"
        case "doc": return "application/msword"
        case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        default: return "application/pdf"
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
        let request = SearchRequest(
            formats: selectedCategories.filter { formatKeys.contains($0) }.sorted(),
            fields: selectedCategories.filter { !formatKeys.contains($0) }.sorted(),
            query: query.trimmingCharacters(in: .whitespacesAndNewlines),
            kind: kindFilter?.rawValue ?? "",
            sort: sort.rpcValue
        )
        do {
            feed = try await api.send("POST", "cards/search", body: request, as: [Card].self)
            feedError = nil
        } catch APIError.unauthorized {
            handle(APIError.unauthorized)
            return
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
        if let list = try? await api.get("categories", as: [CategoryInfo].self), !list.isEmpty {
            categories = list
        }
        await loadCategoryCounts()
    }

    func loadCategoryCounts() async {
        guard let rows = try? await api.get("categories/counts", as: [CategoryCount].self) else { return }
        var counts: [String: Int] = [:]
        for row in rows {
            counts[row.key] = row.total
        }
        categoryCounts = counts
    }

    /// Просит сервер доразобрать карточки, которые ИИ ещё не классифицировал.
    func kickClassification() async {
        _ = try? await api.post("ai/classify-pending", as: IgnoredResponse.self)
    }

    // MARK: - Карточки

    func card(id: UUID) -> Card? {
        feed.first { $0.id == id } ?? myCards.first { $0.id == id } ?? myResponses.first { $0.cardId == id }?.card
    }

    func fetchCard(id: UUID) async throws -> Card {
        let card = try await api.get("cards/\(id.lower)", as: Card.self)
        replaceCard(card)
        return card
    }

    func isMine(_ card: Card) -> Bool {
        card.authorId == me?.id
    }

    func loadMyCards() async {
        do {
            myCards = try await api.get("my/cards", as: [Card].self)
        } catch {
            handle(error)
        }
    }

    @discardableResult
    func saveCard(_ draft: CardDraft, editing original: Card?) async throws -> Card {
        let saved: Card
        if let original {
            saved = try await api.send("PATCH", "cards/\(original.id.lower)", body: draft, as: Card.self)
        } else {
            saved = try await api.send("POST", "cards", body: draft, as: Card.self)
        }
        compat[saved.id] = nil
        await loadMyCards()
        await refreshFeed()
        watchClassification(of: saved.id)
        return saved
    }

    func deleteCard(_ card: Card) async throws {
        try await api.send("DELETE", "cards/\(card.id.lower)")
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
        let body = ResponseRequest(message: message.trimmingCharacters(in: .whitespacesAndNewlines))
        try await api.send("POST", "cards/\(card.id.lower)/responses", body: body)
        respondedCardIDs.insert(card.id)
        await loadMyResponses()
        showToast("Отклик отправлен", "Автор увидит ваш профиль и контакты.")
    }

    func withdrawResponse(to card: Card) async throws {
        try await api.send("DELETE", "cards/\(card.id.lower)/responses")
        respondedCardIDs.remove(card.id)
        myResponses.removeAll { $0.cardId == card.id }
    }

    func responses(for card: Card) async throws -> [ResponseRow] {
        try await api.get("cards/\(card.id.lower)/responses", as: [ResponseRow].self)
    }

    /// Убирает человека из списка откликнувшихся (для автора карточки).
    func removeResponse(_ response: ResponseRow) async throws {
        try await api.send("POST", "responses/\(response.id.lower)/hide")
        if let index = myCards.firstIndex(where: { $0.id == response.cardId }), let count = myCards[index].responsesCount {
            myCards[index].responsesCount = max(0, count - 1)
        }
    }

    func loadMyResponses() async {
        do {
            let rows = try await api.get("my/responses", as: [ResponseRow].self)
            myResponses = rows
            respondedCardIDs = Set(rows.map { $0.cardId })
        } catch {
            handle(error)
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
                try await api.send("DELETE", "favorites/\(profile.id.lower)")
            } catch {
                favoriteIDs.insert(profile.id)
                favorites.insert(profile, at: 0)
                handle(error)
            }
        } else {
            favoriteIDs.insert(profile.id)
            favorites.insert(profile, at: 0)
            do {
                try await api.send("PUT", "favorites/\(profile.id.lower)")
                showToast("Добавлено в избранное", profile.fullName)
            } catch {
                favoriteIDs.remove(profile.id)
                favorites.removeAll { $0.id == profile.id }
                handle(error)
            }
        }
    }

    func loadFavorites() async {
        do {
            let list = try await api.get("favorites", as: [Profile].self)
            favorites = list
            favoriteIDs = Set(list.map { $0.id })
        } catch {
            handle(error)
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
            let response = try await api.send(
                "POST",
                "ai/compatibility",
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
