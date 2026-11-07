import SwiftUI

// MARK: - Отклик на вакансию

struct ApplySheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let teamID: UUID
    @State private var slotID: UUID
    @State private var message = ""

    init(teamID: UUID, slotID: UUID) {
        self.teamID = teamID
        _slotID = State(initialValue: slotID)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let team = store.team(teamID) {
                    form(team)
                } else {
                    EmptyNote(title: "Команда не найдена", message: "Возможно, её расформировали.")
                        .padding(Metrics.gutter)
                }
            }
            .paperBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .principal) {
                    MonoLabel("Отклик в команду", color: Palette.ink, weight: .semibold)
                }
            }
        }
        .presentationBackground(Palette.paper)
        .onAppear(perform: prefill)
    }

    private func form(_ team: Team) -> some View {
        let slots = store.applicableSlots(in: team)
        let selected = team.slots.first { $0.id == slotID }
        return ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    MonoLabel("Команда")
                    Text(team.name)
                        .font(Typo.display(26, weight: .heavy))
                        .foregroundStyle(Palette.ink)
                    Text(teamSubtitle(team, store: store))
                        .font(Typo.subhead)
                        .foregroundStyle(Palette.graphite)
                }

                if slots.count > 1 {
                    VStack(alignment: .leading, spacing: 8) {
                        MonoLabel("На какую роль")
                        FlowLayout(spacing: 6, lineSpacing: 6) {
                            ForEach(slots) { slot in
                                Chip(title: "\(slot.role.code) · \(slot.role.shortTitle)", isOn: slot.id == slotID) {
                                    slotID = slot.id
                                }
                            }
                        }
                    }
                } else if let selected {
                    VStack(spacing: 0) {
                        Hairline()
                        SpecRow(label: "Роль", value: selected.role.title)
                    }
                }

                MatchPanel(report: store.fit(of: team), title: "Ваше соответствие")

                FieldBox(label: "Сопроводительное письмо", hint: "\(message.count)/280") {
                    TextField("Чем вы будете полезны команде", text: $message, axis: .vertical)
                        .lineLimit(4...8)
                }
                .onChange(of: message) { _, newValue in
                    if newValue.count > 280 {
                        message = String(newValue.prefix(280))
                    }
                }

                Button("Отправить отклик") {
                    send(team)
                }
                .buttonStyle(.signal)
                .disabled(selected?.isOpen != true)

                Text("В прототипе ответы других участников имитируются: решение придёт через несколько секунд.")
                    .font(Typo.footnote)
                    .foregroundStyle(Palette.faint)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Metrics.gutter)
            .contentColumn()
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func send(_ team: Team) {
        guard let slot = team.slots.first(where: { $0.id == slotID }) else { return }
        store.apply(to: team, slot: slot, message: message.trimmingCharacters(in: .whitespacesAndNewlines))
        dismiss()
    }

    private func prefill() {
        guard message.isEmpty,
              let me = store.me,
              let team = store.team(teamID),
              let slot = team.slots.first(where: { $0.id == slotID }) else { return }
        message = "Здравствуйте! Хочу закрыть роль «\(slot.role.shortTitle)». \(me.headline)"
    }
}

// MARK: - Приглашение в команду

struct InviteSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let personID: UUID
    @State private var selectedSlotID: UUID?
    @State private var message = ""

    init(personID: UUID, preselectedSlotID: UUID? = nil) {
        self.personID = personID
        _selectedSlotID = State(initialValue: preselectedSlotID)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let person = store.person(personID) {
                    form(person)
                } else {
                    EmptyNote(title: "Участник не найден", message: "Профиль недоступен.")
                        .padding(Metrics.gutter)
                }
            }
            .paperBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .principal) {
                    MonoLabel("Приглашение", color: Palette.ink, weight: .semibold)
                }
            }
        }
        .presentationBackground(Palette.paper)
        .onAppear(perform: prefill)
    }

    private func form(_ person: Person) -> some View {
        let options = store.invitableSlots(for: person)
        let selected = options.first { $0.slot.id == selectedSlotID }
        return ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top, spacing: 12) {
                    Monogram(initials: person.initials, size: 46)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(person.name)
                            .font(Typo.display(22, weight: .bold))
                            .foregroundStyle(Palette.ink)
                        Text(person.headline)
                            .font(Typo.footnote)
                            .foregroundStyle(Palette.graphite)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if options.isEmpty {
                    EmptyNote(
                        title: "Нет подходящих вакансий",
                        message: "Ни в одной вашей команде нет открытой роли «\(person.roles.map { $0.shortTitle }.joined(separator: ", "))». Соберите команду во вкладке «Команды» и добавьте нужную вакансию."
                    )
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        MonoLabel("Куда пригласить")
                            .padding(.bottom, 6)
                        ForEach(options) { option in
                            optionRow(option, isOn: option.slot.id == selectedSlotID)
                        }
                    }

                    if let selected {
                        MatchPanel(
                            report: Matcher.candidate(person, for: selected.team, challenge: store.challenge(selected.team.challengeID)),
                            title: "Насколько закрывает вакансию"
                        )
                    }

                    FieldBox(label: "Сообщение", hint: "\(message.count)/280") {
                        TextField("Почему именно этот человек", text: $message, axis: .vertical)
                            .lineLimit(3...8)
                    }
                    .onChange(of: message) { _, newValue in
                        if newValue.count > 280 {
                            message = String(newValue.prefix(280))
                        }
                    }

                    Button("Пригласить") {
                        if let selected {
                            store.invite(person, to: selected.team, slot: selected.slot, message: message)
                            dismiss()
                        }
                    }
                    .buttonStyle(.signal)
                    .disabled(selected == nil)
                }
            }
            .padding(Metrics.gutter)
            .contentColumn()
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func optionRow(_ option: SlotOption, isOn: Bool) -> some View {
        Button {
            selectedSlotID = option.slot.id
        } label: {
            HStack(spacing: 12) {
                Rectangle()
                    .fill(isOn ? Palette.signal : Color.clear)
                    .overlay { Rectangle().strokeBorder(Palette.ink, lineWidth: 1.2) }
                    .frame(width: 16, height: 16)
                VStack(alignment: .leading, spacing: 3) {
                    Text(option.team.name)
                        .font(Typo.headline)
                        .foregroundStyle(Palette.ink)
                    Text("\(option.slot.role.code) · \(option.slot.note.isEmpty ? option.slot.role.title : option.slot.note)")
                        .font(Typo.footnote)
                        .foregroundStyle(Palette.graphite)
                        .lineLimit(1)
                }
                Spacer()
                TrussGlyph(states: option.team.states)
                    .frame(width: 48, height: 22)
            }
            .padding(.vertical, 12)
            .overlay(alignment: .bottom) { Hairline() }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func prefill() {
        guard let person = store.person(personID) else { return }
        let options = store.invitableSlots(for: person)
        let isValid = options.contains { $0.slot.id == selectedSlotID }
        if !isValid {
            selectedSlotID = options.first?.slot.id
        }
        if message.isEmpty {
            message = "Здравствуйте, \(person.firstName)! Вы закрываете роль, которой нам не хватает. Присоединяйтесь?"
        }
    }
}
