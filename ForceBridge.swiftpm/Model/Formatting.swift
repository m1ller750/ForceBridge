import Foundation

/// Форматирование дат и чисел по-русски.
enum Fmt {
    static let locale = Locale(identifier: "ru_RU")

    private static let dayMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "d MMMM"
        return formatter
    }()

    private static let monthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "LLLL yyyy"
        return formatter
    }()

    private static let numericFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "dd.MM"
        return formatter
    }()

    private static let fullNumericFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    /// «07.11.2026»
    static func numericFull(_ date: Date) -> String {
        fullNumericFormatter.string(from: date)
    }

    /// Дата создания для угла карточки: «сегодня 14:20», «вчера 09:05» или «07.11.2026».
    static func created(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "сегодня " + timeFormatter.string(from: date)
        }
        if calendar.isDateInYesterday(date) {
            return "вчера " + timeFormatter.string(from: date)
        }
        return numericFull(date)
    }

    static let monthsShort = ["ЯНВ", "ФЕВ", "МАР", "АПР", "МАЙ", "ИЮН", "ИЮЛ", "АВГ", "СЕН", "ОКТ", "НОЯ", "ДЕК"]
    static let weekdaysShort = ["ВС", "ПН", "ВТ", "СР", "ЧТ", "ПТ", "СБ"]

    /// «14 ноября»
    static func dayMonth(_ date: Date) -> String {
        dayMonthFormatter.string(from: date)
    }

    /// «Ноябрь 2026»
    static func monthYear(_ date: Date) -> String {
        monthYearFormatter.string(from: date).capitalized(with: locale)
    }

    /// «14.11»
    static func numeric(_ date: Date) -> String {
        numericFormatter.string(from: date)
    }

    static func day(_ date: Date) -> String {
        String(Calendar.current.component(.day, from: date))
    }

    static func monthShort(_ date: Date) -> String {
        let month = Calendar.current.component(.month, from: date)
        return monthsShort[max(0, min(11, month - 1))]
    }

    static func weekdayShort(_ date: Date) -> String {
        let weekday = Calendar.current.component(.weekday, from: date)
        return weekdaysShort[max(0, min(6, weekday - 1))]
    }

    /// Ключ месяца для группировки списков.
    static func monthKey(_ date: Date) -> Int {
        let components = Calendar.current.dateComponents([.year, .month], from: date)
        return (components.year ?? 0) * 100 + (components.month ?? 0)
    }

    static func daysUntil(_ date: Date, from now: Date = Date()) -> Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: now)
        let end = calendar.startOfDay(for: date)
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }

    /// «через 3 дня», «завтра», «сегодня», «прошла».
    static func countdown(_ date: Date, now: Date = Date()) -> String {
        let days = daysUntil(date, from: now)
        if days < 0 { return "завершена" }
        if days == 0 { return "сегодня" }
        if days == 1 { return "завтра" }
        return "через \(days) \(plural(days, "день", "дня", "дней"))"
    }

    /// Русская форма множественного числа: 1 день, 2 дня, 5 дней.
    static func plural(_ number: Int, _ one: String, _ few: String, _ many: String) -> String {
        let n10 = abs(number) % 10
        let n100 = abs(number) % 100
        if n10 == 1 && n100 != 11 { return one }
        if (2...4).contains(n10) && !(12...14).contains(n100) { return few }
        return many
    }

    static func count(_ number: Int, _ one: String, _ few: String, _ many: String) -> String {
        "\(number) \(plural(number, one, few, many))"
    }

    static func date(byAddingDays days: Int, to date: Date = Date(), hour: Int = 10) -> Date {
        let calendar = Calendar.current
        let base = calendar.startOfDay(for: date)
        let shifted = calendar.date(byAdding: .day, value: days, to: base) ?? base
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: shifted) ?? shifted
    }
}
