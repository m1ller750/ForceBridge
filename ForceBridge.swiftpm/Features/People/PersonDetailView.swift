import SwiftUI

struct PersonDetailView: View {
    @EnvironmentObject private var store: AppStore
    let personID: UUID
    @State private var showInvite = false

    var body: some View {
        Group {
            if let person = store.person(personID) {
                content(person)
            } else {
                EmptyNote(title: "Профиль не найден", message: "Возможно, участник удалил аккаунт.")
                    .padding(Metrics.gutter)
            }
        }
        .paperBackground()
        .detailNavigation("Участник")
        .sheet(isPresented: $showInvite) {
            InviteSheet(personID: personID)
        }
    }

    private func content(_ person: Person) -> some View {
        let isMe = person.id == store.me?.id
        let sharedTopics = Set(Matcher.sharedTopics(person.interests, store.me?.interests ?? []))
        let teams = store.teams.filter { $0.memberIDs.contains(person.id) }
        return ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                TitleBlock(person: person, isMe: isMe)

                if !person.headline.isEmpty {
                    Text("«\(person.headline)»")
                        .font(Typo.serif(20))
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !isMe {
                    MatchPanel(report: store.match(for: person), title: "Совместимость с вами")
                    inviteButton(person)
                }

                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle(number: "01", title: "Навыки", trailing: "\(person.skills.count)")
                    TagList(tags: person.skills)
                }

                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle(
                        number: "02",
                        title: "Темы",
                        trailing: isMe || sharedTopics.isEmpty ? nil : "Общих: \(sharedTopics.count)"
                    )
                    TagList(tags: person.interests, highlighted: isMe ? [] : sharedTopics)
                }

                if !person.track.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        SectionTitle(number: "03", title: "Послужной список")
                        ForEach(Array(person.track.enumerated()), id: \.offset) { index, item in
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
                            .padding(.vertical, 11)
                            .overlay(alignment: .bottom) { Hairline() }
                        }
                    }
                }

                if !teams.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        SectionTitle(number: "04", title: "Команды", trailing: "\(teams.count)")
                        ForEach(teams) { team in
                            NavigationLink(value: Route.team(team.id)) {
                                TeamRow(team: team, subtitle: teamSubtitle(team, store: store))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.top, 16)
            .padding(.bottom, 40)
            .contentColumn()
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private func inviteButton(_ person: Person) -> some View {
        if store.hasPendingInvitation(for: person) {
            RequestStatusLine(status: .pending, pendingText: "Приглашение отправлено — ждём ответа")
        } else if store.ownedTeams.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Button("Пригласить в команду") {
                    showInvite = true
                }
                .buttonStyle(.signal)
                .disabled(true)
                Text("Чтобы приглашать людей, соберите команду во вкладке «Команды».")
                    .font(Typo.footnote)
                    .foregroundStyle(Palette.graphite)
            }
        } else {
            Button("Пригласить в команду") {
                showInvite = true
            }
            .buttonStyle(.signal)
        }
    }
}
