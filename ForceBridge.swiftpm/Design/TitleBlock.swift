import SwiftUI

/// «Паспорт участника» — оформлен как основная надпись (штамп) инженерного чертежа.
struct TitleBlock: View {
    let profile: Profile
    var isMe: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                cell("Участник") {
                    Text(profile.fullName)
                        .font(Typo.display(21, weight: .bold))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                }
                verticalRule
                cell("Узел") {
                    Monogram(initials: profile.initials, size: 40, emphasized: isMe)
                }
                .frame(width: 78)
            }
            .fixedSize(horizontal: false, vertical: true)
            horizontalRule
            HStack(spacing: 0) {
                cell("Чем занимается") {
                    Text(profile.occupation.isEmpty ? "—" : profile.occupation)
                        .font(Typo.subhead.weight(.medium))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                verticalRule
                cell("Возраст") {
                    Text(profile.age.map { "\($0)" } ?? "—")
                        .font(Typo.mono(14, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                }
                .frame(width: 78)
            }
            .fixedSize(horizontal: false, vertical: true)
            horizontalRule
            HStack(spacing: 0) {
                cell("Город") {
                    Text(profile.city.isEmpty ? "—" : profile.city)
                        .font(Typo.subhead.weight(.medium))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                verticalRule
                cell("Связь") {
                    Text(profile.messenger.title)
                        .font(Typo.mono(12, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                verticalRule
                cell("Резюме") {
                    Text(profile.hasResume ? "Есть" : "Нет")
                        .font(Typo.mono(12, weight: .semibold))
                        .foregroundStyle(profile.hasResume ? Palette.signal : Palette.faint)
                }
                .frame(width: 78)
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
