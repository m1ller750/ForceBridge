import SwiftUI
import UIKit

@MainActor
struct OnboardingView: View {
    @EnvironmentObject private var store: AppStore
    @State private var step = 0
    @State private var draft = ProfileDraft()

    private let lastStep = 5

    var body: some View {
        ZStack {
            Palette.paper.ignoresSafeArea()
            if step == 0 {
                IntroView(
                    onStart: { go(to: 1) },
                    onDemo: { store.completeOnboarding(with: SeedData.demoProfile()) }
                )
                .transition(.opacity)
            } else {
                wizard
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: step)
    }

    // MARK: Мастер

    private var wizard: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    go(to: step - 1)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 12, weight: .semibold))
                        Text("НАЗАД")
                            .font(Typo.mono(11.5, weight: .semibold))
                    }
                    .foregroundStyle(Palette.ink)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Spacer()
                MonoLabel(step < lastStep ? "Шаг \(step) / 4" : "Паспорт готов", color: Palette.graphite)
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.top, 8)

            StepProgress(current: min(step, 4), total: 4)
                .padding(.horizontal, Metrics.gutter)
                .padding(.top, 6)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    stepHeader
                    stepContent
                }
                .padding(.horizontal, Metrics.gutter)
                .padding(.top, 26)
                .padding(.bottom, 32)
                .contentColumn()
            }
            .scrollDismissesKeyboard(.interactively)

            VStack(spacing: 0) {
                Hairline(color: Palette.lineStrong)
                Button(primaryTitle) {
                    advance()
                }
                .buttonStyle(.signal)
                .disabled(!canAdvance)
                .padding(.horizontal, Metrics.gutter)
                .padding(.vertical, 12)
                .contentColumn()
            }
            .background(Palette.paper)
        }
    }

    @ViewBuilder
    private var stepHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(stepTitle)
                .font(Typo.display(30, weight: .heavy))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(stepSubtitle)
                .font(Typo.subhead)
                .foregroundStyle(Palette.graphite)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 1:
            IdentityFields(draft: $draft)
        case 2:
            RolePicker(selection: $draft.roles)
        case 3:
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 10) {
                    SectionTitle(number: "A", title: "Темы", trailing: "\(draft.interests.count) выбрано")
                    TopicPicker(selection: $draft.interests)
                }
                VStack(alignment: .leading, spacing: 10) {
                    SectionTitle(number: "B", title: "Навыки", trailing: "\(draft.skills.count)")
                    SkillEditor(skills: $draft.skills, suggestions: draft.suggestedSkills)
                }
            }
        case 4:
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    SectionTitle(number: "A", title: "Сколько времени готовы вкладывать")
                    HoursRuler(value: $draft.hours)
                }
                VStack(alignment: .leading, spacing: 10) {
                    SectionTitle(number: "B", title: "Формат работы")
                    FormatPicker(selection: $draft.format)
                }
                Toggle(isOn: $draft.lookingForTeam) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Ищу команду")
                            .font(Typo.headline)
                        Text("Команды с подходящими вакансиями смогут вас пригласить.")
                            .font(Typo.footnote)
                            .foregroundStyle(Palette.graphite)
                    }
                }
                .tint(Palette.signal)
            }
        default:
            VStack(alignment: .leading, spacing: 18) {
                TitleBlock(person: draft.makePerson(), isMe: true)
                if !draft.headline.isEmpty {
                    Text("«\(draft.headline)»")
                        .font(Typo.serif(19))
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !draft.interests.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        MonoLabel("Темы", size: 10)
                        TagList(tags: draft.interests)
                    }
                }
                if !draft.skills.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        MonoLabel("Навыки", size: 10)
                        TagList(tags: draft.skills)
                    }
                }
            }
        }
    }

    // MARK: Логика шагов

    private var stepTitle: String {
        switch step {
        case 1: return "Кто вы"
        case 2: return "Ваши роли"
        case 3: return "Темы и навыки"
        case 4: return "Нагрузка"
        default: return "Паспорт участника"
        }
    }

    private var stepSubtitle: String {
        switch step {
        case 1: return "Это увидят команды и участники. Контакты не публикуются."
        case 2: return "Выберите до трёх ролей. Первая станет основной — по ней вас будут находить на вакансии."
        case 3: return "Темы — то, чем хочется заниматься. Совпадение по темам важнее совпадения по навыкам."
        case 4: return "Честная оценка времени экономит командам недели. Её можно поменять в любой момент."
        default: return "Так ваш профиль видят другие. Проверьте и начинайте собирать конструкцию."
        }
    }

    private var primaryTitle: String {
        step >= lastStep ? "Начать" : "Далее"
    }

    private var canAdvance: Bool {
        switch step {
        case 1: return draft.isIdentityValid
        case 2: return !draft.roles.isEmpty
        case 3: return !draft.interests.isEmpty
        default: return true
        }
    }

    private func advance() {
        if step >= lastStep {
            store.completeOnboarding(with: draft.makePerson())
        } else {
            go(to: step + 1)
        }
    }

    private func go(to value: Int) {
        hideKeyboard()
        step = max(0, min(lastStep, value))
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

/// Прогресс по шагам — сегменты, как деления шкалы.
struct StepProgress: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...max(total, 1), id: \.self) { index in
                Rectangle()
                    .fill(index <= current ? Palette.ink : Palette.line)
                    .frame(height: 3)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: current)
        .accessibilityElement()
        .accessibilityLabel("Шаг \(current) из \(total)")
    }
}

