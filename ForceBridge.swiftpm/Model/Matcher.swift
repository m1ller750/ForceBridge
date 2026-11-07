import Foundation

// Подбор строится на принципе «похожие цели — разные навыки».
// Никакой «магии»: каждая оценка раскладывается на четыре понятные составляющие.

struct MatchFactor: Hashable, Identifiable {
    let id: String
    let label: String
    let value: Double
    let points: Int

    var score: Double { value * Double(points) }
}

struct MatchReport: Hashable {
    let factors: [MatchFactor]
    let reasons: [String]

    var total: Int {
        let sum = factors.reduce(0.0) { $0 + $1.score }
        return Int(sum.rounded())
    }

    var fraction: Double { Double(total) / 100 }

    static let empty = MatchReport(factors: [], reasons: [])
}

enum Matcher {
    static let rolePoints = 40
    static let goalPoints = 30
    static let timePoints = 15
    static let placePoints = 15

    // MARK: Человек ↔ пользователь

    /// Насколько `other` дополняет пользователя `me`.
    static func person(_ other: Person, for me: Person) -> MatchReport {
        let myRoles = Set(me.roles)
        let newRoles = other.roles.filter { !myRoles.contains($0) }
        let roleValue: Double = other.roles.isEmpty ? 0 : Double(newRoles.count) / Double(other.roles.count)

        let shared = sharedTopics(me.interests, other.interests)
        let goalValue = min(1.0, Double(shared.count) / 2.0)

        let timeValue = timeFit(me.hoursPerWeek, other.hoursPerWeek)
        let placeValue = placeFit(cityA: me.city, formatA: me.format, cityB: other.city, formatB: other.format)

        var reasons: [String] = []
        if newRoles.isEmpty {
            reasons.append("Роли совпадают с вашими — скорее дублирует, чем дополняет")
        } else {
            reasons.append("Добавляет роли: " + newRoles.map { $0.shortTitle }.joined(separator: ", "))
        }
        if shared.isEmpty {
            reasons.append("Общих тем пока нет")
        } else {
            reasons.append("Общие темы: " + shared.joined(separator: ", ").lowercased())
        }
        reasons.append("Время: \(other.hoursPerWeek) ч/нед, у вас \(me.hoursPerWeek)")
        reasons.append(placeReason(cityA: me.city, cityB: other.city, value: placeValue))

        return MatchReport(factors: factors(roleValue, goalValue, timeValue, placeValue), reasons: reasons)
    }

    // MARK: Кандидат ↔ команда

    /// Насколько человек закрывает потребности команды.
    static func candidate(_ person: Person, for team: Team, challenge: Challenge?) -> MatchReport {
        let open = team.openRoles
        let covered = person.roles.filter { open.contains($0) }
        let roleValue: Double
        if covered.isEmpty {
            roleValue = 0
        } else {
            roleValue = min(1.0, 0.75 + 0.25 * Double(covered.count) / Double(max(open.count, 1)))
        }

        let topics = teamTopics(team, challenge: challenge)
        let shared = sharedTopics(topics, person.interests)
        let goalValue: Double = topics.isEmpty ? 0.5 : min(1.0, Double(shared.count) / Double(min(2, topics.count)))

        let timeValue: Double = person.hoursPerWeek >= team.hoursPerWeek
            ? 1
            : Double(person.hoursPerWeek) / Double(max(team.hoursPerWeek, 1))

        let placeValue = teamPlaceFit(team, person)

        var reasons: [String] = []
        if covered.isEmpty {
            reasons.append("Не закрывает открытые вакансии")
        } else {
            reasons.append("Закрывает вакансию: " + covered.map { $0.shortTitle }.joined(separator: ", "))
        }
        if shared.isEmpty {
            reasons.append(topics.isEmpty ? "Тематика события открытая" : "Темы не пересекаются")
        } else {
            reasons.append("Общие темы: " + shared.joined(separator: ", ").lowercased())
        }
        reasons.append("Время: \(person.hoursPerWeek) ч/нед при запросе \(team.hoursPerWeek)")
        reasons.append(teamPlaceReason(team, person, value: placeValue))

        return MatchReport(factors: factors(roleValue, goalValue, timeValue, placeValue), reasons: reasons)
    }

    // MARK: Вспомогательное

    static func teamTopics(_ team: Team, challenge: Challenge?) -> [String] {
        if let challenge, !challenge.topics.isEmpty { return challenge.topics }
        return team.field.isEmpty ? [] : [team.field]
    }

    static func sharedTopics(_ a: [String], _ b: [String]) -> [String] {
        let lowered = Set(b.map { $0.lowercased() })
        return a.filter { lowered.contains($0.lowercased()) }
    }

    static func timeFit(_ a: Int, _ b: Int) -> Double {
        let high = Double(max(a, b, 1))
        return max(0, 1 - Double(abs(a - b)) / high)
    }

    static func sameCity(_ a: String, _ b: String) -> Bool {
        let left = a.trimmingCharacters(in: .whitespaces).lowercased()
        let right = b.trimmingCharacters(in: .whitespaces).lowercased()
        return !left.isEmpty && left == right
    }

    static func placeFit(cityA: String, formatA: WorkFormat, cityB: String, formatB: WorkFormat) -> Double {
        if sameCity(cityA, cityB) { return 1 }
        if formatA == .online || formatB == .online { return 0.7 }
        if formatA == .hybrid || formatB == .hybrid { return 0.5 }
        return 0.15
    }

    static func teamPlaceFit(_ team: Team, _ person: Person) -> Double {
        if team.format == .online {
            return person.format == .offline ? 0.7 : 1
        }
        if let city = team.city, sameCity(city, person.city) { return 1 }
        if team.format == .hybrid {
            return person.format == .offline ? 0.4 : 0.7
        }
        return 0.15
    }

    private static func placeReason(cityA: String, cityB: String, value: Double) -> String {
        if sameCity(cityA, cityB) { return "Один город: \(cityB)" }
        if value >= 0.7 { return "Разные города, но готовы к онлайну" }
        if value >= 0.5 { return "Разные города, возможен гибрид" }
        return "Разные города и оба предпочитают очный формат"
    }

    private static func teamPlaceReason(_ team: Team, _ person: Person, value: Double) -> String {
        if team.format == .online { return "Команда работает онлайн" }
        if let city = team.city, sameCity(city, person.city) { return "Один город: \(city)" }
        if value >= 0.7 { return "Гибридный формат, можно подключаться удалённо" }
        if let city = team.city, !city.isEmpty { return "Команда собирается очно: \(city)" }
        return "Очный формат"
    }

    private static func factors(_ role: Double, _ goal: Double, _ time: Double, _ place: Double) -> [MatchFactor] {
        [
            MatchFactor(id: "roles", label: "Роли", value: role, points: rolePoints),
            MatchFactor(id: "goals", label: "Цели", value: goal, points: goalPoints),
            MatchFactor(id: "time", label: "Время", value: time, points: timePoints),
            MatchFactor(id: "place", label: "География", value: place, points: placePoints)
        ]
    }
}
