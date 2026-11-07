import SwiftUI

struct TeamDetailView: View {
    @EnvironmentObject private var store: AppStore
    let teamID: UUID
    @State private var selectedSlotID: UUID?
    @State private var applyTarget: Slot?
    @State private var inviteTarget: InviteTarget?

    struct InviteTarget: Identifiable {
        let personID: UUID
        let slotID: UUID
        var id: String { "\(personID.uuidString)-\(slotID.uuidString)" }
    }

    var body: some View {
        Group {
            if let team = store.team(teamID) {
                content(team)
            } else {
                EmptyNote(title: "Команда не найдена", message: "Возможно, её расформировали.")
                    .padding(Metrics.gutter)
            }
        }
        .paperBackground()
        .detailNavigation("Команда")
        .sheet(item: $applyTarget) { slot in
            ApplySheet(teamID: teamID, slotID: slot.id)
        }
        .sheet(item: $inviteTarget) { target in
            InviteSheet(personID: target.personID, preselectedSlotID: target.slotID)
        }
    }

    private func content(_ team: Team) -> some View {
        let isOwner = store.isOwner(team)
        let isMember = store.isMember(team)
        return ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header(team)
                Text(team.pitch)
                    .font(Typo.serif(19))
                    .foregroundStyle(Palette.ink)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                diagram(team)
                roster(team, isOwner: isOwner)
                specs(team)
                if isOwner {
                    candidatesSection(team)
                } else if !isMember {
                    applySection(team)
                }
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.top, 16)
            .padding(.bottom, 40)
            .contentColumn()
        }
        .scrollIndicators(.hidden)
    }

    // MARK: Шапка

    private func header(_ team: Team) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let challenge = store.challenge(team.challengeID) {
                NavigationLink(value: Route.challenge(challenge.id)) {
                    HStack(spacing: 8) {
                        KindTag(kind: challenge.kind)
                        Text(challenge.title)
                            .font(Typo.footnote.weight(.medium))
                            .foregroundStyle(Palette.ink)
                            .lineLimit(1)
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Palette.graphite)
                    }
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: 6) {
                    Text("RES")
                        .font(Typo.mono(10, weight: .bold))
                        .foregroundStyle(Palette.paper)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Palette.ink)
                    MonoLabel(team.field.isEmpty ? "Научный проект" : "Научный проект · \(team.field)", size: 10)
                }
            }
            Text(team.name)
                .font(Typo.display(32, weight: .heavy))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let owner = store.person(team.ownerID) {
                NavigationLink(value: Route.person(owner.id)) {
                    HStack(spacing: 8) {
                        Monogram(initials: owner.initials, size: 24, emphasized: owner.id == store.me?.id)
                        Text(owner.id == store.me?.id ? "Собираете вы" : "Собирает: \(owner.name)")
                            .font(Typo.subhead)
                            .foregroundStyle(Palette.graphite)
                    }
                }
                .buttonStyle(.plain)
                .disabled(owner.id == store.me?.id)
            }
        }
    }

    // MARK: Схема

    private func diagram(_ team: Team) -> some View {
        let filled = team.slots.count - team.openSlots.count
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                MonoLabel("Схема команды", color: Palette.ink, size: 10.5, weight: .semibold)
                Spacer()
                MonoLabel("Прочность \(filled)/\(team.slots.count) · \(Int((team.integrity * 100).rounded()))%", color: Palette.ink, size: 10.5, weight: .semibold)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            Hairline(color: Palette.lineStrong)
            TrussDiagram(
                slots: team.slots,
                memberInitials: { slot in store.person(slot.memberID)?.initials },
                selection: $selectedSlotID
            )
            .frame(height: 150)
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
            .id(team.slots.map { $0.memberID?.uuidString ?? "open" }.joined())
            Hairline(color: Palette.lineStrong)
            selectedSlotInfo(team)
                .padding(12)
        }
        .background(Palette.surface)
        .overlay { Rectangle().strokeBorder(Palette.ink, lineWidth: 1.2) }
    }

    @ViewBuilder
    private func selectedSlotInfo(_ team: Team) -> some View {
        if let slotID = selectedSlotID, let slot = team.slots.first(where: { $0.id == slotID }) {
            if let member = store.person(slot.memberID) {
                NavigationLink(value: Route.person(member.id)) {
                    HStack(spacing: 10) {
                        RoleCode(role: slot.role, style: .filled)
                        Text(member.name)
                            .font(Typo.subhead.weight(.semibold))
                            .foregroundStyle(Palette.ink)
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Palette.ink)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        RoleCode(role: slot.role, style: .vacancy)
                        Text("Вакансия: \(slot.role.title)")
                            .font(Typo.subhead.weight(.semibold))
                            .foregroundStyle(Palette.ink)
                    }
                    if !slot.note.isEmpty {
                        Text(slot.note)
                            .font(Typo.footnote)
                            .foregroundStyle(Palette.graphite)
                    }
                }
            }
        } else {
            MonoLabel("Нажмите на панель, чтобы увидеть роль", color: Palette.faint, size: 10)
        }
    }

    // MARK: Состав

    private func roster(_ team: Team, isOwner: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle(number: "01", title: "Состав", trailing: "\(team.slots.count) \(Fmt.plural(team.slots.count, "роль", "роли", "ролей"))")
            ForEach(team.slots) { slot in
                slotRow(slot, team: team, isOwner: isOwner)
            }
        }
    }

    @ViewBuilder
    private func slotRow(_ slot: Slot, team: Team, isOwner: Bool) -> some View {
        if let member = store.person(slot.memberID) {
            NavigationLink(value: Route.person(member.id)) {
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        RoleCode(role: slot.role, style: .filled)
                            .frame(width: 40, alignment: .leading)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(member.id == store.me?.id ? "\(member.name) (вы)" : member.name)
                                .font(Typo.subhead.weight(.semibold))
                                .foregroundStyle(Palette.ink)
                            Text(slot.role.title)
                                .font(Typo.footnote)
                                .foregroundStyle(Palette.graphite)
                        }
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Palette.faint)
                    }
                    .padding(.vertical, 13)
                    Hairline()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    RoleCode(role: slot.role, style: .vacancy)
                        .frame(width: 40, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Вакансия · \(slot.role.shortTitle)")
                            .font(Typo.subhead.weight(.semibold))
                            .foregroundStyle(Palette.signal)
                        Text(slot.note.isEmpty ? slot.role.title : slot.note)
                            .font(Typo.footnote)
                            .foregroundStyle(Palette.graphite)
                    }
                    Spacer()
                    if !isOwner && !store.isMember(team) {
                        vacancyAction(slot, team: team)
                    }
                }
                .padding(.vertical, 13)
                Hairline()
            }
        }
    }

    @ViewBuilder
    private func vacancyAction(_ slot: Slot, team: Team) -> some View {
        if let request = store.latestRequest(teamID: team.id, personID: store.me?.id ?? UUID()), request.status == .pending {
            MonoLabel("Отклик отправлен", color: Palette.graphite, size: 9.5)
        } else {
            Button("Откликнуться") {
                applyTarget = slot
            }
            .buttonStyle(.outlineCompact)
        }
    }

    // MARK: Параметры

    private func specs(_ team: Team) -> some View {
        VStack(spacing: 0) {
            SectionTitle(number: "02", title: "Параметры")
            SpecRow(label: "Нагрузка", value: "\(team.hoursPerWeek) ч в неделю")
            SpecRow(label: "Формат", value: placeText(team))
            SpecRow(label: "Опубликована", value: Fmt.dayMonth(team.createdAt))
            if let challenge = store.challenge(team.challengeID) {
                SpecRow(
                    label: "Дедлайн",
                    value: "Регистрация до \(Fmt.dayMonth(challenge.registrationDeadline))",
                    accent: Fmt.daysUntil(challenge.registrationDeadline) <= 7
                )
            }
        }
    }

    private func placeText(_ team: Team) -> String {
        if team.format == .online { return "Онлайн" }
        guard let city = team.city, !city.isEmpty else { return team.format.title }
        return team.format.title + ", " + city
    }

    // MARK: Отклик (чужая команда)

    @ViewBuilder
    private func applySection(_ team: Team) -> some View {
        let report = store.fit(of: team)
        let request = store.latestRequest(teamID: team.id, personID: store.me?.id ?? UUID())
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(number: "03", title: "Ваше соответствие")
            MatchPanel(report: report, title: "Насколько вы закрываете вакансии")
            if let request {
                RequestStatusLine(status: request.status, pendingText: "Отклик отправлен — ждём ответа команды")
            }
            if team.openSlots.isEmpty {
                EmptyNote(title: "Состав собран", message: "Свободных ролей нет — загляните в похожие команды.")
            } else if request?.status != .pending && request?.status != .accepted {
                Button("Откликнуться") {
                    if let first = store.applicableSlots(in: team).first {
                        applyTarget = first
                    }
                }
                .buttonStyle(.signal)
            }
        }
    }

    // MARK: Кандидаты (моя команда)

    @ViewBuilder
    private func candidatesSection(_ team: Team) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle(number: "03", title: "Кандидаты на вакансии")
            if team.openSlots.isEmpty {
                EmptyNote(title: "Конструкция собрана", message: "Все роли закрыты. Удачи на старте!")
                    .padding(.top, 14)
            } else {
                ForEach(team.openSlots) { slot in
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 8) {
                            RoleCode(role: slot.role, style: .vacancy)
                            MonoLabel(slot.note.isEmpty ? slot.role.title : slot.note, color: Palette.ink, size: 10.5, weight: .semibold)
                        }
                        .padding(.top, 18)
                        .padding(.bottom, 4)
                        let candidates = store.candidates(for: team, role: slot.role, limit: 3)
                        if candidates.isEmpty {
                            Text("Подходящих людей пока нет.")
                                .font(Typo.footnote)
                                .foregroundStyle(Palette.graphite)
                                .padding(.vertical, 10)
                        }
                        ForEach(candidates) { ranked in
                            candidateRow(ranked, slot: slot, team: team)
                        }
                    }
                }
            }
        }
    }

    private func candidateRow(_ ranked: RankedPerson, slot: Slot, team: Team) -> some View {
        let request = store.latestRequest(teamID: team.id, personID: ranked.person.id)
        return HStack(alignment: .center, spacing: 10) {
            NavigationLink(value: Route.person(ranked.person.id)) {
                PersonRow(person: ranked.person, score: ranked.report.total, note: ranked.report.reasons.first)
            }
            .buttonStyle(.plain)
            VStack {
                if let request, request.status != .declined {
                    MonoLabel(request.status == .pending ? "Ждём" : "В команде", color: Palette.graphite, size: 9.5)
                } else {
                    Button("Позвать") {
                        inviteTarget = InviteTarget(personID: ranked.person.id, slotID: slot.id)
                    }
                    .buttonStyle(.outlineCompact)
                }
            }
            .frame(width: 84)
        }
    }
}

/// Строка статуса запроса.
struct RequestStatusLine: View {
    let status: RequestStatus
    var pendingText: String = "Ожидает ответа"

    var body: some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(text)
                .font(Typo.mono(11.5, weight: .semibold))
                .foregroundStyle(Palette.ink)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay { Rectangle().strokeBorder(Palette.lineStrong, lineWidth: 1) }
    }

    private var text: String {
        switch status {
        case .pending: return pendingText
        case .accepted: return "Принят — вы в команде"
        case .declined: return "Отклонён"
        }
    }

    private var color: Color {
        switch status {
        case .pending: return Palette.signal
        case .accepted: return Palette.ink
        case .declined: return Palette.faint
        }
    }
}
