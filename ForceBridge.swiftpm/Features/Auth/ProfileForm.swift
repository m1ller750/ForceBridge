import SwiftUI

/// Черновик профиля — общий для первичного заполнения и редактора.
struct ProfileDraft {
    var fullName = ""
    var ageText = ""
    var city = ""
    var occupation = ""
    var about = ""
    var skills: [String] = []
    var projects: [String] = []
    var achievements: [String] = []
    var messenger: Messenger = .telegram
    var contact = ""

    init() {}

    init(profile: Profile) {
        fullName = profile.fullName
        ageText = profile.age.map { String($0) } ?? ""
        city = profile.city
        occupation = profile.occupation
        about = profile.about
        skills = profile.skills
        projects = profile.projects
        achievements = profile.achievements
        messenger = profile.messenger
        contact = profile.contact
    }

    var age: Int? {
        Int(ageText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// Что ещё нужно заполнить. nil — профиль готов.
    var validationMessage: String? {
        if fullName.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 {
            return "Укажите имя и фамилию."
        }
        guard let age, (10...99).contains(age) else {
            return "Укажите возраст числом от 10 до 99."
        }
        if city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Укажите город."
        }
        if occupation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Напишите, чем вы занимаетесь."
        }
        if contact.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 {
            return "Укажите контакт для связи: \(messenger.title), \(messenger.placeholder)."
        }
        return nil
    }

    func applied(to base: Profile) -> Profile {
        var profile = base
        profile.fullName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.age = age
        profile.city = city.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.occupation = occupation.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.about = about.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.skills = skills
        profile.projects = projects
        profile.achievements = achievements
        profile.messenger = messenger
        profile.contact = contact.trimmingCharacters(in: .whitespacesAndNewlines)
        return profile
    }
}

/// Поля профиля. Обязательные: имя, возраст, город, чем занимается, мессенджер и контакт.
struct ProfileForm: View {
    @Binding var draft: ProfileDraft

    private let skillSuggestions = [
        "Swift", "Python", "C++", "Figma", "ML", "Анализ данных", "Робототехника",
        "Биология", "Химия", "Физика", "Математика", "Питч", "Тексты", "3D", "Электроника"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 16) {
                SectionTitle(number: "A", title: "Кто вы", trailing: "обязательно")
                FieldBox(label: "Имя и фамилия") {
                    TextField("Как к вам обращаться", text: $draft.fullName)
                        .textContentType(.name)
                }
                FieldBox(label: "Возраст", hint: "полных лет") {
                    TextField("Например, 19", text: $draft.ageText)
                        .keyboardType(.numberPad)
                }
                CityField(city: $draft.city)
                FieldBox(label: "Чем занимаетесь") {
                    TextField("Студент 2 курса, учу ML и делаю роботов", text: $draft.occupation, axis: .vertical)
                        .lineLimit(1...3)
                }
                FieldBox(label: "О себе", hint: "\(draft.about.count)/1500") {
                    TextField("Что умеете, что ищете, чем горите", text: $draft.about, axis: .vertical)
                        .lineLimit(3...8)
                }
                .onChange(of: draft.about) { _, newValue in
                    if newValue.count > 1500 {
                        draft.about = String(newValue.prefix(1500))
                    }
                }
            }

            VStack(alignment: .leading, spacing: 14) {
                SectionTitle(number: "B", title: "Связь", trailing: "обязательно")
                MessengerPicker(selection: $draft.messenger)
                FieldBox(label: draft.messenger == .phone ? "Номер телефона" : "Юзернейм или номер") {
                    TextField(draft.messenger.placeholder, text: $draft.contact)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(draft.messenger == .phone || draft.messenger == .whatsapp ? .phonePad : .default)
                }
                Text("Контакт увидят участники платформы: авторы объявлений, на которые вы откликнетесь, и те, кто откликнется на ваши.")
                    .font(Typo.footnote)
                    .foregroundStyle(Palette.graphite)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(number: "C", title: "Навыки", trailing: "\(draft.skills.count)")
                TagEditor(items: $draft.skills, placeholder: "Например, PyTorch", suggestions: skillSuggestions)
            }

            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(number: "D", title: "Проекты", trailing: "\(draft.projects.count)")
                ListEditor(items: $draft.projects, placeholder: "Название и пара слов о проекте")
            }

            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(number: "E", title: "Достижения", trailing: "\(draft.achievements.count)")
                ListEditor(items: $draft.achievements, placeholder: "Например: призёр олимпиады по физике, 2025")
            }
        }
    }
}

