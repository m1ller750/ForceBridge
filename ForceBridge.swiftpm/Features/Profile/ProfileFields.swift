import SwiftUI

/// Черновик профиля — общий для онбординга и редактора.
struct ProfileDraft {
    var name = ""
    var city = ""
    var affiliation = ""
    var headline = ""
    var roles: [Role] = []
    var skills: [String] = []
    var interests: [String] = []
    var hours = 10
    var format: WorkFormat = .hybrid
    var lookingForTeam = true
    var track: [String] = []

    init() {}

    init(person: Person) {
        name = person.name
        city = person.city
        affiliation = person.affiliation
        headline = person.headline
        roles = person.roles
        skills = person.skills
        interests = person.interests
        hours = person.hoursPerWeek
        format = person.format
        lookingForTeam = person.isLookingForTeam
        track = person.track
    }

    func makePerson(id: UUID = UUID()) -> Person {
        Person(
            id: id,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            city: city.trimmingCharacters(in: .whitespacesAndNewlines),
            affiliation: affiliation.trimmingCharacters(in: .whitespacesAndNewlines),
            headline: headline.trimmingCharacters(in: .whitespacesAndNewlines),
            roles: roles,
            skills: skills,
            interests: interests,
            hoursPerWeek: hours,
            format: format,
            track: track,
            isLookingForTeam: lookingForTeam
        )
    }

    var isIdentityValid: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
            && !city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var suggestedSkills: [String] {
        var result: [String] = []
        for role in roles {
            for skill in role.suggestedSkills where !result.contains(skill) {
                result.append(skill)
            }
        }
        return result
    }
}

// MARK: - Роли

