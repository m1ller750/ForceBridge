import Foundation
import UIKit
import Vision

/// Строка текста, найденная Vision на изображении.
struct RecognizedLine: Identifiable {
    let id = UUID()
    let text: String
    /// Нормализованный прямоугольник Vision: 0…1, начало координат — внизу слева.
    let box: CGRect
    let confidence: Float
}

// MARK: - Распознавание (Vision)

enum PosterRecognizer {
    /// Приводит фото к ориентации «вверх» и разумному размеру.
    static func normalized(_ image: UIImage, maxDimension: CGFloat = 2048) -> UIImage {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return image }
        let scale = min(1, maxDimension / max(size.width * image.scale, size.height * image.scale))
        let target = CGSize(
            width: (size.width * image.scale * scale).rounded(),
            height: (size.height * image.scale * scale).rounded()
        )
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }

    /// Распознаёт текст на русском и английском в фоновом потоке.
    static func recognize(_ cgImage: CGImage) async throws -> [RecognizedLine] {
        try await Task.detached(priority: .userInitiated) {
            try PosterRecognizer.performRecognition(cgImage)
        }.value
    }

    private static func performRecognition(_ cgImage: CGImage) throws -> [RecognizedLine] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        let wanted = ["ru-RU", "en-US"]
        if let supported = try? request.supportedRecognitionLanguages() {
            let languages = wanted.filter { supported.contains($0) }
            if !languages.isEmpty {
                request.recognitionLanguages = languages
            }
        }
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
        try handler.perform([request])
        let observations = request.results ?? []
        return observations.compactMap { observation -> RecognizedLine? in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            return RecognizedLine(text: text, box: observation.boundingBox, confidence: candidate.confidence)
        }
    }
}

// MARK: - Черновик события

struct ChallengeDraft {
    var title = ""
    var kind: ChallengeKind = .hackathon
    var organizer = ""
    var summary = ""
    var format: WorkFormat = .offline
    var city = ""
    var startDate = Date()
    var deadline = Date()
    var minTeam = 2
    var maxTeam = 5
    var topics: [String] = []
    var prize = ""
    var datesFound = 0

    func makeChallenge() -> Challenge {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanCity = city.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPrize = prize.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanOrganizer = organizer.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        return Challenge(
            title: cleanTitle.isEmpty ? "Новый вызов" : cleanTitle,
            kind: kind,
            organizer: cleanOrganizer.isEmpty ? "Организатор не указан" : cleanOrganizer,
            summary: cleanSummary.isEmpty ? "Добавлено по фото афиши." : cleanSummary,
            format: format,
            city: format == .online || cleanCity.isEmpty ? nil : cleanCity,
            startDate: startDate,
            registrationDeadline: min(deadline, startDate),
            minTeam: max(1, min(minTeam, maxTeam)),
            maxTeam: max(minTeam, maxTeam),
            topics: topics,
            prize: cleanPrize.isEmpty ? nil : cleanPrize,
            isUserCreated: true
        )
    }
}

// MARK: - Разбор текста афиши

enum PosterParser {
    private static let monthNames = [
        "января", "февраля", "марта", "апреля", "мая", "июня",
        "июля", "августа", "сентября", "октября", "ноября", "декабря"
    ]

    private static let monthPattern = try? NSRegularExpression(
        pattern: "(\\d{1,2})\\s*(?:[-–—]\\s*\\d{1,2}\\s*)?(января|февраля|марта|апреля|мая|июня|июля|августа|сентября|октября|ноября|декабря)(?:\\s+(\\d{4}))?",
        options: [.caseInsensitive]
    )

    private static let numericPattern = try? NSRegularExpression(
        pattern: "(?<!\\d)(\\d{1,2})\\.(\\d{1,2})(?:\\.(\\d{2,4}))?(?!\\d)",
        options: []
    )

    private static let teamRangePattern = try? NSRegularExpression(
        pattern: "(\\d{1,2})\\s*[-–—]\\s*(\\d{1,2})\\s*(?:человек|чел|участник)",
        options: [.caseInsensitive]
    )

    private static let teamMaxPattern = try? NSRegularExpression(
        pattern: "(?:до|не более)\\s*(\\d{1,2})\\s*(?:человек|чел|участник)",
        options: [.caseInsensitive]
    )

    private static let cityStems: [(stem: String, name: String)] = [
        ("москв", "Москва"), ("петербург", "Санкт-Петербург"), ("спб", "Санкт-Петербург"),
        ("казан", "Казань"), ("новосибирск", "Новосибирск"), ("екатеринбург", "Екатеринбург"),
        ("томск", "Томск"), ("нижн", "Нижний Новгород"), ("алмат", "Алматы"), ("астан", "Астана"),
        ("иннополис", "Иннополис"), ("самар", "Самара"), ("красноярск", "Красноярск"),
        ("владивосток", "Владивосток")
    ]

