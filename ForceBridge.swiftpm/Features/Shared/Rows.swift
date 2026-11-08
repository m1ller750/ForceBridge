import SwiftUI

/// Процент совместимости, который посчитал ИИ.
struct ScoreBadge: View {
    let score: Int

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text("\(score)")
                    .font(Typo.display(24, weight: .heavy))
                    .monospacedDigit()
                Text("%")
                    .font(Typo.mono(12, weight: .bold))
            }
            .foregroundStyle(score >= 70 ? Palette.signal : Palette.ink)
            MonoLabel("ИИ · совм.", color: Palette.faint, size: 8.5)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Совместимость по оценке ИИ: \(score) процентов")
    }
}

/// Категории карточки, которые расставил ИИ.
struct CategoryStrip: View {
    @EnvironmentObject private var store: AppStore
    let card: Card
    var compact: Bool = true

    var body: some View {
        if card.isClassifying {
            HStack(spacing: 8) {
                TrussScanner(panels: 5)
                    .frame(width: 44, height: 14)
                MonoLabel("ИИ определяет категории…", color: Palette.signal, size: 9.5)
            }
        } else if card.categories.isEmpty {
            MonoLabel(card.classificationFailed ? "ИИ не смог разобрать — повторит позже" : "Без категорий", color: Palette.faint, size: 9.5)
        } else {
            FlowLayout(spacing: 4, lineSpacing: 4) {
                ForEach(card.categories, id: \.self) { key in
                    if compact {
                        CodeTag(text: store.category(key)?.code ?? key.uppercased(), label: store.category(key)?.title)
                    } else {
                        Text(store.category(key)?.title ?? key)
                            .font(Typo.mono(11, weight: .medium))
                            .foregroundStyle(Palette.ink)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .overlay { Rectangle().strokeBorder(Palette.lineStrong, lineWidth: 1) }
                    }
                }
            }
        }
    }
}

/// Строка ленты объявлений. Дата создания — в правом верхнем углу.
struct CardRow: View {
    let card: Card
    var compatibility: Compatibility? = nil
    var compatibilityLoading: Bool = false
    var isMine: Bool = false
    var responded: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 8) {
                    KindTag(kind: card.kind)
                    if isMine {
                        MonoLabel("Ваше", color: Palette.signal, size: 9.5, weight: .bold)
                    } else if responded {
                        MonoLabel("Вы откликнулись", color: Palette.signal, size: 9.5, weight: .bold)
                    }
                    Spacer(minLength: 6)
                    MonoLabel(Fmt.created(card.createdAt), color: Palette.graphite, size: 9.5)
                        .accessibilityLabel("Создано \(Fmt.created(card.createdAt))")
                }

                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(card.title)
                            .font(Typo.title)
                            .foregroundStyle(Palette.ink)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        if !card.eventName.isEmpty {
                            Text(card.eventName)
                                .font(Typo.footnote.weight(.medium))
                                .foregroundStyle(Palette.ink)
                                .lineLimit(1)
                        }
                        Text(metaLine)
                            .font(Typo.footnote)
                            .foregroundStyle(Palette.graphite)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    trailing
                }

                if !card.roles.isEmpty {
                    HStack(spacing: 8) {
                        TrussGlyph(states: Array(repeating: false, count: min(card.roles.count, 5)))
                            .frame(width: CGFloat(min(card.roles.count, 5)) * 9 + 9, height: 13)
                        Text("Ищут: " + card.roles.joined(separator: ", "))
                            .font(Typo.footnote)
                            .foregroundStyle(Palette.ink)
                            .lineLimit(1)
                    }
                }

                CategoryStrip(card: card)
            }
            .padding(.vertical, 16)
            Hairline()
        }
        .contentShape(Rectangle())
    }

    private var metaLine: String {
        var parts: [String] = []
        if let name = card.authorName, !name.isEmpty { parts.append(name) }
        parts.append(card.placeText)
        if let deadline = card.deadline {
            parts.append("до \(Fmt.numeric(deadline))")
        }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var trailing: some View {
        if let compatibility {
            ScoreBadge(score: compatibility.score)
        } else if compatibilityLoading {
            TrussScanner(panels: 3)
                .frame(width: 30, height: 14)
                .padding(.top, 6)
        } else if isMine, let count = card.responsesCount {
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(count)")
                    .font(Typo.display(22, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(count > 0 ? Palette.signal : Palette.ink)
                MonoLabel(Fmt.plural(count, "отклик", "отклика", "откликов"), color: Palette.faint, size: 8.5)
            }
        }
    }
}

/// Строка человека: монограмма, имя, чем занимается.
struct ProfileRow: View {
    let profile: Profile
    var note: String? = nil
    var isFavorite: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                Monogram(initials: profile.initials, size: 42)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(profile.fullName)
                            .font(Typo.headline)
                            .foregroundStyle(Palette.ink)
                        if isFavorite {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(Palette.signal)
                                .accessibilityLabel("В избранном")
                        }
                    }
                    Text(note ?? profile.occupation)
                        .font(Typo.footnote)
                        .foregroundStyle(Palette.graphite)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if !profile.ageAndCity.isEmpty {
                        MonoLabel(profile.ageAndCity, color: Palette.faint, size: 10)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.faint)
                    .padding(.top, 4)
            }
            .padding(.vertical, 14)
            Hairline()
        }
        .contentShape(Rectangle())
    }
}

/// Нумерованный список: проекты, достижения.
struct NumberedList: View {
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(String(format: "%02d", index + 1))
                        .font(Typo.mono(11, weight: .semibold))
                        .foregroundStyle(Palette.faint)
                    Text(item)
                        .font(Typo.subhead)
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 10)
                .overlay(alignment: .bottom) { Hairline() }
            }
        }
    }
}

/// Индикатор загрузки в фирменном стиле.
struct LoadingNote: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TrussScanner()
                .frame(width: 120, height: 22)
            MonoLabel(text, color: Palette.graphite)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 24)
    }
}
