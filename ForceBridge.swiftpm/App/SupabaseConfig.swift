import Foundation

/// Подключение к серверу (Supabase).
/// Публичный ключ (anon / publishable) можно хранить в приложении: доступ к данным
/// ограничен политиками RLS в базе. Ключ Groq здесь НЕ хранится — он лежит
/// в секретах серверных функций Supabase.
enum SupabaseConfig {
    static let url = URL(string: "https://YOUR-PROJECT-REF.supabase.co")!
    static let anonKey = "YOUR-SUPABASE-ANON-KEY"

    static var isConfigured: Bool {
        !anonKey.hasPrefix("YOUR-") && !url.absoluteString.contains("YOUR-PROJECT-REF")
    }
}
