import Foundation

// MARK: - Связь

/// Мессенджер или соцсеть, через которую с человеком можно связаться.
enum Messenger: String, CaseIterable, Codable, Identifiable, Hashable, Sendable {
    case telegram, whatsapp, instagram, tiktok, vk, discord, phone, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .telegram: return "Telegram"
        case .whatsapp: return "WhatsApp"
        case .instagram: return "Instagram"
        case .tiktok: return "TikTok"
        case .vk: return "ВКонтакте"
        case .discord: return "Discord"
        case .phone: return "Телефон"
        case .other: return "Другое"
        }
    }

    var code: String {
        switch self {
        case .telegram: return "TG"
        case .whatsapp: return "WA"
        case .instagram: return "IG"
        case .tiktok: return "TT"
        case .vk: return "VK"
        case .discord: return "DS"
        case .phone: return "TEL"
        case .other: return "ETC"
        }
    }

    var placeholder: String {
        switch self {
        case .telegram: return "@username или номер"
        case .whatsapp, .phone: return "+7 700 000 00 00"
        case .instagram, .tiktok: return "@username"
        case .vk: return "Короткое имя страницы"
        case .discord: return "username"
        case .other: return "Как с вами связаться"
        }
    }

    /// Ссылка, по которой можно сразу написать. Для «Другое» и Discord — нет.
    func url(for contact: String) -> URL? {
        let trimmed = contact.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let handle = trimmed.hasPrefix("@") ? String(trimmed.dropFirst()) : trimmed
        let encoded = handle.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? handle
        let digits = trimmed.filter { $0.isNumber }
        let looksLikePhone = trimmed.hasPrefix("+") || (digits.count >= 10 && !trimmed.contains { $0.isLetter })
        switch self {
        case .telegram:
            return looksLikePhone ? URL(string: "https://t.me/+\(digits)") : URL(string: "https://t.me/\(encoded)")
        case .whatsapp:
            return digits.isEmpty ? nil : URL(string: "https://wa.me/\(digits)")
        case .instagram:
            return URL(string: "https://instagram.com/\(encoded)")
        case .tiktok:
            return URL(string: "https://www.tiktok.com/@\(encoded)")
        case .vk:
            return URL(string: "https://vk.com/\(encoded)")
        case .phone:
            return digits.isEmpty ? nil : URL(string: "tel:+\(digits)")
        case .discord, .other:
            return nil
        }
    }
}

// MARK: - Профиль

struct Profile: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var fullName: String
    var age: Int?
    var city: String
    var occupation: String
    var about: String
    var skills: [String]
    var projects: [String]
    var achievements: [String]
    var messenger: Messenger
    var contact: String
    var resumePath: String?
    var resumeName: String?
    var createdAt: Date?
    var updatedAt: Date?

    static func empty(id: UUID) -> Profile {
        Profile(
            id: id, fullName: "", age: nil, city: "", occupation: "", about: "",
            skills: [], projects: [], achievements: [], messenger: .telegram, contact: "",
            resumePath: nil, resumeName: nil, createdAt: nil, updatedAt: nil
        )
    }

    var initials: String {
        let letters = fullName.split(separator: " ").prefix(2).compactMap { $0.first }.map { String($0) }
        let result = letters.joined().uppercased()
        return result.isEmpty ? "?" : result
    }

    var firstName: String {
        fullName.split(separator: " ").first.map(String.init) ?? fullName
    }

    /// «19 лет · Алматы»
    var ageAndCity: String {
        var parts: [String] = []
        if let age { parts.append("\(age) \(Fmt.plural(age, "год", "года", "лет"))") }
        if !city.isEmpty { parts.append(city) }
        return parts.joined(separator: " · ")
    }

    var hasResume: Bool { resumePath != nil }
}

// MARK: - Карточки-объявления

enum CardKind: String, CaseIterable, Codable, Identifiable, Hashable, Sendable {
    case teammate, research, join

    var id: String { rawValue }