struct RolePicker: View {
    @Binding var selection: [Role]
    var limit: Int = 3

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 148), spacing: 8)], spacing: 8) {
            ForEach(Role.allCases) { role in
                RoleTile(role: role, order: selection.firstIndex(of: role)) {
                    toggle(role)
                }
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func toggle(_ role: Role) {
        if let index = selection.firstIndex(of: role) {
            selection.remove(at: index)
        } else if selection.count < limit {
            selection.append(role)
        }
    }
}

struct RoleTile: View {
    let role: Role
    let order: Int?
    let action: () -> Void

    var body: some View {
        let isOn = order != nil
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    Text(role.code)
                        .font(Typo.display(22, weight: .heavy))
                    Spacer(minLength: 4)
                    if let order {
                        Text("\(order + 1)")
                            .font(Typo.mono(11, weight: .bold))
                            .foregroundStyle(Palette.onSignal)
                            .frame(width: 20, height: 20)
                            .background(Palette.signal)
                    }
                }
                Text(role.title)
                    .font(.system(size: 13, weight: .medium))
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(isOn ? Palette.paper : Palette.ink)
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
            .background(isOn ? Palette.ink : Palette.surface)
            .overlay {
                Rectangle().strokeBorder(isOn ? Palette.ink : Palette.lineStrong, lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(role.title)
        .accessibilityValue(order.map { "Выбрано, приоритет \($0 + 1)" } ?? "Не выбрано")
    }
}

// MARK: - Темы и навыки

struct TopicPicker: View {
    @Binding var selection: [String]
    var options: [String] = Topics.all

    var body: some View {
        FlowLayout(spacing: 6, lineSpacing: 6) {
            ForEach(options, id: \.self) { topic in
                Chip(title: topic, isOn: selection.contains(topic)) {
                    toggle(topic)
                }
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func toggle(_ topic: String) {
        if let index = selection.firstIndex(of: topic) {
            selection.remove(at: index)
        } else {
            selection.append(topic)
        }
    }
}

struct SkillEditor: View {
    @Binding var skills: [String]
    var suggestions: [String]
    @State private var input = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                TextField("Например, PyTorch", text: $input)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .onSubmit(add)
                    .font(Typo.body)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 11)
                    .background(Palette.surface)
                    .overlay { Rectangle().strokeBorder(Palette.lineStrong, lineWidth: 1) }
                Button("Добавить", action: add)
                    .buttonStyle(.outlineCompact)
                    .disabled(trimmedInput.isEmpty)
            }

            if !skills.isEmpty {
                FlowLayout(spacing: 6, lineSpacing: 6) {
                    ForEach(skills, id: \.self) { skill in
                        Button {
                            skills.removeAll { $0 == skill }
                        } label: {
                            HStack(spacing: 6) {
                                Text(skill)
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            .font(Typo.mono(11.5, weight: .medium))
                            .foregroundStyle(Palette.paper)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Palette.ink)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Удалить навык \(skill)")
                    }
                }
            }

            let rest = suggestions.filter { !skills.contains($0) }
            if !rest.isEmpty {
                MonoLabel("Подсказки по вашим ролям", color: Palette.faint, size: 10)
                FlowLayout(spacing: 6, lineSpacing: 6) {
                    ForEach(rest, id: \.self) { suggestion in
                        Button {
                            skills.append(suggestion)
                        } label: {
                            Text("+ \(suggestion)")
                                .font(Typo.mono(11.5))
                                .foregroundStyle(Palette.ink)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .overlay {
                                    Rectangle().strokeBorder(Palette.lineStrong, style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var trimmedInput: String {
        input.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func add() {
        let value = trimmedInput
        input = ""
        guard !value.isEmpty, !skills.contains(value) else { return }
        skills.append(value)
    }
}

// MARK: - Нагрузка и формат

/// Линейка-слайдер для часов в неделю.
struct HoursRuler: View {
    @Binding var value: Int
    var range: ClosedRange<Int> = 2...40

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(value)")
                    .font(Typo.display(44, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink)
                Text("ч/нед")
                    .font(Typo.mono(13, weight: .semibold))
                    .foregroundStyle(Palette.graphite)
                Spacer()
                Text(caption)
                    .font(Typo.footnote)
                    .foregroundStyle(Palette.graphite)
                    .multilineTextAlignment(.trailing)
            }

            GeometryReader { proxy in
                let width = max(proxy.size.width, 1)
                let span = CGFloat(range.upperBound - range.lowerBound)
                let x = CGFloat(value - range.lowerBound) / span * width
                ZStack(alignment: .bottomLeading) {
                    Canvas { context, size in
                        var path = Path()
                        for step in range.lowerBound...range.upperBound {
                            let px = CGFloat(step - range.lowerBound) / span * (size.width - 1) + 0.5
                            let tick: CGFloat = step % 5 == 0 ? size.height * 0.7 : size.height * 0.35
                            path.move(to: CGPoint(x: px, y: size.height))
                            path.addLine(to: CGPoint(x: px, y: size.height - tick))
                        }
                        context.stroke(path, with: .color(Palette.lineStrong), lineWidth: 1)
                    }
                    Rectangle()
                        .fill(Palette.ink)
                        .frame(width: max(x, 0), height: 3)
                    Rectangle()
                        .fill(Palette.signal)
                        .frame(width: 3, height: proxy.size.height)
                        .offset(x: min(max(x - 1.5, 0), width - 3))
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            let ratio = min(max(gesture.location.x / width, 0), 1)
                            let next = range.lowerBound + Int((ratio * span).rounded())
                            if next != value {
                                value = next
                            }
                        }
                )
            }
            .frame(height: 46)

            HStack {
                MonoLabel("\(range.lowerBound) ч", color: Palette.faint, size: 10)
                Spacer()
                MonoLabel("20 ч", color: Palette.faint, size: 10)
                Spacer()
                MonoLabel("\(range.upperBound) ч", color: Palette.faint, size: 10)
            }
        }
        .sensoryFeedback(.selection, trigger: value)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Часов в неделю")
        .accessibilityValue("\(value)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                value = min(range.upperBound, value + 1)
            case .decrement:
                value = max(range.lowerBound, value - 1)
            @unknown default:
                break
            }
        }
    }

    private var caption: String {
        switch value {
        case ..<6: return "Пара вечеров"
        case 6..<12: return "Ровный темп"
        case 12..<20: return "Серьёзная вовлечённость"
        default: return "Почти работа"
        }
    }
}

struct FormatPicker: View {
    @Binding var selection: WorkFormat

    var body: some View {
        HStack(spacing: 0) {
            ForEach(WorkFormat.allCases) { format in
                let isOn = selection == format
                Button {
                    selection = format
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(format.title)
                            .font(.system(size: 15, weight: .semibold))
                        Text(detail(format))
                            .font(.system(size: 11))
                            .opacity(0.72)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(12)
                    .foregroundStyle(isOn ? Palette.paper : Palette.ink)
                    .background(isOn ? Palette.ink : Palette.surface)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? .isSelected : [])
                if format != WorkFormat.allCases.last {
                    Hairline(color: Palette.lineStrong, vertical: true)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .overlay { Rectangle().strokeBorder(Palette.lineStrong, lineWidth: 1) }
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func detail(_ format: WorkFormat) -> String {
        switch format {
        case .online: return "Только удалённо"
        case .offline: return "Встречи вживую"
        case .hybrid: return "Как удобно команде"
        }
    }
}

struct CityField: View {
    @Binding var city: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            FieldBox(label: "Город") {
                TextField("Например, Казань", text: $city)
                    .textContentType(.addressCity)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Topics.cities, id: \.self) { option in
                        Chip(title: option, isOn: Matcher.sameCity(option, city)) {
                            city = option
                        }
                    }
                }
            }
        }
    }
}

/// Поля «кто вы» — общий блок для онбординга и редактора.
struct IdentityFields: View {
    @Binding var draft: ProfileDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            FieldBox(label: "Имя и фамилия") {
                TextField("Как к вам обращаться", text: $draft.name)
                    .textContentType(.name)
            }
            CityField(city: $draft.city)
            FieldBox(label: "Вуз, школа или компания") {
                TextField("Например, ТГУ, физфак", text: $draft.affiliation)
                    .textContentType(.organizationName)
            }
            FieldBox(label: "Одной строкой о себе", hint: "\(draft.headline.count)/90") {
                TextField("Чем вы сильны и что ищете", text: $draft.headline, axis: .vertical)
                    .lineLimit(2...4)
            }
            .onChange(of: draft.headline) { _, newValue in
                if newValue.count > 90 {
                    draft.headline = String(newValue.prefix(90))
                }
            }
        }
    }
}
