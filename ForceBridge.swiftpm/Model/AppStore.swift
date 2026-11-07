import SwiftUI

struct Toast: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
}

struct RankedPerson: Identifiable {
    let person: Person
    let report: MatchReport
    var id: UUID { person.id }
}

struct RankedTeam: Identifiable {
    let team: Team
    let report: MatchReport
    var id: UUID { team.id }
}

/// Конкретная вакансия конкретной команды.
struct SlotOption: Identifiable, Hashable {
    let team: Team
    let slot: Slot
    var id: UUID { slot.id }
}

/// Единое хранилище состояния. Данные лежат локально в JSON —
/// прототип работает без сервера, а ответы других участников имитируются.
/// Все изменения происходят на главном потоке: из интерфейса и из задач `@MainActor`.
final class AppStore: ObservableObject {
    @Published private(set) var me: Person?
    @Published private(set) var people: [Person] = []
    @Published private(set) var challenges: [Challenge] = []
    @Published private(set) var teams: [Team] = []
    @Published private(set) var requests: [JoinRequest] = []
    @Published private(set) var savedChallengeIDs: Set<UUID> = []
    @Published var toast: Toast?

    private let storageURL: URL
    private static let schemaVersion = 1

    init() {
        let directory = (try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? FileManager.default.temporaryDirectory
        storageURL = directory.appendingPathComponent("forcebridge-state.json")
        if !load() {
            seed()
        }
    }

    // MARK: - Поиск

    func person(_ id: UUID?) -> Person? {
        guard let id else { return nil }
        if let me, me.id == id { return me }
        return people.first { $0.id == id }
    }

    func challenge(_ id: UUID?) -> Challenge? {
        guard let id else { return nil }
        return challenges.first { $0.id == id }
    }

    func team(_ id: UUID?) -> Team? {
        guard let id else { return nil }
        return teams.first { $0.id == id }
    }

    var sortedChallenges: [Challenge] {
        challenges.sorted { $0.startDate < $1.startDate }
    }

    func teams(for challenge: Challenge) -> [Team] {
        teams.filter { $0.challengeID == challenge.id }
    }

    func recruitingTeamsCount(for challenge: Challenge) -> Int {
        teams(for: challenge).filter { !$0.openSlots.isEmpty }.count
    }

    var myTeams: [Team] {
        guard let me else { return [] }
        return teams.filter { $0.ownerID == me.id || $0.memberIDs.contains(me.id) }
    }

    var ownedTeams: [Team] {
        guard let me else { return [] }
        return teams.filter { $0.ownerID == me.id }
    }

    func isOwner(_ team: Team) -> Bool {
        guard let me else { return false }
        return team.ownerID == me.id
    }

    func isMember(_ team: Team) -> Bool {
        guard let me else { return false }
        return team.memberIDs.contains(me.id)
    }

    func teammates(of personID: UUID) -> Set<UUID> {
        var result: Set<UUID> = []
        for team in teams where team.memberIDs.contains(personID) {
            for id in team.memberIDs where id != personID {
                result.insert(id)
            }
        }
        return result
    }

    // MARK: - Подбор

    func match(for person: Person) -> MatchReport {
        guard let me else { return .empty }
        return Matcher.person(person, for: me)
    }

    func fit(of team: Team) -> MatchReport {
        guard let me else { return .empty }
        return Matcher.candidate(me, for: team, challenge: challenge(team.challengeID))
    }

    var rankedPeople: [RankedPerson] {
        guard let me else { return [] }
        return people
            .map { RankedPerson(person: $0, report: Matcher.person($0, for: me)) }
            .sorted { $0.report.total > $1.report.total }
    }

    var rankedOpenTeams: [RankedTeam] {
        guard let me else { return [] }
        let candidates = teams.filter { (team: Team) -> Bool in
            !team.openSlots.isEmpty && team.ownerID != me.id && !team.memberIDs.contains(me.id)
        }
        return candidates
            .map { RankedTeam(team: $0, report: Matcher.candidate(me, for: $0, challenge: challenge($0.challengeID))) }
            .sorted { $0.report.total > $1.report.total }
    }

    /// Лучшие кандидаты на вакансии команды (или на конкретную роль).
    func candidates(for team: Team, role: Role? = nil, limit: Int = 5) -> [RankedPerson] {
        let target = challenge(team.challengeID)
        let pool = people.filter { (person: Person) -> Bool in
            if team.memberIDs.contains(person.id) { return false }
            if let role { return person.roles.contains(role) }
            return person.roles.contains { team.openRoles.contains($0) }
        }
        let ranked = pool
            .map { RankedPerson(person: $0, report: Matcher.candidate($0, for: team, challenge: target)) }
            .sorted { $0.report.total > $1.report.total }
        return Array(ranked.prefix(limit))
    }

    /// Открытые вакансии моих команд, которые человек может закрыть.
    func invitableSlots(for person: Person) -> [SlotOption] {
        var result: [SlotOption] = []
        for team in ownedTeams where !team.memberIDs.contains(person.id) {
            for slot in team.openSlots where person.roles.contains(slot.role) {
                result.append(SlotOption(team: team, slot: slot))
            }
        }
        return result
    }

    /// Есть ли неотвеченное приглашение этого человека в мои команды.
    func hasPendingInvitation(for person: Person) -> Bool {
        requests.contains { $0.kind == .invitation && !$0.isIncoming && $0.personID == person.id && $0.status == .pending }
    }

    /// Вакансии команды, на которые может откликнуться пользователь.
    func applicableSlots(in team: Team) -> [Slot] {
        guard let me else { return [] }
        let matching = team.openSlots.filter { me.roles.contains($0.role) }
        return matching.isEmpty ? team.openSlots : matching
    }

    // MARK: - Запросы

    var incomingPending: [JoinRequest] {
        requests.filter { $0.isIncoming && $0.status == .pending }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var incomingResolved: [JoinRequest] {
        requests.filter { $0.isIncoming && $0.status != .pending }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var outgoing: [JoinRequest] {
        requests.filter { !$0.isIncoming }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func latestRequest(teamID: UUID, personID: UUID) -> JoinRequest? {
        requests.last { $0.teamID == teamID && $0.personID == personID }
    }

    // MARK: - Действия

    func completeOnboarding(with profile: Person) {
        me = profile
        persist()
        after(seconds: 2.5) { store in
            store.createWelcomeInvitation()
        }
    }

    func updateProfile(_ profile: Person) {
        me = profile
        persist()
    }

    func isSaved(_ challenge: Challenge) -> Bool {
        savedChallengeIDs.contains(challenge.id)
    }

    func toggleSaved(_ challenge: Challenge) {
        if savedChallengeIDs.contains(challenge.id) {
            savedChallengeIDs.remove(challenge.id)
        } else {
            savedChallengeIDs.insert(challenge.id)
        }
        persist()
    }

    func addChallenge(_ challenge: Challenge) {
        challenges.append(challenge)
        persist()
        showToast(title: "Вызов добавлен", message: challenge.title)
    }

    func createTeam(_ team: Team) {
        teams.insert(team, at: 0)
        persist()
        showToast(title: "Команда опубликована", message: "«\(team.name)» видна участникам. Ищем кандидатов на вакансии.")
        let teamID = team.id
        after(seconds: 6) { store in
            store.createIncomingApplication(for: teamID)
        }
    }

    func apply(to team: Team, slot: Slot, message: String) {
        guard let me else { return }
        let request = JoinRequest(
            kind: .application, teamID: team.id, slotID: slot.id, personID: me.id,
            message: message, status: .pending, createdAt: Date(), isIncoming: false
        )
        requests.append(request)
        persist()
        let score = Matcher.candidate(me, for: team, challenge: challenge(team.challengeID)).total
        let requestID = request.id
        after(seconds: 4) { store in
            store.resolve(requestID, accept: score >= 45)
        }
    }

    func invite(_ person: Person, to team: Team, slot: Slot, message: String) {
        let request = JoinRequest(
            kind: .invitation, teamID: team.id, slotID: slot.id, personID: person.id,
            message: message, status: .pending, createdAt: Date(), isIncoming: false
        )
        requests.append(request)
        persist()
        let score = Matcher.candidate(person, for: team, challenge: challenge(team.challengeID)).total
        let accept = person.isLookingForTeam ? score >= 40 : score >= 70
        let requestID = request.id
        after(seconds: 3.5) { store in
            store.resolve(requestID, accept: accept)
        }
    }

    /// Ответ пользователя на входящий запрос.
    func respond(to request: JoinRequest, accept: Bool) {
        resolve(request.id, accept: accept)
    }

    func setLookingForTeam(_ value: Bool) {
        guard var profile = me else { return }
        profile.isLookingForTeam = value
        me = profile
        persist()
    }

    func resetAll() {
        try? FileManager.default.removeItem(at: storageURL)
        toast = nil
        seed()
    }

    func showToast(title: String, message: String) {
        let next = Toast(title: title, message: message)
        toast = next
        let nextID = next.id
        after(seconds: 3.4) { store in
            if store.toast?.id == nextID {
                store.toast = nil
            }
        }
    }

    // MARK: - Внутреннее

    private func after(seconds: Double, perform action: @escaping (AppStore) -> Void) {
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard let self else { return }
            action(self)
        }
    }

    private func resolve(_ requestID: UUID, accept: Bool) {
        guard let index = requests.firstIndex(where: { $0.id == requestID }),
              requests[index].status == .pending else { return }
        var request = requests[index]
        var accepted = accept
        if accepted {
            accepted = fill(teamID: request.teamID, slotID: request.slotID, with: request.personID)
        }
        request.status = accepted ? .accepted : .declined
        requests[index] = request
        persist()
        announce(request)
    }

    private func announce(_ request: JoinRequest) {
        let teamName = team(request.teamID)?.name ?? "команда"
        let personName = person(request.personID)?.name ?? "Участник"
        let accepted = request.status == .accepted
        switch (request.kind, request.isIncoming) {
        case (.application, false):
            if accepted {
                showToast(title: "Вы в команде «\(teamName)»", message: "Роль закреплена за вами — конструкция стала прочнее.")
            } else {
                showToast(title: "«\(teamName)»: отказ", message: "Команда выбрала другого кандидата. Загляните в похожие команды.")
            }
        case (.invitation, false):
            if accepted {
                showToast(title: "\(personName) — в «\(teamName)»", message: "Приглашение принято, вакансия закрыта.")
            } else {
                showToast(title: "Приглашение отклонено", message: "\(personName) пока не может присоединиться к «\(teamName)».")
            }
        case (.invitation, true):
            if accepted {
                showToast(title: "Вы в команде «\(teamName)»", message: "Команда получила ваше согласие.")
            }
        case (.application, true):
            if accepted {
                showToast(title: "\(personName) — в «\(teamName)»", message: "Вакансия закрыта.")
            }
        }
    }

    /// Закрепляет участника за позицией. Если позиция уже занята — ищет свободную с той же ролью.
    private func fill(teamID: UUID, slotID: UUID, with personID: UUID) -> Bool {
        guard let teamIndex = teams.firstIndex(where: { $0.id == teamID }) else { return false }
        if teams[teamIndex].memberIDs.contains(personID) { return true }
        if let slotIndex = teams[teamIndex].slots.firstIndex(where: { $0.id == slotID && $0.isOpen }) {
            teams[teamIndex].slots[slotIndex].memberID = personID
            return true
        }
        if let role = teams[teamIndex].slots.first(where: { $0.id == slotID })?.role,
           let slotIndex = teams[teamIndex].slots.firstIndex(where: { $0.isOpen && $0.role == role }) {
            teams[teamIndex].slots[slotIndex].memberID = personID
            return true
        }
        return false
    }

    private func createWelcomeInvitation() {
        guard let me else { return }
        var best: (team: Team, slot: Slot, score: Int)?
        for team in teams where team.ownerID != me.id && !team.memberIDs.contains(me.id) {
            for slot in team.openSlots where me.roles.contains(slot.role) {
                let score = Matcher.candidate(me, for: team, challenge: challenge(team.challengeID)).total
                if let current = best, current.score >= score { continue }
                best = (team: team, slot: slot, score: score)
            }
        }
        guard let pick = best else { return }
        let ownerName = person(pick.team.ownerID)?.firstName ?? "Команда"
        let message = "Привет! Нам не хватает узла «\(pick.slot.role.shortTitle)», и по профилю вы закрываете его лучше всех. Присоединяйтесь к «\(pick.team.name)»."
        let request = JoinRequest(
            kind: .invitation, teamID: pick.team.id, slotID: pick.slot.id, personID: me.id,
            message: message, status: .pending, createdAt: Date(), isIncoming: true
        )
        requests.append(request)
        persist()
        showToast(title: "Новое приглашение", message: "\(ownerName) зовёт вас в «\(pick.team.name)»")
    }

    private func createIncomingApplication(for teamID: UUID) {
        guard let team = team(teamID), let me else { return }
        let target = challenge(team.challengeID)
        var best: (person: Person, slot: Slot, score: Int)?
        for slot in team.openSlots {
            for candidate in people where candidate.roles.contains(slot.role) && !team.memberIDs.contains(candidate.id) && candidate.id != me.id {
                let alreadyAsked = requests.contains { $0.teamID == team.id && $0.personID == candidate.id }
                if alreadyAsked { continue }
                let bonus = candidate.isLookingForTeam ? 10 : 0
                let score = Matcher.candidate(candidate, for: team, challenge: target).total + bonus
                if let current = best, current.score >= score { continue }
                best = (person: candidate, slot: slot, score: score)
            }
        }
        guard let pick = best else { return }
        let message = "Здравствуйте! Хочу закрыть у вас роль «\(pick.slot.role.shortTitle)». \(pick.person.headline)"
        let request = JoinRequest(
            kind: .application, teamID: team.id, slotID: pick.slot.id, personID: pick.person.id,
            message: message, status: .pending, createdAt: Date(), isIncoming: true
        )
        requests.append(request)
        persist()
        showToast(title: "Новый отклик", message: "\(pick.person.name) хочет в «\(team.name)»")
    }

    // MARK: - Хранение

    private func seed() {
        let dataset = SeedData.make()
        me = nil
        people = dataset.people
        challenges = dataset.challenges
        teams = dataset.teams
        requests = []
        savedChallengeIDs = []
    }

    private func load() -> Bool {
        guard let data = try? Data(contentsOf: storageURL),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data),
              snapshot.version == Self.schemaVersion,
              snapshot.me != nil else {
            return false
        }
        me = snapshot.me
        people = snapshot.people
        challenges = snapshot.challenges
        teams = snapshot.teams
        requests = snapshot.requests
        savedChallengeIDs = snapshot.savedChallengeIDs
        return true
    }

    private func persist() {
        let snapshot = Snapshot(
            version: Self.schemaVersion,
            me: me,
            people: people,
            challenges: challenges,
            teams: teams,
            requests: requests,
            savedChallengeIDs: savedChallengeIDs
        )
        do {
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            print("ForceBridge: не удалось сохранить состояние — \(error)")
        }
    }
}