    var title: String {
        switch self {
        case .teammate: return "Ищу сокомандника"
        case .research: return "Нужен человек для исследования"
        case .join: return "Ищу команду"
        }
    }

    var shortTitle: String {
        switch self {
        case .teammate: return "Сокомандник"
        case .research: return "Исследование"
        case .join: return "Ищу команду"
        }
    }

    var code: String {
        switch self {
        case .teammate: return "TEAM"
        case .research: return "RES"
        case .join: return "JOIN"
        }
    }
}

enum CardFormat: String, CaseIterable, Codable, Identifiable, Hashable, Sendable {
    case online, offline, any

    var id: String { rawValue }

    var title: String {
        switch self {
        case .online: return "Онлайн"
        case .offline: return "Очно"
        case .any: return "Любой формат"
        }
    }
}

struct Card: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var authorId: UUID
    var kind: CardKind
    var title: String
    var description: String
    var eventName: String
    var roles: [String]
    var city: String
    var format: CardFormat
    var deadline: Date?
    var categories: [String]
    var aiStatus: String
    var createdAt: Date
    var updatedAt: Date
    // Поля представления card_feed
    var authorName: String?
    var authorCity: String?
    var authorOccupation: String?
    var responsesCount: Int?

    var isClassifying: Bool { aiStatus == "pending" }
    var classificationFailed: Bool { aiStatus == "error" }

    var placeText: String {
        if format == .online { return "Онлайн" }
        if city.isEmpty { return format.title }
        return format == .offline ? "Очно, \(city)" : city
    }
}

/// Данные карточки для создания и изменения.
struct CardDraft: Encodable, Sendable {
    var authorId: UUID
    var kind: CardKind
    var title: String
    var description: String
    var eventName: String
    var roles: [String]
    var city: String
    var format: CardFormat
    var deadline: Date?

    enum CodingKeys: String, CodingKey {
        case authorId, kind, title, description, eventName, roles, city, format, deadline
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(authorId, forKey: .authorId)
        try container.encode(kind, forKey: .kind)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encode(eventName, forKey: .eventName)
        try container.encode(roles, forKey: .roles)
        try container.encode(city, forKey: .city)
        try container.encode(format, forKey: .format)
        if let deadline {
            try container.encode(JSONCoding.dayString(deadline), forKey: .deadline)
        } else {
            try container.encodeNil(forKey: .deadline)
        }
    }
}

// MARK: - Отклики и избранное

struct ResponseRow: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var cardId: UUID
    var userId: UUID
    var message: String
    var hidden: Bool
    var createdAt: Date
    var profile: Profile?
    var card: Card?
}

struct FavoriteRow: Decodable, Sendable {
    var profileId: UUID
    var createdAt: Date
    var profile: Profile?
}

struct NewResponse: Encodable, Sendable {
    var cardId: UUID
    var userId: UUID
    var message: String
}

struct NewFavorite: Encodable, Sendable {
    var ownerId: UUID
    var profileId: UUID
}

struct HiddenPatch: Encodable, Sendable {
    var hidden: Bool
}

// MARK: - ИИ

struct Compatibility: Codable, Hashable, Sendable {
    var score: Int
    var summary: String
    var strengths: [String]
    var gaps: [String]
}

struct CompatibilityRequest: Encodable, Sendable {
    var cardIds: [String]
    var force: Bool
}

struct CompatibilityResponse: Decodable, Sendable {
    var results: [String: Compatibility]
    var error: String?
}

// MARK: - Категории

struct CategoryInfo: Codable, Identifiable, Hashable, Sendable {
    var key: String
    var title: String
    var grp: String
    var sort: Int

    var id: String { key }
    var isFormat: Bool { grp == "format" }

    var code: String {
        switch key {
        case "hackathon": return "HCK"
        case "olympiad": return "OLY"
        case "contest": return "CNT"
        case "research": return "RES"
        case "startup": return "STP"
        case "it": return "IT"
        case "ai": return "AI"
        case "design": return "DSN"
        case "engineering": return "ENG"
        case "biomed": return "BIO"
        case "physchem": return "PHY"
        case "math": return "MTH"
        case "ecology": return "ECO"
        case "business": return "BIZ"
        case "social": return "SOC"
        case "media": return "MED"
        case "education": return "EDU"
        default: return String(key.prefix(3)).uppercased()
        }
    }

