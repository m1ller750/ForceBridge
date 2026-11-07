import SwiftUI

/// «Паспорт участника» — оформлен как основная надпись (штамп) инженерного чертежа.
struct TitleBlock: View {
    let person: Person
    var isMe: Bool = false
    var sheetNumber: String = "1 / 1"

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                cell("Участник") {
                    Text(person.name)
                        .font(Typo.display(21, weight: .bold))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                }
                verticalRule
                cell("Узел") {
                    Monogram(initials: person.initials, size: 40, emphasized: isMe)
                }
                .frame(width: 78)
            }
            .fixedSize(horizontal: false, vertical: true)
            horizontalRule
            HStack(spacing: 0) {
                cell("Роли") {
                    HStack(spacing: 4) {
                        ForEach(person.roles) { role in
                            RoleCode(role: role, style: .filled)
                        }
                    }
                }
                verticalRule
                cell("Нагрузка") {
                    Text("\(person.hoursPerWeek) ч/нед")
                        .font(Typo.mono(14, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                }
                .frame(width: 108)
            }
            .fixedSize(horizontal: false, vertical: true)
            horizontalRule
            HStack(spacing: 0) {
                cell("Организация") {
                    Text(person.affiliation.isEmpty ? "—" : person.affiliation)
                        .font(Typo.subhead.weight(.medium))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(2)
                }
                verticalRule
                cell("Город") {
                    Text(person.city.isEmpty ? "—" : person.city)
                        .font(Typo.subhead.weight(.medium))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(width: 108)
            }
            .fixedSize(horizontal: false, vertical: true)
            horizontalRule
            HStack(spacing: 0) {
                cell("Формат") {
                    Text(person.format.title)
                        .font(Typo.mono(12, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                }
                verticalRule
                cell("Статус") {
                    Text(person.isLookingForTeam ? "Ищет команду" : "Не ищет")
                        .font(Typo.mono(12, weight: .semibold))
                        .foregroundStyle(person.isLookingForTeam ? Palette.signal : Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                verticalRule
                cell("Лист") {
                    Text(sheetNumber)
                        .font(Typo.mono(12, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                }
                .frame(width: 66)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .background(Palette.surface)
        .overlay { Rectangle().strokeBorder(Palette.ink, lineWidth: 1.6) }
        .accessibilityElement(children: .combine)
    }

    private var horizontalRule: some View {
        Rectangle()
            .fill(Palette.ink)
            .frame(height: 1)
    }

    private var verticalRule: some View {
        Rectangle()
            .fill(Palette.ink)
            .frame(width: 1)
    }

    private func cell<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            MonoLabel(label, color: Palette.faint, size: 9)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }
}
