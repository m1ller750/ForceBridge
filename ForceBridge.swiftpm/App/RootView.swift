import SwiftUI

enum Route: Hashable {
    case card(UUID)
    case profile(UUID)
    case respondent(ResponseRow)
}

enum AppTab: Int, CaseIterable, Identifiable {
    case feed, map, cabinet

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .feed: return "Объявления"
        case .map: return "Карта сил"
        case .cabinet: return "Кабинет"
        }
    }

    var number: String { String(format: "%02d", rawValue + 1) }
}

struct RootView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        ZStack {
            switch store.phase {
            case .launching:
                LaunchView()
                    .transition(.opacity)
            case .signedOut:
                AuthView()
                    .transition(.opacity)
            case .needsProfile:
                ProfileSetupView()
                    .transition(.opacity)
            case .ready:
                MainView()
                    .transition(.opacity)
            case .failed(let message):
                LaunchFailedView(message: message)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: store.phase)
        .overlay(alignment: .top) {
            ToastOverlay()
        }
        .task {
            await store.bootstrap()
        }
    }
}

private struct LaunchView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer()
            AssemblingTruss()
                .frame(height: 96)
            MonoLabel("ForceBridge · подключаемся", color: Palette.graphite)
            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .paperBackground()
    }
}

private struct LaunchFailedView: View {
    @EnvironmentObject private var store: AppStore
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer()
            EmptyNote(title: "Не удалось загрузить профиль", message: message)
            Button("Повторить") {
                Task { await store.retryLaunch() }
            }
            .buttonStyle(.signal)
            Button("Выйти из аккаунта") {
                Task { await store.signOut() }
            }
            .buttonStyle(.outline)
            Spacer()
        }
        .padding(.horizontal, Metrics.gutter)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .paperBackground()
    }
}

struct MainView: View {
    @EnvironmentObject private var store: AppStore
    @State private var tab: AppTab = .feed
    @State private var feedPath: [Route] = []
    @State private var mapPath: [Route] = []
    @State private var cabinetPath: [Route] = []

    private var responsesTotal: Int {
        store.myCards.reduce(0) { $0 + ($1.responsesCount ?? 0) }
    }

    var body: some View {
        ZStack {
            layer(.feed) {
                NavigationStack(path: $feedPath) {
                    FeedView()
                        .routeDestinations()
                }
            }
            layer(.map) {
                NavigationStack(path: $mapPath) {
                    ForceMapView(isActive: tab == .map)
                        .routeDestinations()
                }
            }
            layer(.cabinet) {
                NavigationStack(path: $cabinetPath) {
                    CabinetView()
                        .routeDestinations()
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            TabBar(selection: $tab, badge: responsesTotal) { reselected in
                switch reselected {
                case .feed: feedPath.removeAll()
                case .map: mapPath.removeAll()
                case .cabinet: cabinetPath.removeAll()
                }
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
}

extension View {
    func routeDestinations() -> some View {
        navigationDestination(for: Route.self) { route in
            switch route {
            case .card(let id):
                CardDetailView(cardID: id)
            case .profile(let id):
                ProfileDetailView(profileID: id)
            case .respondent(let response):
                ProfileDetailView(profileID: response.userId, response: response)
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
                    .accessibilityValue(tab == .cabinet && badge > 0 ? "Откликов на ваши объявления: \(badge)" : "")
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
                if tab == .cabinet && badge > 0 {
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
            if tab != .feed {
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
                if !toast.message.isEmpty {
                    Text(toast.message)
                        .font(Typo.footnote)
                        .foregroundStyle(Palette.paper.opacity(0.78))
                        .fixedSize(horizontal: false, vertical: true)
                }
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
