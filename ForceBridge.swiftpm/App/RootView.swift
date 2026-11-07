import SwiftUI

enum Route: Hashable {
    case challenge(UUID)
    case team(UUID)
    case person(UUID)
}

enum AppTab: Int, CaseIterable, Identifiable {
    case challenges, teams, map, profile

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .challenges: return "Вызовы"
        case .teams: return "Команды"
        case .map: return "Карта сил"
        case .profile: return "Профиль"
        }
    }

    var number: String { String(format: "%02d", rawValue + 1) }
}

struct RootView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        ZStack {
            if store.me == nil {
                OnboardingView()
                    .transition(.opacity)
            } else {
                MainView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: store.me == nil)
        .overlay(alignment: .top) {
            ToastOverlay()
        }
    }
}

struct MainView: View {
    @EnvironmentObject private var store: AppStore
    @State private var tab: AppTab = .challenges
    @State private var challengesPath: [Route] = []
    @State private var teamsPath: [Route] = []
    @State private var mapPath: [Route] = []
    @State private var profilePath: [Route] = []

    var body: some View {
        ZStack {
            layer(.challenges) {
                NavigationStack(path: $challengesPath) {
                    ChallengesView()
                        .routeDestinations()
                }
            }
            layer(.teams) {
                NavigationStack(path: $teamsPath) {
                    TeamsView()
                        .routeDestinations()
                }
            }
            layer(.map) {
                NavigationStack(path: $mapPath) {
                    ForceMapView(isActive: tab == .map)
                        .routeDestinations()
                }
            }
            layer(.profile) {
                NavigationStack(path: $profilePath) {
                    ProfileView()
                        .routeDestinations()
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            TabBar(selection: $tab, badge: store.incomingPending.count) { reselected in
                popToRoot(reselected)
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .paperBackground()
    }

    private func layer<Content: View>(_ value: AppTab, @ViewBuilder content: () -> Content) -> some View {
        content()
            .opacity(tab == value ? 1 : 0)
            .allowsHitTesting(tab == value)
            .accessibilityHidden(tab != value)
    }

    private func popToRoot(_ value: AppTab) {
        switch value {
        case .challenges: challengesPath.removeAll()
        case .teams: teamsPath.removeAll()
        case .map: mapPath.removeAll()
        case .profile: profilePath.removeAll()
        }
    }
}

extension View {
    func routeDestinations() -> some View {
        navigationDestination(for: Route.self) { route in
            switch route {
            case .challenge(let id):
                ChallengeDetailView(challengeID: id)
            case .team(let id):
                TeamDetailView(teamID: id)
            case .person(let id):
                PersonDetailView(personID: id)
            }
        }
    }

    /// Единый стиль навигационной панели для экранов деталей.
    func detailNavigation(_ label: String) -> some View {
        self
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    MonoLabel(label, color: Palette.ink, size: 11, weight: .semibold)
                }
            }
            .toolbarBackground(Palette.paper, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
}

// MARK: - Панель вкладок

struct TabBar: View {
    @Binding var selection: AppTab
    var badge: Int
    var onReselect: (AppTab) -> Void
    @Namespace private var marker

    var body: some View {
        VStack(spacing: 0) {
            Hairline(color: Palette.lineStrong)
            HStack(spacing: 0) {
                ForEach(AppTab.allCases) { tab in
                    Button {
                        select(tab)
                    } label: {
                        item(tab)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tab.title)
                    .accessibilityValue(tab == .profile && badge > 0 ? "Новых запросов: \(badge)" : "")
                    .accessibilityAddTraits(selection == tab ? .isSelected : [])
                }
            }
            .frame(height: Metrics.tabBarHeight)
            .frame(maxWidth: Metrics.maxContentWidth)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.paper.ignoresSafeArea(edges: .bottom))
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func select(_ tab: AppTab) {
        if selection == tab {
            onReselect(tab)
        } else {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                selection = tab
            }
        }
    }

    private func item(_ tab: AppTab) -> some View {
        let isOn = selection == tab
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Text(tab.number)
                    .font(Typo.mono(10, weight: .semibold))
                    .foregroundStyle(isOn ? Palette.signal : Palette.faint)
                if tab == .profile && badge > 0 {
                    Text("\(badge)")
                        .font(Typo.mono(9, weight: .bold))
                        .foregroundStyle(Palette.onSignal)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Palette.signal)
                }
            }
            Text(tab.title)
                .font(.system(size: 13, weight: isOn ? .semibold : .regular))
                .foregroundStyle(isOn ? Palette.ink : Palette.graphite)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.leading, 14)
        .overlay(alignment: .top) {
            if isOn {
                Rectangle()
                    .fill(Palette.ink)
                    .frame(height: 2)
                    .matchedGeometryEffect(id: "tab-marker", in: marker)
            }
        }
        .overlay(alignment: .leading) {
            if tab != .challenges {
                Hairline(vertical: true)
                    .padding(.vertical, 14)
            }
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Уведомления

struct ToastOverlay: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        VStack(spacing: 0) {
            if let toast = store.toast {
                ToastCard(toast: toast)
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onTapGesture {
                        store.toast = nil
                    }
            }
        }
        .frame(maxWidth: 560)
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: store.toast)
        .sensoryFeedback(.impact(weight: .light), trigger: store.toast?.id)
    }
}

struct ToastCard: View {
    let toast: Toast

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Rectangle()
                .fill(Palette.signal)
                .frame(width: 4)
            VStack(alignment: .leading, spacing: 3) {
                Text(toast.title)
                    .font(Typo.headline)
                    .foregroundStyle(Palette.paper)
                Text(toast.message)
                    .font(Typo.footnote)
                    .foregroundStyle(Palette.paper.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 12)
            Spacer(minLength: 0)
        }
        .padding(.trailing, 14)
        .background(Palette.ink)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }
}