    static let defaults: [CategoryInfo] = [
        CategoryInfo(key: "hackathon", title: "Хакатоны", grp: "format", sort: 1),
        CategoryInfo(key: "olympiad", title: "Олимпиады", grp: "format", sort: 2),
        CategoryInfo(key: "contest", title: "Конкурсы и чемпионаты", grp: "format", sort: 3),
        CategoryInfo(key: "research", title: "Научные исследования", grp: "format", sort: 4),
        CategoryInfo(key: "startup", title: "Стартапы и проекты", grp: "format", sort: 5),
        CategoryInfo(key: "it", title: "IT и разработка", grp: "field", sort: 10),
        CategoryInfo(key: "ai", title: "ИИ и данные", grp: "field", sort: 11),
        CategoryInfo(key: "design", title: "Дизайн", grp: "field", sort: 12),
        CategoryInfo(key: "engineering", title: "Инженерия и робототехника", grp: "field", sort: 13),
        CategoryInfo(key: "biomed", title: "Биология и медицина", grp: "field", sort: 14),
        CategoryInfo(key: "physchem", title: "Физика и химия", grp: "field", sort: 15),
        CategoryInfo(key: "math", title: "Математика", grp: "field", sort: 16),
        CategoryInfo(key: "ecology", title: "Экология", grp: "field", sort: 17),
        CategoryInfo(key: "business", title: "Бизнес и маркетинг", grp: "field", sort: 18),
        CategoryInfo(key: "social", title: "Социальные проекты", grp: "field", sort: 19),
        CategoryInfo(key: "media", title: "Медиа и искусство", grp: "field", sort: 20),
        CategoryInfo(key: "education", title: "Образование", grp: "field", sort: 21)
    ]
}

struct CategoryCount: Decodable, Sendable {
    var key: String
    var total: Int
}

// MARK: - Параметры запросов

struct SearchParams: Encodable, Sendable {
    var pFormats: [String]
    var pFields: [String]
    var pQuery: String
    var pKind: String
    var pSort: String
}

struct EmptyParams: Encodable, Sendable {}

struct PendingRequest: Encodable, Sendable {
    var pending: Bool
}

struct RegisterRequest: Encodable, Sendable {
    var email: String
    var password: String
}

/// Ответ, содержимое которого не нужно.
struct IgnoredResponse: Decodable, Sendable {}

// MARK: - Сортировка ленты

enum FeedSort: String, CaseIterable, Identifiable, Sendable {
    case newest, oldest, deadline, match

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newest: return "Сначала новые"
        case .oldest: return "Сначала старые"
        case .deadline: return "Ближайший дедлайн"
        case .match: return "По совместимости (ИИ)"
        }
    }

    var rpcValue: String {
        switch self {
        case .newest, .match: return "new"
        case .oldest: return "old"
        case .deadline: return "deadline"
        }
    }
}

// MARK: - Города

enum Cities {
    static let popular: [String] = [
        "Алматы", "Астана", "Шымкент", "Москва", "Санкт-Петербург",
        "Казань", "Новосибирск", "Екатеринбург", "Томск", "Бишкек", "Ташкент"
    ]

    static func same(_ a: String, _ b: String) -> Bool {
        let left = a.trimmingCharacters(in: .whitespaces).lowercased()
        let right = b.trimmingCharacters(in: .whitespaces).lowercased()
        return !left.isEmpty && left == right
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0, !isEmpty else { return isEmpty ? [] : [self] }
        return stride(from: 0, to: count, by: size).map { start in
            Array(self[start..<Swift.min(start + size, count)])
        }
    }
}

extension UUID {
    /// Нижний регистр — так UUID хранит Postgres и так пишутся пути в хранилище.
    var lower: String { uuidString.lowercased() }
}
