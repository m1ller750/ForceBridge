import SwiftUI

/// Крупное число совместимости.
struct ScoreBadge: View {
    let score: Int

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("\(score)")
                .font(Typo.display(24, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(score >= 70 ? Palette.signal : Palette.ink)
            MonoLabel("Совм.", color: Palette.faint, size: 9)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Совместимость \(score) из 100")
    }
}

struct TeamRow: View {
    let team: Team
    let subtitle: String
    var score: Int? = nil

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                TrussGlyph(states: team.states)
                    .frame(width: 74, height: 32)
                    .padding(.top, 3)
                VStack(alignment: .leading, spacing: 5) {
                    Text(team.name)
                        .font(Typo.title)
                        .foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.leading)
                    Text(subtitle)
                        .font(Typo.footnote)
                        .foregroundStyle(Palette.graphite)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if team.openRoles.isEmpty {
                        MonoLabel("Состав собран", color: Palette.ink, size: 10)
                    } else {
                        HStack(spacing: 5) {
                            MonoLabel("Ищут", color: Palette.faint, size: 10)
                            ForEach(team.openRoles) { role in
                                RoleCode(role: role, style: .vacancy)
                            }
                        }
                    }
                }
                Spacer(minLength: 8)
                if let score {
                    ScoreBadge(score: score)
                }
            }
            .padding(.vertical, 16)
            Hairline()
        }
        .contentShape(Rectangle())
    }
}

struct PersonRow: View {
    let person: Person
    var score: Int? = nil
    var note: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                Monogram(initials: person.initials, size: 42)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(person.name)
                            .font(Typo.headline)
                            .foregroundStyle(Palette.ink)
                        if person.isLookingForTeam {
                            Circle()
                                .fill(Palette.signal)
                                .frame(width: 6, height: 6)
                                .accessibilityLabel("Ищет команду")
                        }
                    }
                    Text(note ?? person.headline)
                        .font(Typo.footnote)
                        .foregroundStyle(Palette.graphite)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 4) {
                        ForEach(person.roles) { role in
                            RoleCode(role: role)
                        }
                        MonoLabel(person.city, color: Palette.faint, size: 10)
                            .padding(.leading, 4)
                    }
                }
                Spacer(minLength: 8)
                if let score {
                    ScoreBadge(score: score)
                }
            }
            .padding(.vertical, 14)
            Hairline()
        }
        .contentShape(Rectangle())
    }
}

/// Разложение оценки совместимости на составляющие.
struct MatchPanel: View {
    let report: MatchReport
    var title: String = "Расчёт совместимости"

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                MonoLabel(title, color: Palette.ink, size: 11, weight: .semibold)
                Spacer()
                Text("\(report.total)")
                    .font(Typo.display(30, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(Palette.signal)
                Text("/100")
                    .font(Typo.mono(12, weight: .semibold))
                    .foregroundStyle(Palette.graphite)
            }
            ForEach(report.factors) { factor in
                LoadBar(label: factor.label, value: factor.value, points: factor.points)
            }
            VStack(alignment: .leading, spacing: 6) {
                ForEach(report.reasons, id: \.self) { reason in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("—")
                            .font(Typo.mono(12))
                            .foregroundStyle(Palette.faint)
                        Text(reason)
                            .font(Typo.footnote)
                            .foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.top, 2)
        }
        .padding(16)
        .background(Palette.surface)
        .overlay { Rectangle().strokeBorder(Palette.lineStrong, lineWidth: 1) }
    }
}

/// Подпись к команде: на какое событие она собирается.
func teamSubtitle(_ team: Team, store: AppStore) -> String {
    if let challenge = store.challenge(team.challengeID) {
        return challenge.title
    }
    let field = team.field.isEmpty ? "" : " · \(team.field)"
    return "Научный проект\(field)"
}
