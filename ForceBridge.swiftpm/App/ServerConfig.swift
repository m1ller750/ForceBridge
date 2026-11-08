import Foundation

/// Адрес сервера ForceBridge (Cloudflare Worker).
/// Секретов здесь нет: ключ Groq хранится только в секретах Cloudflare,
/// а доступ к данным проверяет сервер по токену входа.
enum ServerConfig {
    static let baseURL = URL(string: "https://forcebridge-api.forcebridge-api.workers.dev")!

    static var isConfigured: Bool {
        !baseURL.absoluteString.contains("YOUR-SUBDOMAIN")
    }
}
