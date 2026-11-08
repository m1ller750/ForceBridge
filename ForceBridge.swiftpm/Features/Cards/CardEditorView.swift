import SwiftUI

/// Создание и изменение карточки-объявления.
/// После сохранения ИИ сам относит карточку к категориям фильтра.
struct CardEditorView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let editing: Card?

    @State private var kind: CardKind = .teammate
    @State private var title = ""
    @State private var eventName = ""
    @State private var description = ""
    @State private var roles: [String] = []
    @State private var city = ""
    @State private var format: CardFormat = .any
    @State private var hasDeadline = false
    @State private var deadline = Date().addingTimeInterval(14 * 24 * 3600)
    @State private var prepared = false
    @State private var saving = false
    @State private var errorText: String?
    @State private var showScanner = false

    private let roleSuggestions = [
        "Разработчик", "Дизайнер", "ML-инженер", "Аналитик", "Биолог", "Химик",
        "Физик", "Математик", "Инженер-электронщик", "Питчер", "Исследователь"
    ]

    private var validationMessage: String? {
        if title.trimmingCharacters(in: .whitespacesAndNewlines).count < 3 {
            return "Заголовок — минимум 3 символа."
        }
        if description.trimmingCharacters(in: .whitespacesAndNewlines).count < 10 {
            return "Опишите задачу подробнее — минимум 10 символов."
        }
        return nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    scanBanner
                    kindSection
                    textSection
                    rolesSection
                    detailsSection
                    footer
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
                    MonoLabel(editing == nil ? "Новое объявление" : "Изменение", color: Palette.ink, weight: .semibold)
                }
            }
        }
        .presentationBackground(Palette.paper)
        .onAppear(perform: prepare)
        .sheet(isPresented: $showScanner) {
            PosterScanView { draft in
                apply(draft)
            }
        }
    }

    // MARK: Секции

    private var scanBanner: some View {
        Button {
            showScanner = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "text.viewfinder")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Заполнить по фото афиши")
                        .font(Typo.subhead.weight(.semibold))
                        .foregroundStyle(Palette.ink)
                    Text("Vision прочитает название, даты и город")
                        .font(Typo.footnote)
                        .foregroundStyle(Palette.graphite)
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.ink)
            }
            .padding(14)
            .overlay {
                Rectangle().strokeBorder(Palette.ink, style: StrokeStyle(lineWidth: 1.2, dash: [5, 3]))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var kindSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(number: "01", title: "Что ищете")
            VStack(spacing: 6) {
                ForEach(CardKind.allCases) { option in
                    Button {
                        kind = option
                    } label: {
                        HStack(spacing: 10) {
                            Text(option.code)
                                .font(Typo.mono(10, weight: .bold))
                                .frame(width: 40, alignment: .leading)
                            Text(option.title)
                                .font(.system(size: 15, weight: .semibold))
                            Spacer()
                        }
                        .foregroundStyle(kind == option ? Palette.paper : Palette.ink)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(kind == option ? Palette.ink : Palette.surface)
                        .overlay { Rectangle().strokeBorder(kind == option ? Palette.ink : Palette.lineStrong, lineWidth: 1) }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(kind == option ? .isSelected : [])
                }
            }
            .sensoryFeedback(.selection, trigger: kind)
        }
    }

    private var textSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle(number: "02", title: "Объявление")
            FieldBox(label: "Заголовок", hint: "\(title.count)/120") {
                TextField(titlePlaceholder, text: $title, axis: .vertical)
                    .lineLimit(1...3)
            }
            .onChange(of: title) { _, newValue in
                if newValue.count > 120 { title = String(newValue.prefix(120)) }
            }
            FieldBox(label: "Конкурс, хакатон или проект", hint: "необязательно") {
                TextField("Например, хакатон «Северный код»", text: $eventName)
            }
            FieldBox(label: "Описание", hint: "\(description.count)/3000") {
                TextField("Задача, что уже есть, что нужно от человека, сроки", text: $description, axis: .vertical)
                    .lineLimit(5...14)
            }
            .onChange(of: description) { _, newValue in
                if newValue.count > 3000 { description = String(newValue.prefix(3000)) }
            }
        }
    }

    private var rolesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(number: "03", title: kind == .join ? "Чем можете помочь команде" : "Кого ищете", trailing: "\(roles.count)")
            TagEditor(items: $roles, placeholder: "Роль или навык", suggestions: roleSuggestions)
        }
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle(number: "04", title: "Формат и сроки")
            FormatPicker(selection: $format)
            if format != .online {
                CityField(city: $city)
            }
            Toggle(isOn: $hasDeadline.animation()) {
                Text("Есть дедлайн")
                    .font(Typo.headline)
                    .foregroundStyle(Palette.ink)
            }
            .tint(Palette.signal)
            if hasDeadline {
                DatePicker(selection: $deadline, in: Date()..., displayedComponents: .date) {
                    MonoLabel("Дедлайн", size: 10.5)
                }
                .environment(\.locale, Fmt.locale)
                .tint(Palette.signal)
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                AIBadge()
                Text(editing == nil
                     ? "После публикации ИИ прочитает объявление и отнесёт его к одной или нескольким категориям фильтра."
                     : "Если вы измените текст, ИИ заново разберёт объявление и обновит категории. Изменения сразу увидят все.")
                    .font(Typo.footnote)
                    .foregroundStyle(Palette.graphite)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let errorText {
                Text(errorText)
                    .font(Typo.footnote)
                    .foregroundStyle(Palette.signal)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button(saving ? "Сохраняем…" : (editing == nil ? "Опубликовать" : "Сохранить изменения")) {
                save()
            }
            .buttonStyle(.signal)
            .disabled(saving)
        }
    }

    private var titlePlaceholder: String {
        switch kind {
        case .teammate: return "Ищу дизайнера в команду на хакатон"
        case .research: return "Нужен химик для исследования микропластика"
        case .join: return "Frontend-разработчик ищет команду на конкурс"
        }
    }

    // MARK: Логика

    private func prepare() {
        guard !prepared else { return }
        prepared = true
        if let editing {
            kind = editing.kind
            title = editing.title
            eventName = editing.eventName
            description = editing.description
            roles = editing.roles
            city = editing.city
            format = editing.format
            if let date = editing.deadline {
                hasDeadline = true
                deadline = date
            }
        } else if let me = store.me {
            city = me.city
        }
    }

    private func apply(_ draft: PosterDraft) {
        if !draft.title.isEmpty {
            eventName = draft.title
            if title.isEmpty {
                title = "Ищу команду на «\(draft.title)»"
            }
        }
        if description.isEmpty {
            description = draft.cardDescription
        }
        format = draft.format
        if !draft.city.isEmpty {
            city = draft.city
        }
        if draft.datesFound > 0 {
            hasDeadline = true
            deadline = draft.deadline
        }
    }

    private func save() {
        if let message = validationMessage {
            errorText = message
            return
        }
        guard store.me != nil else { return }
        errorText = nil
        saving = true
        let draft = CardDraft(
            kind: kind,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            eventName: eventName.trimmingCharacters(in: .whitespacesAndNewlines),
            roles: roles,
            city: format == .online ? "" : city.trimmingCharacters(in: .whitespacesAndNewlines),
            format: format,
            deadline: hasDeadline ? deadline : nil
        )
        Task {
            do {
                try await store.saveCard(draft, editing: editing)
                store.showToast(
                    editing == nil ? "Объявление опубликовано" : "Изменения сохранены",
                    "ИИ раскладывает его по категориям — это займёт несколько секунд."
                )
                dismiss()
            } catch {
                errorText = error.localizedDescription
            }
            saving = false
        }
    }
}
