import Foundation

/// Кодирование JSON для Supabase: ключи в snake_case, даты Postgres.
enum JSONCoding {
    private static let isoFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let isoPlain: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = parseDate(string) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unrecognized date: \(string)")
        }
        return decoder
    }

    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(isoFractional.string(from: date))
        }
        return encoder
    }

    /// Дата без времени для колонок типа date: «2026-11-20».
    static func dayString(_ date: Date) -> String {
        dayFormatter.string(from: date)
    }

    /// Разбирает «2026-11-07», «2026-11-07T10:00:00+00:00» и «2026-11-07T10:00:00.123456+00:00».
    static func parseDate(_ raw: String) -> Date? {
        let string = raw.trimmingCharacters(in: .whitespaces)
        if string.count == 10 {
            return dayFormatter.date(from: string)
        }
        let normalized = trimFraction(string.replacingOccurrences(of: " ", with: "T"))
        return isoFractional.date(from: normalized) ?? isoPlain.date(from: normalized)
    }

    /// Postgres отдаёт микросекунды; ISO8601DateFormatter надёжно понимает только миллисекунды.
    private static func trimFraction(_ string: String) -> String {
        guard let timeStart = string.firstIndex(of: "T"),
              let dot = string[timeStart...].firstIndex(of: ".") else { return string }
        var end = string.index(after: dot)
        while end < string.endIndex, string[end].isNumber {
            end = string.index(after: end)
        }
        var digits = String(string[string.index(after: dot)..<end])
        if digits.count > 3 {
            digits = String(digits.prefix(3))
        }
        while digits.count < 3 {
            digits += "0"
        }
        var suffix = String(string[end...])
        if suffix.isEmpty {
            suffix = "Z"
        }
        return String(string[..<dot]) + "." + digits + suffix
    }
}
