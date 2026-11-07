import Foundation

// MARK: - Роли

/// Роль человека в команде. Код — короткое обозначение для схем и меток.
enum Role: String, CaseIterable, Codable, Identifiable, Hashable {
    case mobile, web, backend, ml, design, hardware, science, math, product

    var id: String { rawValue }

    var code: String {
        switch self {
        case .mobile: return "MOB"
        case .web: return "WEB"
        case .backend: return "BCK"
        case .ml: return "ML"
        case .design: return "DSN"
        case .hardware: return "HW"
        case .science: return "SCI"
        case .math: return "MTH"
        case .product: return "PRD"
        }
    }

    var title: String {
        switch self {
        case .mobile: return "Мобильная разработка"
        case .web: return "Веб-разработка"
        case .backend: return "Бэкенд и инфраструктура"
        case .ml: return "ML и анализ данных"
        case .design: return "Дизайн и UX"
        case .hardware: return "Электроника и железо"
        case .science: return "Естественные науки"
        case .math: return "Математика и алгоритмы"
        case .product: return "Продукт и презентация"
        }
    }

    var shortTitle: String {
        switch self {
        case .mobile: return "Мобайл"
        case .web: return "Веб"
        case .backend: return "Бэкенд"
        case .ml: return "ML"
        case .design: return "Дизайн"
        case .hardware: return "Железо"
        case .science: return "Наука"
        case .math: return "Алгоритмы"
        case .product: return "Продукт"
        }
    }

    /// Подсказки навыков при заполнении профиля.
    var suggestedSkills: [String] {
        switch self {
        case .mobile: return ["Swift", "SwiftUI", "UIKit", "Kotlin", "Flutter"]
        case .web: return ["TypeScript", "React", "Vue", "D3", "WebGL"]
        case .backend: return ["Go", "Python", "PostgreSQL", "Docker", "FastAPI"]
        case .ml: return ["Python", "PyTorch", "Компьютерное зрение", "NLP", "Статистика"]
        case .design: return ["Figma", "UX-исследования", "Прототипирование", "Моушн", "3D"]
        case .hardware: return ["Arduino", "STM32", "KiCad", "FPGA", "3D-печать"]
        case .science: return ["Лабораторный эксперимент", "Биоинформатика", "Химический анализ", "Полевые исследования"]
        case .math: return ["C++", "Теория графов", "Оптимизация", "Динамическое программирование"]
        case .product: return ["Питч", "Грантовые заявки", "Исследование рынка", "Управление проектом"]
        }
    }
}

// MARK: - Темы

enum Topics {
    static let all: [String] = [
        "Медицина", "Образование", "Климат", "Космос", "Финтех", "Городская среда",
        "Игры", "Биотех", "Робототехника", "Энергетика", "Агротех", "Социальные проекты"
    ]

    static let cities: [String] = [
        "Москва", "Санкт-Петербург", "Казань", "Новосибирск", "Екатеринбург",
        "Томск", "Нижний Новгород", "Алматы", "Астана"
    ]
}

// MARK: - Форматы и типы событий

enum WorkFormat: String, CaseIterable, Codable, Identifiable, Hashable {
    case online, offline, hybrid

    var id: String { rawValue }

    var title: String {
        switch self {
        case .online: return "Онлайн"
        case .offline: return "Очно"
        case .hybrid: return "Гибрид"
        }
    }
}

enum ChallengeKind: String, CaseIterable, Codable, Identifiable, Hashable {
    case hackathon, olympiad, contest, grant

    var id: String { rawValue }

    var code: String {
        switch self {
        case .hackathon: return "HCK"
        case .olympiad: return "OLY"
        case .contest: return "CNT"
        case .grant: return "GRT"
        }
    }

    var title: String {
        switch self {
        case .hackathon: return "Хакатон"
        case .olympiad: return "Олимпиада"
        case .contest: return "Конкурс"
        case .grant: return "Грант"
        }
    }

    var plural: String {
        switch self {
        case .hackathon: return "Хакатоны"
        case .olympiad: return "Олимпиады"
        case .contest: return "Конкурсы"
        case .grant: return "Гранты"
        }
    }
}

// MARK: - Сущности

/// Вызов — событие, ради которого собираются команды.
struct Challenge: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var kind: ChallengeKind
    var organizer: String
    var summary: String
    var format: WorkFormat
    var city: String?
    var startDate: Date
    var registrationDeadline: Date
    var minTeam: Int
    var maxTeam: Int
    var topics: [String]
    var prize: String?
    var isUserCreated: Bool = false

    var placeText: String {
        if format == .online { return "Онлайн" }
        if let city, !city.isEmpty { return "\(format.title), \(city)" }
        return format.title
    }

    var teamSizeText: String {
        if minTeam == maxTeam { return "\(maxTeam) чел." }
        return "\(minTeam)–\(maxTeam) чел."
    }
}

struct Person: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var city: String
    var affiliation: String
    var headline: String
    var roles: [Role]
    var skills: [String]
    var interests: [String]
    var hoursPerWeek: Int
    var format: WorkFormat
    var track: [String]
    var isLookingForTeam: Bool

    var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first }.map { String($0) }
        let result = letters.joined().uppercased()
        return result.isEmpty ? "?" : result
    }

    var firstName: String {
        name.split(separator: " ").first.map(String.init) ?? name
    }

    var primaryRole: Role? { roles.first }
}

/// Позиция в команде: роль и, если занята, участник.
struct Slot: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var role: Role
    var memberID: UUID?
    var note: String = ""

    var isOpen: Bool { memberID == nil }
}

struct Team: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    /// nil — самостоятельный научный проект без привязки к событию.
    var challengeID: UUID?
    var field: String
    var pitch: String
    var slots: [Slot]
    var hoursPerWeek: Int
    var format: WorkFormat
    var city: String?
    var ownerID: UUID
    var createdAt: Date

    var openSlots: [Slot] { slots.filter { $0.isOpen } }
    var memberIDs: [UUID] { slots.compactMap { $0.memberID } }
    var openRoles: [Role] {
        var seen: [Role] = []
        for slot in openSlots where !seen.contains(slot.role) {
            seen.append(slot.role)
        }
        return seen
    }
    var integrity: Double {
        guard !slots.isEmpty else { return 0 }
        return Double(slots.count - openSlots.count) / Double(slots.count)
    }
    var isResearch: Bool { challengeID == nil }
    var states: [Bool] { slots.map { !$0.isOpen } }
}

// MARK: - Запросы

enum RequestKind: String, Codable, Hashable {
    /// Человек просится в команду.
    case application
    /// Команда зовёт человека.
    case invitation
}

enum RequestStatus: String, Codable, Hashable {
    case pending, accepted, declined

    var title: String {
        switch self {
        case .pending: return "Ожидает ответа"
        case .accepted: return "Принят"
        case .declined: return "Отклонён"
        }
    }
}

struct JoinRequest: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var kind: RequestKind
    var teamID: UUID
    var slotID: UUID
    /// Тот, кто вступает в команду (кандидат).
    var personID: UUID
    var message: String
    var status: RequestStatus
    var createdAt: Date
    /// true — решение принимает текущий пользователь.
    var isIncoming: Bool
}

// MARK: - Снимок состояния для сохранения

struct Snapshot: Codable {
    var version: Int
    var me: Person?
    var people: [Person]
    var challenges: [Challenge]
    var teams: [Team]
    var requests: [JoinRequest]
    var savedChallengeIDs: Set<UUID>
}
