import Foundation

enum APIError: LocalizedError, Sendable {
    case notConfigured
    case unauthorized
    case server(status: Int, message: String)
    case decoding(String)
    case network(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Приложение не подключено к серверу: заполните App/SupabaseConfig.swift."
        case .unauthorized:
            return "Сессия истекла. Войдите снова."
        case .server(_, let message):
            return message
        case .decoding(let details):
            return "Сервер ответил в неожиданном формате. \(details)"
        case .network(let details):
            return "Нет связи с сервером. \(details)"
        }
    }
}

/// Тонкий клиент Supabase поверх URLSession: вход, PostgREST, RPC, функции и хранилище.
/// Без сторонних зависимостей, чтобы проект собирался в Swift Playgrounds.
actor SupabaseClient {
    private struct PasswordGrant: Encodable { let email: String; let password: String }
    private struct RefreshGrant: Encodable { let refreshToken: String }
    private struct TokenUser: Decodable { let id: UUID; let email: String? }
    private struct TokenResponse: Decodable {
        let accessToken: String
        let refreshToken: String
        let expiresIn: Double?
        let user: TokenUser
    }

    private let baseURL: URL
    private let apiKey: String
    private let urlSession: URLSession
    private let decoder = JSONCoding.makeDecoder()
    private let encoder = JSONCoding.makeEncoder()
    private var session: AuthSession?
    private var refreshTask: Task<AuthSession, Error>?

    init(baseURL: URL, apiKey: String) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 40
        configuration.waitsForConnectivity = false
        self.urlSession = URLSession(configuration: configuration)
        self.session = SessionStore.load()
    }

    // MARK: - Вход

    func currentSession() -> AuthSession? {
        session
    }

    /// Восстанавливает сохранённую сессию и при необходимости обновляет токен.
    func restoreSession() async -> AuthSession? {
        guard let stored = session else { return nil }
        if stored.expiresAt > Date().addingTimeInterval(60) {
            return stored
        }
        do {
            return try await refreshSession()
        } catch APIError.unauthorized {
            return nil
        } catch {
            // Нет сети — оставляем сессию, токен обновится при первом запросе.
            return stored
        }
    }

    func register(email: String, password: String) async throws {
        var request = try makeRequest(path: "functions/v1/register", method: "POST", authorized: false)
        request.httpBody = try encoder.encode(RegisterRequest(email: email, password: password))
        _ = try await send(request, retryOnUnauthorized: false)
    }

    func signIn(email: String, password: String) async throws -> AuthSession {
        var request = try makeRequest(
            path: "auth/v1/token",
            query: [URLQueryItem(name: "grant_type", value: "password")],
            method: "POST",
            authorized: false
        )
        request.httpBody = try encoder.encode(PasswordGrant(email: email, password: password))
        let data: Data
        do {
            data = try await send(request, retryOnUnauthorized: false)
        } catch APIError.server(let status, _) where status == 400 || status == 401 {
            throw APIError.server(status: status, message: "Неверная почта или пароль")
        }
        let token = try decode(TokenResponse.self, from: data)
        return store(token)
    }

    func signOut() async {
        if let token = session?.accessToken,
           var request = try? makeRequest(path: "auth/v1/logout", method: "POST", authorized: false) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            _ = try? await urlSession.data(for: request)
        }
        session = nil
        SessionStore.clear()
    }

    private func refreshSession() async throws -> AuthSession {
        if let refreshTask {
            return try await refreshTask.value
        }
        guard let current = session else { throw APIError.unauthorized }
        let task = Task { () async throws -> AuthSession in
            var request = try self.makeRequest(
                path: "auth/v1/token",
                query: [URLQueryItem(name: "grant_type", value: "refresh_token")],
                method: "POST",
                authorized: false
            )
            request.httpBody = try self.encoder.encode(RefreshGrant(refreshToken: current.refreshToken))
            let data: Data
            do {
                data = try await self.send(request, retryOnUnauthorized: false)
            } catch APIError.server(let status, _) where status == 400 || status == 401 {
                self.dropSession()
                throw APIError.unauthorized
            }
            let token = try self.decode(TokenResponse.self, from: data)
            return self.store(token)
        }
        refreshTask = task
        defer { refreshTask = nil }
        return try await task.value
    }

    private func store(_ token: TokenResponse) -> AuthSession {
        let lifetime = token.expiresIn ?? 3600
        let newSession = AuthSession(
            accessToken: token.accessToken,
            refreshToken: token.refreshToken,
            expiresAt: Date().addingTimeInterval(lifetime),
            userId: token.user.id,
            email: token.user.email ?? ""
        )
        session = newSession
        SessionStore.save(newSession)
        return newSession
    }

    private func dropSession() {
        session = nil
        SessionStore.clear()
    }

    private func ensureFreshToken() async throws {
        guard let current = session else { throw APIError.unauthorized }
        if current.expiresAt < Date().addingTimeInterval(60) {
            _ = try await refreshSession()
        }
    }

    // MARK: - Таблицы (PostgREST)

    func select<T: Decodable & Sendable>(_ table: String, query: [URLQueryItem], as type: T.Type) async throws -> T {
        try await ensureFreshToken()
        let request = try makeRequest(path: "rest/v1/\(table)", query: query)
        let data = try await send(request)
        return try decode(T.self, from: data)
    }

    func insert<T: Decodable & Sendable, B: Encodable & Sendable>(
        _ table: String,
        body: B,
        as type: T.Type
    ) async throws -> T {
        try await ensureFreshToken()
        var request = try makeRequest(path: "rest/v1/\(table)", method: "POST")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.httpBody = try encoder.encode(body)
        let data = try await send(request)
        return try decode(T.self, from: data)
    }

    func insertMinimal<B: Encodable & Sendable>(_ table: String, body: B) async throws {
        try await ensureFreshToken()
        var request = try makeRequest(path: "rest/v1/\(table)", method: "POST")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = try encoder.encode(body)
        _ = try await send(request)
    }

    func upsert<T: Decodable & Sendable, B: Encodable & Sendable>(
        _ table: String,
        body: B,
        onConflict: String,
        as type: T.Type
    ) async throws -> T {
        try await ensureFreshToken()
        var request = try makeRequest(
            path: "rest/v1/\(table)",
            query: [URLQueryItem(name: "on_conflict", value: onConflict)],
            method: "POST"
        )
        request.setValue("return=representation,resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        request.httpBody = try encoder.encode(body)
        let data = try await send(request)
        return try decode(T.self, from: data)
    }

    func update<T: Decodable & Sendable, B: Encodable & Sendable>(
        _ table: String,
        filters: [URLQueryItem],
        body: B,
        as type: T.Type
    ) async throws -> T {
        try await ensureFreshToken()
        var request = try makeRequest(path: "rest/v1/\(table)", query: filters, method: "PATCH")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.httpBody = try encoder.encode(body)
        let data = try await send(request)
        return try decode(T.self, from: data)
    }

    func updateMinimal<B: Encodable & Sendable>(_ table: String, filters: [URLQueryItem], body: B) async throws {
        try await ensureFreshToken()
        var request = try makeRequest(path: "rest/v1/\(table)", query: filters, method: "PATCH")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = try encoder.encode(body)
        _ = try await send(request)
    }

    func delete(_ table: String, filters: [URLQueryItem]) async throws {
        try await ensureFreshToken()
        var request = try makeRequest(path: "rest/v1/\(table)", query: filters, method: "DELETE")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        _ = try await send(request)
    }

    func rpc<T: Decodable & Sendable, B: Encodable & Sendable>(_ name: String, params: B, as type: T.Type) async throws -> T {
        try await ensureFreshToken()
        var request = try makeRequest(path: "rest/v1/rpc/\(name)", method: "POST")
        request.httpBody = try encoder.encode(params)
        let data = try await send(request)
        return try decode(T.self, from: data)
    }

    // MARK: - Серверные функции

    func invoke<T: Decodable & Sendable, B: Encodable & Sendable>(_ function: String, body: B, as type: T.Type) async throws -> T {
        if session != nil {
            try await ensureFreshToken()
        }
        var request = try makeRequest(path: "functions/v1/\(function)", method: "POST")
        request.timeoutInterval = 90
        request.httpBody = try encoder.encode(body)
        let data = try await send(request)
        return try decode(T.self, from: data)
    }

    // MARK: - Хранилище

    func upload(bucket: String, path: String, data: Data, contentType: String) async throws {
        try await ensureFreshToken()
        var request = try makeRequest(path: "storage/v1/object/\(bucket)/\(path)", method: "POST")
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("true", forHTTPHeaderField: "x-upsert")
        request.timeoutInterval = 120
        request.httpBody = data
        _ = try await send(request)
    }

    func download(bucket: String, path: String) async throws -> Data {
        try await ensureFreshToken()
        var request = try makeRequest(path: "storage/v1/object/authenticated/\(bucket)/\(path)")
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 120
        return try await send(request)
    }

    // MARK: - Транспорт

    private func makeRequest(
        path: String,
        query: [URLQueryItem] = [],
        method: String = "GET",
        authorized: Bool = true
    ) throws -> URLRequest {
        guard SupabaseConfig.isConfigured else { throw APIError.notConfigured }
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        if !query.isEmpty {
            components?.queryItems = query
        }
        guard let url = components?.url else { throw APIError.network("Некорректный адрес запроса") }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if authorized, let token = session?.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func send(_ request: URLRequest, retryOnUnauthorized: Bool = true) async throws -> Data {
        let result: (Data, URLResponse)
        do {
            result = try await urlSession.data(for: request)
        } catch {
            throw APIError.network(error.localizedDescription)
        }
        let (data, response) = result
        guard let http = response as? HTTPURLResponse else {
            throw APIError.network("Пустой ответ сервера")
        }
        if http.statusCode == 401, retryOnUnauthorized, session != nil {
            let fresh = try await refreshSession()
            var retry = request
            retry.setValue("Bearer \(fresh.accessToken)", forHTTPHeaderField: "Authorization")
            return try await send(retry, retryOnUnauthorized: false)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.server(status: http.statusCode, message: Self.message(from: data, status: http.statusCode))
        }
        return data
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(String(describing: error).prefix(200).description)
        }
    }

    /// Достаёт понятное сообщение из ответов Auth, PostgREST и наших функций.
    private static func message(from data: Data, status: Int) -> String {
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let code = object["code"] as? String {
                switch code {
                case "23505": return "Такая запись уже есть."
                case "23514": return "Проверьте заполнение полей: часть данных не прошла проверку."
                case "42501": return "Недостаточно прав для этого действия."
                default: break
                }
            }
            for key in ["error", "msg", "message", "error_description"] {
                if let text = object[key] as? String, !text.isEmpty {
                    return text
                }
            }
        }
        switch status {
        case 401: return "Нужно войти в аккаунт."
        case 403: return "Недостаточно прав для этого действия."
        case 404: return "Не найдено."
        case 413: return "Файл слишком большой."
        case 429: return "Слишком много запросов. Попробуйте через минуту."
        case 500...599: return "Сервер временно недоступен (\(status))."
        default: return "Ошибка сервера (\(status))."
        }
    }
}