// MARK: - Вступительный экран

private struct IntroView: View {
    let onStart: () -> Void
    let onDemo: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                HStack {
                    MonoLabel("ForceBridge / v1.0", color: Palette.faint)
                    Spacer()
                    MonoLabel("Лист 1", color: Palette.faint)
                }

                AssemblingTruss()
                    .frame(height: 118)
                    .padding(.top, 8)

                VStack(alignment: .leading, spacing: 14) {
                    Text("Force\nBridge")
                        .font(Typo.display(54, weight: .heavy))
                        .foregroundStyle(Palette.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text("Команда — это конструкция. Найдите тех, с кем она выдержит нагрузку хакатона, олимпиады или научного проекта.")
                        .font(Typo.serif(20))
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Ruler()

                VStack(alignment: .leading, spacing: 18) {
                    Principle(
                        number: "01",
                        title: "Похожие цели, разные навыки",
                        text: "Подбираем тех, кто дополняет вас, а не повторяет."
                    )
                    Principle(
                        number: "02",
                        title: "Прозрачный расчёт",
                        text: "Каждая оценка раскладывается на роли, цели, время и географию — видно, почему человек подходит."
                    )
                    Principle(
                        number: "03",
                        title: "Всё в одной ленте",
                        text: "Хакатоны, олимпиады, конкурсы, гранты и долгие научные проекты."
                    )
                }

                VStack(spacing: 10) {
                    Button("Собрать профиль", action: onStart)
                        .buttonStyle(.signal)
                    Button("Посмотреть на демо-профиле", action: onDemo)
                        .buttonStyle(.outline)
                }
                .padding(.top, 6)
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.vertical, 20)
            .contentColumn()
        }
    }
}

private struct Principle: View {
    let number: String
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(number)
                .font(Typo.mono(12, weight: .bold))
                .foregroundStyle(Palette.signal)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Typo.headline)
                    .foregroundStyle(Palette.ink)
                Text(text)
                    .font(Typo.subhead)
                    .foregroundStyle(Palette.graphite)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Ферма, которая «собирается» при появлении: сначала рама, затем панели.
struct AssemblingTruss: View {
    var filled: [Bool] = [true, false, true, true, false, true, true]
    @State private var progress: CGFloat = 0
    @State private var panelsVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let truss = TrussGeometry(
                count: filled.count,
                rect: CGRect(x: 5, y: 5, width: proxy.size.width - 10, height: proxy.size.height - 10)
            )
            ZStack(alignment: .topLeading) {
                ForEach(0..<filled.count, id: \.self) { index in
                    PolygonShape(points: truss.panel(index, shrink: 0.6))
                        .fill(filled[index] ? Palette.ink : Palette.signal)
                        .opacity(panelsVisible ? 1 : 0)
                        .animation(.easeOut(duration: 0.35).delay(Double(index) * 0.07), value: panelsVisible)
                }
                truss.framePath
                    .trim(from: 0, to: progress)
                    .stroke(Palette.ink, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                ForEach(Array(truss.nodes.enumerated()), id: \.offset) { _, point in
                    Circle()
                        .fill(Palette.paper)
                        .overlay { Circle().strokeBorder(Palette.ink, lineWidth: 1.5) }
                        .frame(width: 8, height: 8)
                        .position(point)
                        .opacity(panelsVisible ? 1 : 0)
                }
            }
        }
        .accessibilityHidden(true)
        .task {
            if reduceMotion {
                progress = 1
                panelsVisible = true
                return
            }
            withAnimation(.easeInOut(duration: 1.3)) {
                progress = 1
            }
            try? await Task.sleep(nanoseconds: 900_000_000)
            panelsVisible = true
        }
    }
}
