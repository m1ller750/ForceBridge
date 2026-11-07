import SwiftUI

struct TeamEditorView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var challengeID: UUID?
    @State private var field = ""
    @State private var pitch = ""
    @State private var myRole: Role = .mobile
    @State private var vacancies: [VacancyDraft] = []
    @State private var hours = 10
    @State private var format: WorkFormat = .hybrid
    @State private var city = ""
    @State private var prepared = false

    struct VacancyDraft: Identifiable {
        let id = UUID()
        var role: Role
        var note: String = ""
    }

    init(preselectedChallengeID: UUID?) {
        _challengeID = State(initialValue: preselectedChallengeID)
    }

    private var upcomingChallenges: [Challenge] {
        let today = Calendar.current.startOfDay(for: Date())
        return store.sortedChallenges.filter { $0.registrationDeadline >= today }
    }

    private var selectedChallenge: Challenge? {
        store.challenge(challengeID)
    }

    private var isValid: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 && !vacancies.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    preview
                    basics
                    roleSection
                    vacancySection
                    loadSection
                    Button("Опубликовать команду") {
                        publish()
                    }
                    .buttonStyle(.signal)
                    .disabled(!isValid)
                }
                .padding(Metrics.gutter)
                .contentColumn()
            }
            .scrollDismissesKeyboard(.interactively)
            .paperBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .principal) {
                    MonoLabel("Новая команда", color: Palette.ink, weight: .semibold)
                }
            }
        }
        .presentationBackground(Palette.paper)
        .onAppear(perform: prepare)
    }

    // MARK: Секции

    private var preview: some View {
        let states = [true] + vacancies.map { _ in false }
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                MonoLabel("Конструкция", color: Palette.ink, size: 10.5, weight: .semibold)
                Spacer()
                MonoLabel("1 + \(vacancies.count) \(Fmt.plural(vacancies.count, "вакансия", "вакансии", "вакансий"))", size: 10.5)
            }
            TrussGlyph(states: states, lineWidth: 1.4)
                .frame(height: 64)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: vacancies.count)
            HStack(spacing: 5) {
                RoleCode(role: myRole, style: .filled)
                ForEach(vacancies) { vacancy in
                    RoleCode(role: vacancy.role, style: .vacancy)
                }
            }
        }
        .padding(14)
        .background(Palette.surface)
        .overlay { Rectangle().strokeBorder(Palette.ink, lineWidth: 1.2) }
    }

    private var basics: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionTitle(number: "01", title: "Основное")
            FieldBox(label: "Название команды") {
                TextField("Коротко и запоминаемо", text: $name)
            }
            FieldBox(label: "Цель") {
                Menu {
                    Button("Научный проект без события") {
                        challengeID = nil
                    }
                    ForEach(upcomingChallenges) { challenge in
                        Button(challenge.title) {
                            select(challenge)
                        }
                    }
                } label: {
                    HStack {
                        Text(selectedChallenge?.title ?? "Научный проект без события")
                            .lineLimit(1)
                            .foregroundStyle(Palette.ink)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Palette.graphite)
                    }
                    .contentShape(Rectangle())
                }
            }
            if challengeID == nil {
                VStack(alignment: .leading, spacing: 8) {
                    FieldBox(label: "Область исследования") {
                        TextField("Например, Биотех", text: $field)
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(Topics.all, id: \.self) { topic in
                                Chip(title: topic, isOn: field == topic) {
                                    field = topic
                                }
                            }
                        }
                    }
                }
            }
            FieldBox(label: "Идея в двух предложениях", hint: "\(pitch.count)/220") {
                TextField("Какую задачу решаете и чем это интересно", text: $pitch, axis: .vertical)
                    .lineLimit(3...6)
            }
            .onChange(of: pitch) { _, newValue in
                if newValue.count > 220 {
                    pitch = String(newValue.prefix(220))
                }
            }
        }
    }

    private var roleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(number: "02", title: "Ваша роль в команде")
            FlowLayout(spacing: 6, lineSpacing: 6) {
                ForEach(availableOwnRoles) { role in
                    Chip(title: "\(role.code) · \(role.shortTitle)", isOn: myRole == role) {
                        myRole = role
                    }
                }
            }
        }
    }

    private var vacancySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle(number: "03", title: "Вакансии", trailing: "\(vacancies.count)")
            ForEach($vacancies) { $vacancy in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        RoleCode(role: vacancy.role, style: .vacancy)
                        Text(vacancy.role.title)
                            .font(Typo.subhead.weight(.semibold))
                            .foregroundStyle(Palette.ink)
                        Spacer()
                        Button {
                            remove(vacancy.id)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Palette.graphite)
                                .frame(width: 32, height: 32)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Убрать вакансию \(vacancy.role.title)")
                    }
                    TextField("Что именно нужно: стек, задачи", text: $vacancy.note)
                        .font(Typo.footnote)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Palette.surface)
                        .overlay { Rectangle().strokeBorder(Palette.line, lineWidth: 1) }
                }
                .padding(.vertical, 12)
                .overlay(alignment: .bottom) { Hairline() }
            }
            Menu {
                ForEach(Role.allCases) { role in
                    Button("\(role.code) — \(role.title)") {
                        vacancies.append(VacancyDraft(role: role))
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                    Text("ДОБАВИТЬ ВАКАНСИЮ")
                        .font(Typo.mono(12, weight: .bold))
                }
                .foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .overlay {
                    Rectangle().strokeBorder(Palette.ink, style: StrokeStyle(lineWidth: 1.2, dash: [5, 3]))
                }
                .contentShape(Rectangle())
            }
            .padding(.top, 14)
        }
    }

    private var loadSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionTitle(number: "04", title: "Нагрузка и формат")
            HoursRuler(value: $hours)
            FormatPicker(selection: $format)
            if format != .online {
                CityField(city: $city)
            }
        }
    }

    // MARK: Логика

    private var availableOwnRoles: [Role] {
        guard let me = store.me, !me.roles.isEmpty else { return Role.allCases }
        return me.roles
    }

    private func select(_ challenge: Challenge) {
        challengeID = challenge.id
        format = challenge.format
        if let challengeCity = challenge.city, !challengeCity.isEmpty {
            city = challengeCity
        }
    }

    private func remove(_ id: UUID) {
        vacancies.removeAll { $0.id == id }
    }

    private func prepare() {
        guard !prepared else { return }
        prepared = true
        if let me = store.me {
            myRole = me.roles.first ?? .mobile
            hours = me.hoursPerWeek
            format = me.format
            city = me.city
            // Предлагаем недостающие роли — их легко убрать.
            let preference: [Role] = [.ml, .design, .backend, .product, .science, .hardware]
            let missing = preference.filter { !me.roles.contains($0) }
            vacancies = missing.prefix(2).map { VacancyDraft(role: $0) }
        }
        if let challenge = selectedChallenge {
            select(challenge)
        }
    }

    private func publish() {
        guard let me = store.me else { return }
        var slots = [Slot(role: myRole, memberID: me.id)]
        for vacancy in vacancies {
            slots.append(Slot(role: vacancy.role, note: vacancy.note.trimmingCharacters(in: .whitespacesAndNewlines)))
        }
        let trimmedCity = city.trimmingCharacters(in: .whitespacesAndNewlines)
        let researchField = field.trimmingCharacters(in: .whitespacesAndNewlines)
        let team = Team(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            challengeID: challengeID,
            field: challengeID == nil ? researchField : (selectedChallenge?.topics.first ?? ""),
            pitch: pitch.trimmingCharacters(in: .whitespacesAndNewlines),
            slots: slots,
            hoursPerWeek: hours,
            format: format,
            city: format == .online || trimmedCity.isEmpty ? nil : trimmedCity,
            ownerID: me.id,
            createdAt: Date()
        )
        store.createTeam(team)
        dismiss()
    }
}