    private static let topicStems: [(stem: String, topic: String)] = [
        ("медиц", "Медицина"), ("здоров", "Медицина"), ("образов", "Образование"), ("школ", "Образование"),
        ("климат", "Климат"), ("эколог", "Климат"), ("космо", "Космос"), ("спутник", "Космос"),
        ("финанс", "Финтех"), ("финтех", "Финтех"), ("банк", "Финтех"), ("город", "Городская среда"),
        ("транспорт", "Городская среда"), ("игр", "Игры"), ("био", "Биотех"), ("генет", "Биотех"),
        ("робот", "Робототехника"), ("энерг", "Энергетика"), ("солнеч", "Энергетика"),
        ("агро", "Агротех"), ("сельск", "Агротех"), ("социал", "Социальные проекты"), ("инклюз", "Социальные проекты")
    ]

    static func parse(_ lines: [RecognizedLine], now: Date = Date()) -> ChallengeDraft {
        var draft = ChallengeDraft()
        guard !lines.isEmpty else { return draft }

        // Порядок чтения: сверху вниз, слева направо (у Vision ось Y направлена вверх).
        let ordered = lines.sorted { a, b in
            if abs(a.box.midY - b.box.midY) > 0.015 {
                return a.box.midY > b.box.midY
            }
            return a.box.minX < b.box.minX
        }
        let texts = ordered.map { $0.text }
        let lowerText = texts.joined(separator: "\n").lowercased()

        // Тип события.
        draft.kind = detectKind(lowerText)

        // Название — строки с самым крупным кеглем.
        let tallest = ordered.map { $0.box.height }.max() ?? 0
        let titleLines = ordered.filter { $0.box.height >= tallest * 0.72 && letterCount($0.text) >= 2 }
        var usedTexts = Set(titleLines.prefix(3).map { $0.text })
        let rawTitle = titleLines.prefix(3).map { $0.text }.joined(separator: " ")
        draft.title = makeTitle(rawTitle, kind: draft.kind)

        // Даты: строки со словами «регистрация», «заявки», «дедлайн» — это дедлайн.
        var starts: [Date] = []
        var deadlines: [Date] = []
        let deadlineMarkers = ["регистрац", "заявк", "дедлайн", "приём", "прием", "deadline"]
        for text in texts {
            let lower = text.lowercased()
            let dates = extractDates(from: lower, now: now)
            guard let first = dates.first else { continue }
            usedTexts.insert(text)
            if deadlineMarkers.contains(where: { lower.contains($0) }) {
                deadlines.append(first)
            } else {
                starts.append(first)
            }
        }
        draft.datesFound = starts.count + deadlines.count
        let calendar = Calendar.current
        let start: Date
        if let first = starts.first {
            start = first
        } else if let firstDeadline = deadlines.first {
            start = calendar.date(byAdding: .day, value: 7, to: firstDeadline) ?? firstDeadline
        } else {
            start = Fmt.date(byAddingDays: 30, to: now)
        }
        draft.startDate = start
        if let firstDeadline = deadlines.first {
            draft.deadline = min(firstDeadline, start)
        } else {
            let weekBefore = calendar.date(byAdding: .day, value: -7, to: start) ?? start
            draft.deadline = max(weekBefore, min(now, start))
        }

        // Город и формат.
        if let city = cityStems.first(where: { lowerText.contains($0.stem) }) {
            draft.city = city.name
        }
        let isHybrid = lowerText.contains("гибрид") || lowerText.contains("hybrid")
        let isOnline = lowerText.contains("онлайн") || lowerText.contains("online")
            || lowerText.contains("дистанц") || lowerText.contains("удалённ") || lowerText.contains("удаленн")
        if isHybrid || (isOnline && !draft.city.isEmpty) {
            draft.format = .hybrid
        } else if isOnline {
            draft.format = .online
        } else {
            draft.format = .offline
        }

        // Размер команды.
        if let range = firstMatch(teamRangePattern, in: lowerText),
           let low = Int(range[0]), let high = Int(range[1]),
           low >= 1, high >= low, high <= 12 {
            draft.minTeam = low
            draft.maxTeam = high
        } else if let limit = firstMatch(teamMaxPattern, in: lowerText),
                  let high = Int(limit[0]), high >= 1, high <= 12 {
            draft.minTeam = min(2, high)
            draft.maxTeam = high
        }

        // Приз и организатор.
        let prizeMarkers = ["приз", "₽", "₸", "руб", "грант до", "$"]
        if let prizeLine = texts.first(where: { line in
            let lower = line.lowercased()
            return prizeMarkers.contains { lower.contains($0) }
        }) {
            draft.prize = prizeLine
            usedTexts.insert(prizeLine)
        }
        if let organizerLine = texts.first(where: { $0.lowercased().contains("организатор") }) {
            usedTexts.insert(organizerLine)
            if let colon = organizerLine.firstIndex(of: ":") {
                draft.organizer = String(organizerLine[organizerLine.index(after: colon)...])
                    .trimmingCharacters(in: .whitespaces)
            } else {
                draft.organizer = organizerLine
            }
        }

        // Темы.
        var topics: [String] = []
        for entry in topicStems where lowerText.contains(entry.stem) && !topics.contains(entry.topic) {
            topics.append(entry.topic)
        }
        draft.topics = topics

        // Описание — всё, что не ушло в другие поля.
        let rest = texts.filter { !usedTexts.contains($0) && letterCount($0) >= 4 }
        draft.summary = String(rest.joined(separator: ". ").prefix(240))

        return draft
    }