// MARK: - Поля

struct MessengerPicker: View {
    @Binding var selection: Messenger

    var body: some View {
        FlowLayout(spacing: 6, lineSpacing: 6) {
            ForEach(Messenger.allCases) { messenger in
                Chip(title: messenger.title, isOn: selection == messenger) {
                    selection = messenger
                }
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}

struct CityField: View {
    @Binding var city: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            FieldBox(label: "Город") {
                TextField("Например, Алматы", text: $city)
                    .textContentType(.addressCity)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Cities.popular, id: \.self) { option in
                        Chip(title: option, isOn: Cities.same(option, city)) {
                            city = option
                        }
                    }
                }
            }
        }
    }
}

/// Теги: навыки, роли.
struct TagEditor: View {
    @Binding var items: [String]
    var placeholder: String
    var suggestions: [String] = []
    @State private var input = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                TextField(placeholder, text: $input)
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

            if !items.isEmpty {
                FlowLayout(spacing: 6, lineSpacing: 6) {
                    ForEach(items, id: \.self) { item in
                        Button {
                            items.removeAll { $0 == item }
                        } label: {
                            HStack(spacing: 6) {
                                Text(item)
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
                        .accessibilityLabel("Удалить \(item)")
                    }
                }
            }

            let rest = suggestions.filter { !items.contains($0) }
            if !rest.isEmpty {
                FlowLayout(spacing: 6, lineSpacing: 6) {
                    ForEach(rest, id: \.self) { suggestion in
                        Button {
                            items.append(suggestion)
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
        guard !value.isEmpty, !items.contains(value) else { return }
        items.append(value)
    }
}

/// Нумерованный список с добавлением и удалением: проекты, достижения.
struct ListEditor: View {
    @Binding var items: [String]
    var placeholder: String
    @State private var input = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(String(format: "%02d", index + 1))
                        .font(Typo.mono(11, weight: .semibold))
                        .foregroundStyle(Palette.faint)
                    Text(item)
                        .font(Typo.subhead)
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Button {
                        if items.indices.contains(index) {
                            items.remove(at: index)
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Palette.graphite)
                            .frame(width: 30, height: 30)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Удалить запись")
                }
                .padding(.vertical, 6)
                .overlay(alignment: .bottom) { Hairline() }
            }
            HStack(spacing: 8) {
                TextField(placeholder, text: $input, axis: .vertical)
                    .lineLimit(1...3)
                    .submitLabel(.done)
                    .onSubmit(add)
                    .font(Typo.body)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 11)
                    .background(Palette.surface)
                    .overlay { Rectangle().strokeBorder(Palette.lineStrong, lineWidth: 1) }
                Button("Добавить", action: add)
                    .buttonStyle(.outlineCompact)
                    .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.top, 10)
        }
    }

    private func add() {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        input = ""
        guard !value.isEmpty else { return }
        items.append(value)
    }
}

/// Выбор формата объявления.
struct FormatPicker: View {
    @Binding var selection: CardFormat

    var body: some View {
        HStack(spacing: 0) {
            ForEach(CardFormat.allCases) { format in
                let isOn = selection == format
                Button {
                    selection = format
                } label: {
                    Text(format.title)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(isOn ? Palette.paper : Palette.ink)
                        .background(isOn ? Palette.ink : Palette.surface)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? .isSelected : [])
                if format != CardFormat.allCases.last {
                    Hairline(color: Palette.lineStrong, vertical: true)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .overlay { Rectangle().strokeBorder(Palette.lineStrong, lineWidth: 1) }
        .sensoryFeedback(.selection, trigger: selection)
    }
}
