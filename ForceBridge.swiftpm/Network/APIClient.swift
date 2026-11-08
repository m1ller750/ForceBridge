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
            return "Приложение не подключено к серверу: укажите адрес в App/ServerConfig.swift."
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

/// Клиент API ForceBridge поверх URLSession. Без сторонних зависимостей,
/// чтобы проект собирался и в Xcode, и в Swift Playgrounds.
actor APIClient {
    private struct Credentials: Encodable, Sendable {
        let email: String
        let password: String
    }

    private struct AuthResponse: Decodable, Sendable {
        let token: String
        let userId: UUID
        let email: String
    }

    private struct NoBody: Encodable, Sendable {}

    private let baseURL: URL
    private let urlSession: URLSession
    private let decoder = JSONCoding.makeDecoder()
    private let encoder = JSONCoding.makeEncoder()
    private var auth: AuthSession?

    init(baseURL: URL) {
        self.baseURL = baseURL
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60
        self.urlSession = URLSession(configuration: configuration)
        self.auth = SessionStore.load()
    }

    // MARK: - Вход

    func currentSession() -> AuthSession? {
        auth
    }

    func register(email: String, password: String) async throws -> AuthSession {
        try await authenticate(path: "auth/register", email: email, password: password)
    }

    func signIn(email: String, password: String) async throws -> AuthSession {
        try await authenticate(path: "auth/login", email: email, password: password)
    }

    func signOut() async {
        if auth != nil, let request = try? makeRequest("POST", "auth/logout") {
            _ = try? await urlSession.data(for: request)
        }
        auth = nil
        SessionStore.clear()
    }

    private func authenticate(path: String, email: String, password: String) async throws -> AuthSession {
        var request = try makeRequest("POST", path, authorized: false)
        request.httpBody = try encoder.encode(Credentials(email: email, password: password))
        let data = try await perform(request, authorized: false)
        let response = try decode(AuthResponse.self, from: data)
        let session = AuthSession(token: response.token, userId: response.userId, email: response.email)
        auth = session
        SessionStore.save(session)
        return session
    }

    // MARK: - Запросы

    func get<T: Decodable & Sendable>(_ path: String, as type: T.Type) async throws -> T {
        let request = try makeRequest("GET", path)
        return try decode(T.self, from: try await perform(request))
    }

    func send<T: Decodable & Sendable, B: Encodable & Sendable>(
        _ method: String,
        _ path: String,
        body: B,
        as type: T.Type
    ) async throws -> T {
        var request = try makeRequest(method, path)
        request.httpBody = try encoder.encode(body)
        return try decode(T.self, from: try await perform(request))
    }

    func send<B: Encodable & Sendable>(_ method: String, _ path: String, body: B) async throws {
        var request = try makeRequest(method, path)
        request.httpBody = try encoder.encode(body)
        _ = try await perform(request)
    }

    func send(_ method: String, _ path: String) async throws {
        let request = try makeRequest(method, path)
        _ = try await perform(request)
    }

    func post<T: Decodable & Sendable>(_ path: String, as type: T.Type) async throws -> T {
        var request = try makeRequest("POST", path)
        request.httpBody = try encoder.encode(NoBody())
        return try decode(T.self, from: try await perform(request))
    }

    func upload<T: Decodable & Sendable>(
        _ path: String,
        data: Data,
        contentType: String,
        fileName: String,
        as type: T.Type
    ) async throws -> T {
        var request = try makeRequest("PUT", path)
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        let asciiSafe = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        let encodedName = fileName.addingPercentEncoding(withAllowedCharacters: asciiSafe) ?? "resume"
        request.setValue(encodedName, forHTTPHeaderField: "X-File-Name")
        request.timeoutInterval = 120
        request.httpBody = data
        return try decode(T.self, from: try await perform(request))
    }

    func download(_ path: String) async throws -> Data {
        var request = try makeRequest("GET", path)
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 120
        return try await perform(request)
    }

    // MARK: - Транспорт

    private func makeRequest(_ method: String, _ path: String, authorized: Bool = true) throws -> URLRequest {
        guard ServerConfig.isConfigured else { throw APIError.notConfigured }
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if authorized, let token = auth?.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func perform(_ request: URLRequest, authorized: Bool = true) async throws -> Data {
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
        if http.statusCode == 401 && authorized {
            auth = nil
            SessionStore.clear()
            throw APIError.unauthorized
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

    private static func message(from data: Data, status: Int) -> String {
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let text = object["error"] as? String, !text.isEmpty {
            return text
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
