import SwiftUI

struct TeamsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var scope: Scope = .forMe
    @State private var showEditor = false

    enum Scope: String, CaseIterable, Identifiable {
        case forMe, all, events, research

        var id: String { rawValue }

        var title: String {
            switch self {
            case .forMe: return "Подходят мне"
            case .all: return "Все"
            case .events: return "К событиям"
            case .research: return "Наука"
            }
        }
    }

    private var list: [RankedTeam] {
        let all = store.rankedOpenTeams
        switch scope {
        case .forMe:
            return all.filter { roleValue($0.report) > 0 }
        case .all:
            return all
        case .events:
            return all.filter { !$0.team.isResearch }
        case .research:
            return all.filter { $0.team.isResearch }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenHeader(
                    index: "02",
                    title: "Команды",
                    subtitle: "Каждая команда — конструкция из ролей. Закрашенная панель — роль закрыта, пунктир — вакансия."
                ) {
                    Button {
                        showEditor = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 11, weight: .bold))
                            Text("СОБРАТЬ")
                                .font(Typo.mono(11, weight: .bold))
                        }
                        .foregroundStyle(Palette.onSignal)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(Palette.signal)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Собрать команду")
                }
                .padding(.bottom, 22)

                if !store.myTeams.isEmpty {
                    SectionTitle(number: "01", title: "Мои команды", trailing: "\(store.myTeams.count)")
                    ForEach(store.myTeams) { team in
                        NavigationLink(value: Route.team(team.id)) {
                            TeamRow(
                                team: team,
                                subtitle: (store.isOwner(team) ? "Вы собираете · " : "Вы в составе · ") + teamSubtitle(team, store: store)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    Color.clear.frame(height: 30)
                }

                SectionTitle(
                    number: store.myTeams.isEmpty ? "01" : "02",
                    title: "Ищут людей",
                    trailing: "\(list.count)"
                )

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Scope.allCases) { item in
                            Chip(title: item.title, isOn: scope == item) {
                                scope = item
                            }
                        }
                    }
                }
                .padding(.top, 14)
                .sensoryFeedback(.selection, trigger: scope)

                legend
                    .padding(.top, 12)
                    .padding(.bottom, 4)

                if list.isEmpty {
                    EmptyNote(
                        title: scope == .forMe ? "Пока нет вакансий под ваши роли" : "Здесь пусто",
                        message: scope == .forMe
                            ? "Посмотрите все команды или соберите свою — подходящие люди найдутся на карте сил."
                            : "Попробуйте другой фильтр."
                    )
                    .padding(.top, 12)
                }

                ForEach(list) { ranked in
                    NavigationLink(value: Route.team(ranked.team.id)) {
                        TeamRow(
                            team: ranked.team,
                            subtitle: teamSubtitle(ranked.team, store: store),
                            score: ranked.report.total
                        )
                    }
                    .buttonStyle(.plain)
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
            TeamEditorView(preselectedChallengeID: nil)
        }
    }

    private var legend: some View {
        HStack(spacing: 16) {
            HStack(spacing: 6) {
                TrussGlyph(states: [true])
                    .frame(width: 14, height: 12)
                MonoLabel("Роль закрыта", color: Palette.graphite, size: 9.5)
            }
            HStack(spacing: 6) {
                TrussGlyph(states: [false])
                    .frame(width: 14, height: 12)
                MonoLabel("Вакансия", color: Palette.graphite, size: 9.5)
            }
            Spacer()
            MonoLabel("Совм. / 100", color: Palette.faint, size: 9.5)
        }
        .accessibilityHidden(true)
    }

    private func roleValue(_ report: MatchReport) -> Double {
        report.factors.first { $0.id == "roles" }?.value ?? 0
    }
}
