import SwiftUI

// MARK: - Текстовые примитивы

/// Техническая подпись: моноширинный шрифт, верхний регистр, разрядка.
struct MonoLabel: View {
    let text: String
    var color: Color
    var size: CGFloat
    var weight: Font.Weight

    init(_ text: String, color: Color = Palette.graphite, size: CGFloat = 11, weight: Font.Weight = .medium) {
        self.text = text
        self.color = color
        self.size = size
        self.weight = weight
    }

    var body: some View {
        Text(text.uppercased())
            .font(Typo.mono(size, weight: weight))
            .tracking(0.6)
            .foregroundStyle(color)
            .lineLimit(1)
    }
}

/// Волосяная линия толщиной в два физических пикселя.
struct Hairline: View {
    var color: Color = Palette.line
    var vertical: Bool = false
    @Environment(\.pixelLength) private var pixel

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: vertical ? pixel * 2 : nil, height: vertical ? nil : pixel * 2)
            .accessibilityHidden(true)
    }
}

/// Линейка с делениями — фирменная деталь под заголовками экранов.
struct Ruler: View {
    var color: Color = Palette.lineStrong

    var body: some View {
        Canvas { context, size in
            var path = Path()
            path.move(to: CGPoint(x: 0, y: size.height - 0.5))
            path.addLine(to: CGPoint(x: size.width, y: size.height - 0.5))
            var x: CGFloat = 0.5
            var index = 0
            while x <= size.width {
                let tick: CGFloat
                if index % 10 == 0 {
                    tick = size.height
                } else if index % 5 == 0 {
                    tick = size.height * 0.6
                } else {
                    tick = size.height * 0.3
                }
                path.move(to: CGPoint(x: x, y: size.height))
                path.addLine(to: CGPoint(x: x, y: size.height - tick))
                x += 6
                index += 1
            }
            context.stroke(path, with: .color(color), lineWidth: 1)
        }
        .frame(height: 9)
        .accessibilityHidden(true)
    }
}

/// Шапка корневого экрана вкладки.
struct ScreenHeader<Trailing: View>: View {
    let index: String
    let title: String
    let subtitle: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                MonoLabel("ForceBridge / \(index)", color: Palette.faint)
                Spacer(minLength: 12)
                trailing()
            }
            Text(title)
                .font(Typo.display(36, weight: .heavy))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .accessibilityAddTraits(.isHeader)
            Text(subtitle)
                .font(Typo.subhead)
                .foregroundStyle(Palette.graphite)
                .fixedSize(horizontal: false, vertical: true)
            Ruler()
                .padding(.top, 6)
        }
    }
}

extension ScreenHeader where Trailing == EmptyView {
    init(index: String, title: String, subtitle: String) {
        self.init(index: index, title: title, subtitle: subtitle, trailing: { EmptyView() })
    }
}

