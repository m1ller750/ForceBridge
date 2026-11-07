import SwiftUI

struct ChallengeDetailView: View {
    @EnvironmentObject private var store: AppStore
    let challengeID: UUID
    @State private var showTeamEditor = false

    var body: some View {
        Group {
            if let challenge = store.challenge(challengeID) {
                content(challenge)
            } else {
                EmptyNote(title: "Вызов не найден", message: "Возможно, он был удалён.")
                    .padding(Metrics.gutter)
            }
        }
        .paperBackground()
        .detailNavigation("Вызов")
        .sheet(isPresented: $showTeamEditor) {
            TeamEditorView(preselectedChallengeID: challengeID)
        }
    }

    private func content(_ challenge: Challenge) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header(challenge)
                specs(challenge)
                Text(challenge.summary)
                    .font(Typo.serif(18))
                    .foregroundStyle(Palette.ink)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                actions(challenge)
                teamsSection(challenge)
                peopleSection(challenge)
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.top, 16)
            .padding(.bottom, 40)
            .contentColumn()
        }
        .scrollIndicators(.hidden)
    }

    private func header(_ challenge: Challenge) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            KindTag(kind: challenge.kind)
            Text(challenge.title)
                .font(Typo.display(28, weight: .heavy))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(challenge.organizer)
                .font(Typo.subhead)
                .foregroundStyle(Palette.graphite)
            Ruler()
                .padding(.top, 4)
        }
    }

    private func specs(_ challenge: Challenge) -> some View {
        let deadlineDays = Fmt.daysUntil(challenge.registrationDeadline)
        let deadlineText = deadlineDays < 0
            ? "закрыта \(Fmt.dayMonth(challenge.registrationDeadline))"
            : "до \(Fmt.dayMonth(challenge.registrationDeadline)) — \(Fmt.countdown(challenge.registrationDeadline))"
        return VStack(spacing: 0) {
            Hairline()
            SpecRow(label: "Старт", value: "\(Fmt.dayMonth(challenge.startDate)), \(Fmt.countdown(challenge.startDate))")
            SpecRow(label: "Регистрация", value: deadlineText, accent: deadlineDays >= 0 && deadlineDays <= 7)
            SpecRow(label: "Формат", value: challenge.placeText)
            SpecRow(label: "Команда", value: challenge.teamSizeText)
            SpecRow(label: "Приз", value: challenge.prize ?? "—")
            SpecRow(label: "Темы", value: challenge.topics.isEmpty ? "Любые" : challenge.topics.joined(separator: ", "))
        }
    }

    private func actions(_ challenge: Challenge) -> some View {
        let saved = store.isSaved(challenge)
        return VStack(spacing: 10) {
            Button("Собрать команду") {
                showTeamEditor = true
            }
            .buttonStyle(.signal)
            Button(saved ? "В сохранённых" : "Сохранить вызов") {
                store.toggleSaved(challenge)
            }
            .buttonStyle(.outline)
            .sensoryFeedback(.success, trigger: saved)
        }
    }

    @ViewBuilder
    private func teamsSection(_ challenge: Challenge) -> some View {
        let teams = store.teams(for: challenge)
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle(number: "01", title: "Команды на этот вызов", trailing: "\(teams.count)")
            if teams.isEmpty {
                EmptyNote(
                    title: "Команд пока нет",
                    message: "Станьте первыми: опубликуйте команду с вакансиями — подходящие участники увидят её в ленте."
                )
                .padding(.top, 14)
            } else {
                ForEach(teams) { team in
                    NavigationLink(value: Route.team(team.id)) {
                        TeamRow(
                            team: team,
                            subtitle: team.pitch,
                            score: store.isOwner(team) || store.isMember(team) ? nil : store.fit(of: team).total
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func peopleSection(_ challenge: Challenge) -> some View {
        let people = lookingPeople(for: challenge)
        if !people.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                SectionTitle(number: "02", title: "Ищут команду по этим темам", trailing: "\(people.count)")
                ForEach(people) { ranked in
                    NavigationLink(value: Route.person(ranked.person.id)) {
                        PersonRow(person: ranked.person, score: ranked.report.total)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func lookingPeople(for challenge: Challenge) -> [RankedPerson] {
        let topics = Set(challenge.topics.map { $0.lowercased() })
        let filtered = store.rankedPeople.filter { (ranked: RankedPerson) -> Bool in
            guard ranked.person.isLookingForTeam else { return false }
            if topics.isEmpty { return true }
            return ranked.person.interests.contains { topics.contains($0.lowercased()) }
        }
        return Array(filtered.prefix(5))
    }
}
