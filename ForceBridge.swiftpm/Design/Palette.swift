import SwiftUI
import UIKit

// MARK: - Цвет
// Три основных тона: бумага, тушь и «международный оранжевый» —
// цвет, которым красят мосты и сигнальные конструкции. Никаких градиентов.

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        let r = CGFloat((hex >> 16) & 0xFF) / 255
        let g = CGFloat((hex >> 8) & 0xFF) / 255
        let b = CGFloat(hex & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: alpha)
    }

    static func adaptive(light: UInt32, dark: UInt32, lightAlpha: CGFloat = 1, darkAlpha: CGFloat = 1) -> UIColor {
        UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(hex: dark, alpha: darkAlpha)
            }
            return UIColor(hex: light, alpha: lightAlpha)
        }
    }
}

enum Palette {
    /// Фон — тёплая чертёжная бумага / почти чёрный в тёмной теме.
    static let paper = Color(uiColor: .adaptive(light: 0xF1EEE6, dark: 0x111110))
    /// Слегка приподнятая поверхность: поля ввода, карточки.
    static let surface = Color(uiColor: .adaptive(light: 0xF8F6F0, dark: 0x1B1B19))
    /// Основной текст и линии — «тушь».
    static let ink = Color(uiColor: .adaptive(light: 0x151514, dark: 0xEDEAE2))
    /// Вторичный текст.
    static let graphite = Color(uiColor: .adaptive(light: 0x5E5C56, dark: 0x9D9A91))
    /// Третичный текст, подписи.
    static let faint = Color(uiColor: .adaptive(light: 0x9A968C, dark: 0x6B6861))
    /// Волосяные линии.
    static let line = Color(uiColor: .adaptive(light: 0x151514, dark: 0xEDEAE2, lightAlpha: 0.13, darkAlpha: 0.15))
    /// Более заметные линии: рамки полей, линейки.
    static let lineStrong = Color(uiColor: .adaptive(light: 0x151514, dark: 0xEDEAE2, lightAlpha: 0.34, darkAlpha: 0.38))
    /// Сигнальный оранжевый: действия, вакансии, важные числа.
    static let signal = Color(uiColor: .adaptive(light: 0xFF4F00, dark: 0xFF5C1A))
    /// Подложка сигнального цвета.
    static let signalSoft = Color(uiColor: .adaptive(light: 0xFF4F00, dark: 0xFF5C1A, lightAlpha: 0.10, darkAlpha: 0.16))
    /// Текст на оранжевом — всегда тёмный (контраст 6.4:1).
    static let onSignal = Color(uiColor: UIColor(hex: 0x151514))
}

// MARK: - Типографика
// Широкий гротеск SF Pro Expanded — для заголовков,
// SF Mono — для технических подписей, New York — для цитат и питчей.

enum Typo {
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        Font.system(size: size, weight: weight).width(.expanded)
    }

    static func mono(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        Font.system(size: size, weight: weight, design: .monospaced)
    }

    static func serif(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.system(size: size, weight: weight, design: .serif)
    }

    static let title = Font.system(.title3, design: .default, weight: .semibold)
    static let headline = Font.system(.headline)
    static let body = Font.system(.body)
    static let subhead = Font.system(.subheadline)
    static let footnote = Font.system(.footnote)
}

// MARK: - Сетка

enum Metrics {
    static let gutter: CGFloat = 20
    static let maxContentWidth: CGFloat = 720
    static let tabBarHeight: CGFloat = 58
}

extension View {
    /// Центрированная колонка с ограниченной шириной (iPad, альбомная ориентация).
    func contentColumn() -> some View {
        self
            .frame(maxWidth: Metrics.maxContentWidth)
            .frame(maxWidth: .infinity)
    }

    /// Фон бумаги на весь экран.
    func paperBackground() -> some View {
        self.background(Palette.paper.ignoresSafeArea())
    }
}
