import SwiftUI

private struct ChallengeGroup: Identifiable {
    let id: Int
    let title: String
    let items: [Challenge]
}

struct ChallengesView: View {
    @EnvironmentObject private var store: AppStore
    @State private var filter: ChallengeKind?
    @State private var savedOnly = false
    @State private var showScanner = false

    private var visible: [Challenge] {
        let today = Calendar.current.startOfDay(for: Date())
        return store.sortedChallenges.filter { (challenge: Challenge) -> Bool in
            if challenge.startDate < today { return false }
            if let filter, challenge.kind != filter { return false }
            if savedOnly && !store.isSaved(challenge) { return false }
            return true
        }
    }

    private var featured: Challenge? {
        visible
            .filter { Fmt.daysUntil($0.registrationDeadline) >= 0 }
            .min { $0.registrationDeadline < $1.registrationDeadline }
    }

    private var groups: [ChallengeGroup] {
        var keys: [Int] = []
        var buckets: [Int: [Challenge]] = [:]
        for challenge in visible {
            let key = Fmt.monthKey(challenge.startDate)
            if buckets[key] == nil {
                keys.append(key)
                buckets[key] = []
            }
            buckets[key]?.append(challenge)
        }
        return keys.map { (key: Int) -> ChallengeGroup in
            let items = buckets[key] ?? []
            let title = items.first.map { Fmt.monthYear($0.startDate) } ?? ""
            return ChallengeGroup(id: key, title: title, items: items)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenHeader(
                    index: "01",
                    title: "Вызовы",
                    subtitle: "Хакатоны, олимпиады, конкурсы и гранты. Выберите событие и соберите под него команду."
                ) {
                    Button {
                        showScanner = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "text.viewfinder")
                                .font(.system(size: 12, weight: .semibold))
                            Text("СКАН АФИШИ")
                                .font(Typo.mono(11, weight: .bold))
                        }
                        .foregroundStyle(Palette.ink)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .overlay { Rectangle().strokeBorder(Palette.ink, lineWidth: 1) }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Распознать афишу")
                }
                .padding(.bottom, 18)

                filterBar
                    .padding(.bottom, 26)

                if let featured {
                    FeaturedDeadline(challenge: featured, recruiting: store.recruitingTeamsCount(for: featured))
                        .padding(.bottom, 36)
                }

                if visible.isEmpty {
                    EmptyNote(
                        title: savedOnly ? "Сохранённых вызовов нет" : "Ничего не нашлось",
                        message: savedOnly
                            ? "Добавляйте события в сохранённые, чтобы не потерять дедлайны."
                            : "Попробуйте другой тип события или добавьте вызов по фото афиши."
                    )
                }

                ForEach(groups) { group in
                    SectionTitle(
                        number: "§",
                        title: group.title,
                        trailing: Fmt.count(group.items.count, "событие", "события", "событий")
                    )
                    ForEach(group.items) { challenge in
                        NavigationLink(value: Route.challenge(challenge.id)) {
                            ChallengeRow(
                                challenge: challenge,
                                recruiting: store.recruitingTeamsCount(for: challenge),
                                saved: store.isSaved(challenge)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    Color.clear.frame(height: 30)
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
        .sheet(isPresented: $showScanner) {
            PosterScanView()
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Chip(title: "Все", isOn: filter == nil && !savedOnly) {
                    filter = nil
                    savedOnly = false
                }
                ForEach(ChallengeKind.allCases) { kind in
                    Chip(title: kind.plural, isOn: filter == kind) {
                        filter = (filter == kind) ? nil : kind
                    }
                }
                Chip(title: "Сохранённые", isOn: savedOnly) {
                    savedOnly.toggle()
                }
            }
        }
        .sensoryFeedback(.selection, trigger: filter)
    }
}

// MARK: - Ближайший дедлайн

struct FeaturedDeadline: View {
    let challenge: Challenge
    let recruiting: Int

    private var days: Int { max(0, Fmt.daysUntil(challenge.registrationDeadline)) }

    var body: some View {
        NavigationLink(value: Route.challenge(challenge.id)) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    MonoLabel("Ближайший дедлайн", color: Palette.paper.opacity(0.7), size: 10.5)
                    Spacer()
                    Text(challenge.kind.code)
                        .font(Typo.mono(10, weight: .bold))
                        .foregroundStyle(Palette.ink)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Palette.paper)
                }
                HStack(alignment: .lastTextBaseline, spacing: 12) {
                    Text(String(format: "%02d", days))
                        .font(Typo.display(64, weight: .heavy))
                        .monospacedDigit()
                        .foregroundStyle(Palette.signal)
                    Text("\(Fmt.plural(days, "день", "дня", "дней"))\nдо конца регистрации".uppercased())
                        .font(Typo.mono(11, weight: .semibold))
                        .foregroundStyle(Palette.paper)
                        .padding(.bottom, 8)
                }
                Text(challenge.title)
                    .font(Typo.display(20, weight: .bold))
                    .foregroundStyle(Palette.paper)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(challenge.placeText) · команда \(challenge.teamSizeText) · старт \(Fmt.dayMonth(challenge.startDate))")
                    .font(Typo.footnote)
                    .foregroundStyle(Palette.paper.opacity(0.72))
                    .multilineTextAlignment(.leading)
                HStack {
                    Text(recruitingText.uppercased())
                        .font(Typo.mono(11, weight: .semibold))
                        .foregroundStyle(Palette.paper)
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.signal)
                }
                .padding(.top, 4)
            }
            .padding(20)
            .background(Palette.ink)
            .overlay { CropMarks(color: Palette.ink) }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var recruitingText: String {
        if recruiting == 0 { return "Команд пока нет — станьте первыми" }
        return "\(recruiting) \(Fmt.plural(recruiting, "команда ищет", "команды ищут", "команд ищут")) людей"
    }
}