/// Заголовок раздела: «01  ОТКРЫТЫЕ КОМАНДЫ ........ 12».
struct SectionTitle: View {
    let number: String
    let title: String
    var trailing: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(number)
                    .font(Typo.mono(11, weight: .semibold))
                    .foregroundStyle(Palette.signal)
                Text(title.uppercased())
                    .font(Typo.mono(11, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Spacer(minLength: 8)
                if let trailing {
                    Text(trailing.uppercased())
                        .font(Typo.mono(11))
                        .foregroundStyle(Palette.graphite)
                }
            }
            Hairline(color: Palette.lineStrong)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Метки

/// Код роли в рамке: «ML», «DSN». Пунктир — вакансия.
struct RoleCode: View {
    enum Style { case filled, outline, vacancy }

    let role: Role
    var style: Style = .outline

    var body: some View {
        Text(role.code)
            .font(Typo.mono(10.5, weight: .bold))
            .tracking(0.4)
            .padding(.horizontal, 5)
            .padding(.vertical, 2.5)
            .foregroundStyle(textColor)
            .background(fillColor)
            .overlay {
                Rectangle()
                    .strokeBorder(borderColor, style: StrokeStyle(lineWidth: 1, dash: style == .vacancy ? [3, 2] : []))
            }
            .accessibilityLabel(role.title)
    }

    private var textColor: Color {
        switch style {
        case .filled: return Palette.paper
        case .outline: return Palette.ink
        case .vacancy: return Palette.signal
        }
    }

    private var fillColor: Color {
        switch style {
        case .filled: return Palette.ink
        case .outline: return Color.clear
        case .vacancy: return Palette.signalSoft
        }
    }

    private var borderColor: Color {
        switch style {
        case .filled: return Palette.ink
        case .outline: return Palette.lineStrong
        case .vacancy: return Palette.signal
        }
    }
}

/// Тип события: «HCK  ХАКАТОН».
struct KindTag: View {
    let kind: ChallengeKind

    var body: some View {
        HStack(spacing: 6) {
            Text(kind.code)
                .font(Typo.mono(10, weight: .bold))
                .foregroundStyle(Palette.paper)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Palette.ink)
            Text(kind.title.uppercased())
                .font(Typo.mono(10, weight: .medium))
                .tracking(0.6)
                .foregroundStyle(Palette.graphite)
                .lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(kind.title)
    }
}

/// Фильтр-переключатель.
struct Chip: View {
    let title: String
    var isOn: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Typo.mono(12, weight: .medium))
                .lineLimit(1)
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .foregroundStyle(isOn ? Palette.paper : Palette.ink)
                .background(isOn ? Palette.ink : Color.clear)
                .overlay {
                    Rectangle().strokeBorder(isOn ? Palette.ink : Palette.lineStrong, lineWidth: 1)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// Монограмма человека — круглый «узел» конструкции.
struct Monogram: View {
    let initials: String
    var size: CGFloat = 44
    var emphasized: Bool = false

    var body: some View {
        Text(initials)
            .font(Typo.mono(size * 0.3, weight: .bold))
            .foregroundStyle(emphasized ? Palette.onSignal : Palette.ink)
            .frame(width: size, height: size)
            .background { Circle().fill(emphasized ? Palette.signal : Palette.surface) }
            .overlay { Circle().strokeBorder(Palette.ink, lineWidth: 1.2) }
            .accessibilityHidden(true)
    }
}

/// Облако тегов; выделенные теги — совпадения.
struct TagList: View {
    let tags: [String]
    var highlighted: Set<String> = []

    var body: some View {
        FlowLayout(spacing: 6, lineSpacing: 6) {
            ForEach(tags, id: \.self) { tag in
                let isHit = highlighted.contains(tag)
                Text(tag)
                    .font(Typo.mono(11.5))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .foregroundStyle(isHit ? Palette.onSignal : Palette.ink)
                    .background(isHit ? Palette.signal : Color.clear)
                    .overlay {
                        Rectangle().strokeBorder(isHit ? Palette.signal : Palette.lineStrong, lineWidth: 1)
                    }
            }
        }
    }
}

// MARK: - Строки данных

/// Строка технического паспорта: подпись слева, значение справа.
struct SpecRow: View {
    let label: String
    let value: String
    var accent: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                MonoLabel(label, size: 10.5)
                    .frame(width: 108, alignment: .leading)
                Text(value)
                    .font(Typo.subhead.weight(.medium))
                    .foregroundStyle(accent ? Palette.signal : Palette.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 11)
            Hairline()
        }
        .accessibilityElement(children: .combine)
    }
}

/// Сегментная шкала — вместо круговых прогресс-баров.
struct SegmentBar: View {
    let value: Double
    var segments: Int = 20
    var color: Color = Palette.ink

    var body: some View {
        let filled = Int((min(max(value, 0), 1) * Double(segments)).rounded())
        HStack(spacing: 2) {
            ForEach(0..<segments, id: \.self) { index in
                Rectangle()
                    .fill(index < filled ? color : Palette.line)
            }
        }
        .accessibilityHidden(true)
    }
}

/// Шкала одной составляющей совместимости.
struct LoadBar: View {
    let label: String
    let value: Double
    let points: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                MonoLabel(label, size: 10)
                Spacer()
                Text("\(Int((value * Double(points)).rounded()))/\(points)")
                    .font(Typo.mono(10, weight: .semibold))
                    .foregroundStyle(Palette.ink)
            }
            SegmentBar(value: value)
                .frame(height: 7)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("\(Int((value * Double(points)).rounded())) из \(points)")
    }
}

/// Пустое состояние: пунктирная рамка и короткое пояснение.
struct EmptyNote: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(Typo.headline)
                .foregroundStyle(Palette.ink)
            Text(message)
                .font(Typo.subhead)
                .foregroundStyle(Palette.graphite)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .overlay {
            Rectangle().strokeBorder(Palette.lineStrong, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        }
    }
}