    // MARK: Вспомогательное

    static func detectKind(_ text: String) -> ChallengeKind {
        if text.contains("хакатон") || text.contains("hackathon") { return .hackathon }
        if text.contains("олимпиад") || text.contains("olymp") { return .olympiad }
        if text.contains("грант") || text.contains("grant") { return .grant }
        if text.contains("конкурс") || text.contains("чемпионат") || text.contains("contest") { return .contest }
        return .hackathon
    }

    private static func makeTitle(_ raw: String, kind: ChallengeKind) -> String {
        let quotes = CharacterSet(charactersIn: "«»\"“”„'")
        var title = raw.trimmingCharacters(in: quotes.union(.whitespacesAndNewlines).union(.punctuationCharacters))
        guard !title.isEmpty else { return "" }
        title = sentenceCase(title)
        if title.lowercased().contains(kind.title.lowercased()) {
            return title
        }
        return "\(kind.title) «\(title)»"
    }

    private static func sentenceCase(_ text: String) -> String {
        let letters = text.filter { $0.isLetter }
        guard !letters.isEmpty, letters == letters.uppercased() else { return text }
        let lower = text.lowercased()
        return lower.prefix(1).uppercased() + lower.dropFirst()
    }

    private static func letterCount(_ text: String) -> Int {
        text.filter { $0.isLetter }.count
    }

    private static func extractDates(from line: String, now: Date) -> [Date] {
        let ns = line as NSString
        let range = NSRange(location: 0, length: ns.length)
        var found: [(location: Int, date: Date)] = []

        if let monthPattern {
            for match in monthPattern.matches(in: line, options: [], range: range) {
                let day = Int(ns.substring(with: match.range(at: 1))) ?? 0
                let name = ns.substring(with: match.range(at: 2)).lowercased()
                let month = (monthNames.firstIndex(of: name) ?? -1) + 1
                var year: Int?
                if match.range(at: 3).location != NSNotFound {
                    year = Int(ns.substring(with: match.range(at: 3)))
                }
                if let date = makeDate(day: day, month: month, year: year, now: now) {
                    found.append((location: match.range.location, date: date))
                }
            }
        }

        if let numericPattern {
            for match in numericPattern.matches(in: line, options: [], range: range) {
                let day = Int(ns.substring(with: match.range(at: 1))) ?? 0
                let month = Int(ns.substring(with: match.range(at: 2))) ?? 0
                var year: Int?
                if match.range(at: 3).location != NSNotFound {
                    year = Int(ns.substring(with: match.range(at: 3)))
                }
                if let date = makeDate(day: day, month: month, year: year, now: now) {
                    found.append((location: match.range.location, date: date))
                }
            }
        }

        return found.sorted { $0.location < $1.location }.map { $0.date }
    }

    private static func makeDate(day: Int, month: Int, year: Int?, now: Date) -> Date? {
        guard (1...31).contains(day), (1...12).contains(month) else { return nil }
        let calendar = Calendar.current
        var fullYear = year ?? calendar.component(.year, from: now)
        if fullYear < 100 { fullYear += 2000 }
        var components = DateComponents()
        components.year = fullYear
        components.month = month
        components.day = day
        components.hour = 10
        guard var date = calendar.date(from: components) else { return nil }
        // Без года на афише: если дата уже давно прошла — это следующий год.
        if year == nil, date < now.addingTimeInterval(-30 * 24 * 3600) {
            components.year = fullYear + 1
            date = calendar.date(from: components) ?? date
        }
        return date
    }

    /// Группы первого совпадения регулярного выражения.
    private static func firstMatch(_ expression: NSRegularExpression?, in text: String) -> [String]? {
        guard let expression else { return nil }
        let ns = text as NSString
        guard let match = expression.firstMatch(in: text, options: [], range: NSRange(location: 0, length: ns.length)) else {
            return nil
        }
        var groups: [String] = []
        for index in 1..<match.numberOfRanges {
            let groupRange = match.range(at: index)
            groups.append(groupRange.location == NSNotFound ? "" : ns.substring(with: groupRange))
        }
        return groups
    }
}