// MARK: - Строка события

struct ChallengeRow: View {
    let challenge: Challenge
    let recruiting: Int
    let saved: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Fmt.day(challenge.startDate))
                        .font(Typo.display(30, weight: .heavy))
                        .monospacedDigit()
                        .foregroundStyle(Palette.ink)
                    MonoLabel(Fmt.monthShort(challenge.startDate), color: Palette.ink, size: 11, weight: .semibold)
                    MonoLabel(Fmt.weekdayShort(challenge.startDate), color: Palette.faint, size: 10)
                }
                .frame(width: 56, alignment: .leading)

                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 8) {
                        KindTag(kind: challenge.kind)
                        if saved {
                            Image(systemName: "bookmark.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(Palette.signal)
                                .accessibilityLabel("Сохранено")
                        }
                        Spacer(minLength: 4)
                        deadlineLabel
                    }
                    Text(challenge.title)
                        .font(Typo.title)
                        .foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(challenge.organizer)
                        .font(Typo.footnote)
                        .foregroundStyle(Palette.graphite)
                        .lineLimit(1)
                    HStack(spacing: 12) {
                        MonoLabel(challenge.placeText, color: Palette.ink, size: 10.5)
                        MonoLabel("Команда \(challenge.teamSizeText)", color: Palette.ink, size: 10.5)
                    }
                    if recruiting > 0 {
                        Text("\(recruiting) \(Fmt.plural(recruiting, "команда ищет", "команды ищут", "команд ищут")) людей")
                            .font(Typo.mono(11, weight: .semibold))
                            .foregroundStyle(Palette.signal)
                    }
                }
            }
            .padding(.vertical, 18)
            Hairline()
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var deadlineLabel: some View {
        let days = Fmt.daysUntil(challenge.registrationDeadline)
        if days < 0 {
            MonoLabel("Рег. закрыта", color: Palette.faint, size: 10)
        } else {
            MonoLabel(
                "Рег. до \(Fmt.numeric(challenge.registrationDeadline))",
                color: days <= 7 ? Palette.signal : Palette.graphite,
                size: 10
            )
        }
    }
}