/// Поле формы с подписью в стиле чертёжного бланка.
struct FieldBox<Content: View>: View {
    let label: String
    var hint: String? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                MonoLabel(label, size: 10.5)
                Spacer()
                if let hint {
                    MonoLabel(hint, color: Palette.faint, size: 10.5)
                }
            }
            content()
                .font(Typo.body)
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(Palette.surface)
                .overlay { Rectangle().strokeBorder(Palette.lineStrong, lineWidth: 1) }
        }
    }
}

/// Метки обреза по углам — как на типографском макете.
struct CropMarks: View {
    var color: Color = Palette.ink

    var body: some View {
        Canvas { context, size in
            let outset: CGFloat = 12
            let length: CGFloat = 8
            let gap: CGFloat = 3
            let rect = CGRect(x: outset, y: outset, width: size.width - outset * 2, height: size.height - outset * 2)
            let corners = [
                CGPoint(x: rect.minX, y: rect.minY),
                CGPoint(x: rect.maxX, y: rect.minY),
                CGPoint(x: rect.minX, y: rect.maxY),
                CGPoint(x: rect.maxX, y: rect.maxY)
            ]
            var path = Path()
            for corner in corners {
                let sx: CGFloat = corner.x == rect.minX ? -1 : 1
                let sy: CGFloat = corner.y == rect.minY ? -1 : 1
                path.move(to: CGPoint(x: corner.x + sx * gap, y: corner.y))
                path.addLine(to: CGPoint(x: corner.x + sx * (gap + length), y: corner.y))
                path.move(to: CGPoint(x: corner.x, y: corner.y + sy * gap))
                path.addLine(to: CGPoint(x: corner.x, y: corner.y + sy * (gap + length)))
            }
            context.stroke(path, with: .color(color), lineWidth: 1)
        }
        .padding(-12)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Кнопки

struct SignalButtonStyle: ButtonStyle {
    var fullWidth: Bool = true
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typo.mono(13, weight: .bold))
            .tracking(0.8)
            .textCase(.uppercase)
            .lineLimit(1)
            .foregroundStyle(isEnabled ? Palette.onSignal : Palette.graphite)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.horizontal, 18)
            .padding(.vertical, 15)
            .background(isEnabled ? Palette.signal : Palette.line)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.black.opacity(isEnabled ? 0.2 : 0))
                    .frame(height: 3)
            }
            .offset(y: configuration.isPressed ? 1.5 : 0)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .contentShape(Rectangle())
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct InkButtonStyle: ButtonStyle {
    var fullWidth: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typo.mono(13, weight: .bold))
            .tracking(0.8)
            .textCase(.uppercase)
            .lineLimit(1)
            .foregroundStyle(Palette.paper)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.horizontal, 18)
            .padding(.vertical, 15)
            .background(Palette.ink)
            .offset(y: configuration.isPressed ? 1.5 : 0)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .contentShape(Rectangle())
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct OutlineButtonStyle: ButtonStyle {
    var fullWidth: Bool = true
    var compact: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typo.mono(compact ? 11 : 13, weight: .bold))
            .tracking(0.8)
            .textCase(.uppercase)
            .lineLimit(1)
            .foregroundStyle(Palette.ink)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.horizontal, compact ? 10 : 18)
            .padding(.vertical, compact ? 8 : 14)
            .background(configuration.isPressed ? Palette.line : Color.clear)
            .overlay { Rectangle().strokeBorder(Palette.ink, lineWidth: 1.2) }
            .contentShape(Rectangle())
    }
}

extension ButtonStyle where Self == SignalButtonStyle {
    static var signal: SignalButtonStyle { SignalButtonStyle() }
}

extension ButtonStyle where Self == InkButtonStyle {
    static var ink: InkButtonStyle { InkButtonStyle() }
}

extension ButtonStyle where Self == OutlineButtonStyle {
    static var outline: OutlineButtonStyle { OutlineButtonStyle() }
    static var outlineCompact: OutlineButtonStyle { OutlineButtonStyle(fullWidth: false, compact: true) }
}

/// Текстовая ссылка со стрелкой: «Все команды →».
struct ArrowLink: View {
    let title: String
    var color: Color = Palette.ink
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title.uppercased())
                    .font(Typo.mono(11.5, weight: .semibold))
                    .tracking(0.6)
                Image(systemName: "arrow.right")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(color)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Раскладка «поток» для тегов

struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    var lineSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        var widest: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                y += lineHeight + lineSpacing
                x = 0
                lineHeight = 0
            }
            x += size.width
            widest = max(widest, x)
            x += spacing
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: widest, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                y += lineHeight + lineSpacing
                x = bounds.minX
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
