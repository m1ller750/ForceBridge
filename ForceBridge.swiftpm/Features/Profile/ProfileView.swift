import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showEditor = false
    @State private var confirmReset = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenHeader(
                    index: "04",
                    title: "Профиль",
                    subtitle: "Паспорт участника, запросы и ваши команды."
                ) {
                    Button {
                        showEditor = true
                    } label: {
                        Text("ИЗМЕНИТЬ")
                            .font(Typo.mono(11, weight: .bold))
                            .foregroundStyle(Palette.ink)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .overlay { Rectangle().strokeBorder(Palette.ink, lineWidth: 1) }
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Изменить профиль")
                }
                .padding(.bottom, 22)

                if let me = store.me {
                    VStack(alignment: .leading, spacing: 30) {
                        passport(me)
                        incomingSection
                        outgoingSection
                        teamsSection
                        aboutSection(me)
                        savedSection
                        dataSection
                    }
                }
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.top, 12)
            .padding(.bottom, 32)
            .contentColumn()
        }
        .scrollIndicators(.hidden)
        .paperBackground()
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showEditor) {
            ProfileEditorView()
        }
        .confirmationDialog("Сбросить все данные?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Сбросить", role: .destructive) {
                store.resetAll()
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Профиль, команды и запросы будут удалены, демо-данные восстановятся.")
        }
    }

    // MARK: Паспорт

    private func passport(_ me: Person) -> some View {
        let looking = Binding<Bool>(
            get: { store.me?.isLookingForTeam ?? false },
            set: { store.setLookingForTeam($0) }
        )
        return VStack(alignment: .leading, spacing: 14) {
            TitleBlock(person: me, isMe: true)
            if !me.headline.isEmpty {
                Text("«\(me.headline)»")
                    .font(Typo.serif(18))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Toggle(isOn: looking) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ищу команду")
                        .font(Typo.headline)
                        .foregroundStyle(Palette.ink)
                    Text("Вас видно в подборках и на карте сил с оранжевой меткой.")
                        .font(Typo.footnote)
                        .foregroundStyle(Palette.graphite)
                }
            }
            .tint(Palette.signal)
            .padding(.top, 4)
        }
    }

    // MARK: Запросы

    @ViewBuilder
    private var incomingSection: some View {
        let pending = store.incomingPending
        let resolved = store.incomingResolved
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(number: "01", title: "Входящие", trailing: pending.isEmpty ? "нет новых" : "\(pending.count) новых")
            if pending.isEmpty && resolved.isEmpty {
                EmptyNote(
                    title: "Пока тихо",
                    message: "Здесь появятся приглашения от команд и отклики на ваши вакансии."
                )
            }
            ForEach(pending) { request in
                IncomingRequestCard(request: request)
            }
            ForEach(resolved.prefix(4)) { request in
                RequestLine(request: request)
            }
        }
    }

    @ViewBuilder
    private var outgoingSection: some View {
        let outgoing = store.outgoing
        if !outgoing.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                SectionTitle(number: "02", title: "Исходящие", trailing: "\(outgoing.count)")
                ForEach(outgoing) { request in
                    RequestLine(request: request)
                }
            }
        }
    }

    // MARK: Команды

    @ViewBuilder
    private var teamsSection: some View {
        let teams = store.myTeams
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle(number: "03", title: "Мои команды", trailing: "\(teams.count)")
            if teams.isEmpty {
                EmptyNote(
                    title: "Вы пока не в команде",
                    message: "Откликнитесь на вакансию во вкладке «Команды» или соберите свою."
                )
                .padding(.top, 12)
            }
            ForEach(teams) { team in
                NavigationLink(value: Route.team(team.id)) {
                    TeamRow(
                        team: team,
                        subtitle: (store.isOwner(team) ? "Вы собираете · " : "Вы в составе · ") + teamSubtitle(team, store: store)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: О себе

    private func aboutSection(_ me: Person) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(number: "04", title: "Навыки", trailing: "\(me.skills.count)")
                if me.skills.isEmpty {
                    Text("Добавьте навыки в редакторе профиля.")
                        .font(Typo.footnote)
                        .foregroundStyle(Palette.graphite)
                } else {
                    TagList(tags: me.skills)
                }
            }
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(number: "05", title: "Темы", trailing: "\(me.interests.count)")
                TagList(tags: me.interests)
            }
            if !me.track.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    SectionTitle(number: "06", title: "Послужной список")
                    ForEach(Array(me.track.enumerated()), id: \.offset) { index, item in
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
        }
    }

    @ViewBuilder
    private var savedSection: some View {
        let saved = store.sortedChallenges.filter { store.isSaved($0) }
        if !saved.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                SectionTitle(number: "07", title: "Сохранённые вызовы", trailing: "\(saved.count)")
                ForEach(saved) { challenge in
                    NavigationLink(value: Route.challenge(challenge.id)) {
                        HStack(spacing: 12) {
                            KindTag(kind: challenge.kind)
                            Text(challenge.title)
                                .font(Typo.subhead.weight(.medium))
                                .foregroundStyle(Palette.ink)
                                .lineLimit(1)
                            Spacer()
                            MonoLabel(Fmt.numeric(challenge.startDate), color: Palette.graphite, size: 10)
                        }
                        .padding(.vertical, 13)
                        .overlay(alignment: .bottom) { Hairline() }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(number: "—", title: "Данные")
            Text("Прототип хранит всё на устройстве. Люди, команды и события в ленте — демонстрационные, ответы на запросы имитируются.")
                .font(Typo.footnote)
                .foregroundStyle(Palette.graphite)
                .fixedSize(horizontal: false, vertical: true)
            Button("Сбросить демо-данные") {
                confirmReset = true
            }
            .buttonStyle(.outline)
        }
    }
}

// MARK: - Карточки запросов

struct IncomingRequestCard: View {
    @EnvironmentObject private var store: AppStore
    let request: JoinRequest

    var body: some View {
        let team = store.team(request.teamID)
        let person = store.person(request.personID)
        let role = team?.slots.first { $0.id == request.slotID }?.role
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                MonoLabel(request.kind == .invitation ? "Приглашение" : "Отклик на вакансию", color: Palette.signal, size: 10.5, weight: .bold)
                Spacer()
                if let role {
                    RoleCode(role: role, style: .vacancy)
                }
            }
            Text(headline(team: team, person: person))
                .font(Typo.headline)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            if !request.message.isEmpty {
                Text("«\(request.message)»")
                    .font(Typo.serif(16))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if request.kind == .application, let person {
                NavigationLink(value: Route.person(person.id)) {
                    linkLabel("Профиль кандидата")
                }
                .buttonStyle(.plain)
            } else if let team {
                NavigationLink(value: Route.team(team.id)) {
                    linkLabel("Открыть команду")
                }
                .buttonStyle(.plain)
            }
            HStack(spacing: 8) {
                Button("Принять") {
                    store.respond(to: request, accept: true)
                }
                .buttonStyle(SignalButtonStyle())
                Button("Отклонить") {
                    store.respond(to: request, accept: false)
                }
                .buttonStyle(OutlineButtonStyle())
            }
        }
        .padding(16)
        .background(Palette.surface)
        .overlay { Rectangle().strokeBorder(Palette.ink, lineWidth: 1.2) }
    }

    private func headline(team: Team?, person: Person?) -> String {
        let teamName = team?.name ?? "Команда"
        if request.kind == .invitation {
            return "«\(teamName)» зовёт вас в команду"
        }
        return "\(person?.name ?? "Участник") хочет в «\(teamName)»"
    }

    private func linkLabel(_ title: String) -> some View {
        HStack(spacing: 6) {
            Text(title.uppercased())
                .font(Typo.mono(11, weight: .semibold))
            Image(systemName: "arrow.right")
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(Palette.ink)
        .contentShape(Rectangle())
    }
}

struct RequestLine: View {
    @EnvironmentObject private var store: AppStore
    let request: JoinRequest

    var body: some View {
        let teamName = store.team(request.teamID)?.name ?? "команда"
        let personName = store.person(request.personID)?.name ?? "Участник"
        let role = store.team(request.teamID)?.slots.first { $0.id == request.slotID }?.role
        HStack(alignment: .top, spacing: 12) {
            statusMark
                .padding(.top, 4)
            VStack(alignment: .leading, spacing: 3) {
                Text(title(teamName: teamName, personName: personName))
                    .font(Typo.subhead.weight(.medium))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                MonoLabel(
                    "\(role?.code ?? "—") · \(request.status.title)",
                    color: request.status == .accepted ? Palette.ink : (request.status == .pending ? Palette.signal : Palette.faint),
                    size: 10
                )
            }
            Spacer()
            MonoLabel(Fmt.numeric(request.createdAt), color: Palette.faint, size: 10)
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) { Hairline() }
        .accessibilityElement(children: .combine)
    }

    private func title(teamName: String, personName: String) -> String {
        switch (request.kind, request.isIncoming) {
        case (.application, false): return "Ваш отклик в «\(teamName)»"
        case (.invitation, false): return "\(personName) — приглашение в «\(teamName)»"
        case (.invitation, true): return "Приглашение от «\(teamName)»"
        case (.application, true): return "\(personName) — отклик в «\(teamName)»"
        }
    }

    @ViewBuilder
    private var statusMark: some View {
        switch request.status {
        case .pending:
            Rectangle()
                .strokeBorder(Palette.signal, style: StrokeStyle(lineWidth: 1.2, dash: [2, 2]))
                .frame(width: 10, height: 10)
        case .accepted:
            Rectangle()
                .fill(Palette.ink)
                .frame(width: 10, height: 10)
        case .declined:
            Rectangle()
                .fill(Palette.line)
                .frame(width: 10, height: 10)
        }
    }
}
