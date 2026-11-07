import SwiftUI
import SpriteKit

/// Держатель сцены: создаётся один раз на жизнь вкладки.
@MainActor
final class ForceSceneHolder: ObservableObject {
    let scene: ForceGraphScene

    init() {
        scene = ForceGraphScene(size: CGSize(width: 390, height: 600))
    }
}

@MainActor
struct ForceMapView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var colorScheme
    let isActive: Bool
    @StateObject private var holder = ForceSceneHolder()
    @State private var mode: Mode = .match
    @State private var selectedID: String?

    enum Mode: String, CaseIterable, Identifiable {
        case match, roles

        var id: String { rawValue }

        var title: String {
            switch self {
            case .match: return "Совместимость"
            case .roles: return "Роли и мосты"
            }
        }
    }

    private enum Selection {
        case me(Person)
        case person(Person)
        case role(Role)
    }

    /// Меняется, когда меняются данные, влияющие на граф.
    private var graphSignature: Int {
        var hasher = Hasher()
        hasher.combine(store.me)
        hasher.combine(store.teams)
        hasher.combine(store.people)
        return hasher.finalize()
    }

    private var selection: Selection? {
        guard let id = selectedID else { return nil }
        if id == "me", let me = store.me { return .me(me) }
        if id.hasPrefix("p:"), let uuid = UUID(uuidString: String(id.dropFirst(2))), let person = store.person(uuid) {
            return .person(person)
        }
        if id.hasPrefix("r:"), let role = Role(rawValue: String(id.dropFirst(2))) {
            return .role(role)
        }
        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ZStack(alignment: .bottom) {
                BlueprintGrid()
                SpriteView(scene: holder.scene, isPaused: !isActive, options: [.allowsTransparency])
                    .accessibilityLabel(mode == .match ? "Граф совместимости участников" : "Граф ролей")
                if let selection {
                    selectionCard(selection)
                        .padding(12)
                        .contentColumn()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .clipped()
            .overlay(alignment: .top) { Hairline(color: Palette.lineStrong) }
            legend
        }
        .paperBackground()
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            holder.scene.setDark(colorScheme == .dark)
            holder.scene.onSelect = { id in
                withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                    selectedID = id
                }
            }
            rebuild()
        }
        .onChange(of: mode) {
            selectedID = nil
            holder.scene.setSelection(nil)
            rebuild()
        }
        .onChange(of: colorScheme) { _, newValue in
            holder.scene.setDark(newValue == .dark)
        }
        .onChange(of: graphSignature) {
            rebuild()
        }
        .sensoryFeedback(.selection, trigger: selectedID)
    }

    // MARK: Шапка и легенда

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                MonoLabel("ForceBridge / 03", color: Palette.faint)
                Spacer()
                MonoLabel("Перетаскивайте узлы", color: Palette.faint)
            }
            Text("Карта сил")
                .font(Typo.display(36, weight: .heavy))
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            Text(mode == .match
                 ? "Связи — пружины. Чем сильнее человек дополняет вас, тем короче пружина и ближе узел."
                 : "Люди притягиваются к своим ролям. Тот, кто связывает несколько кластеров, — мост между дисциплинами.")
                .font(Typo.subhead)
                .foregroundStyle(Palette.graphite)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                ForEach(Mode.allCases) { item in
                    Chip(title: item.title, isOn: mode == item) {
                        mode = item
                    }
                }
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.top, 12)
        .padding(.bottom, 14)
        .contentColumn()
    }

    private var legend: some View {
        HStack(spacing: 16) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Palette.signal)
                    .overlay { Circle().strokeBorder(Palette.ink, lineWidth: 1) }
                    .frame(width: 11, height: 11)
                MonoLabel("Вы", size: 9.5)
            }
            HStack(spacing: 6) {
                Circle()
                    .strokeBorder(Palette.ink, lineWidth: 1)
                    .frame(width: 11, height: 11)
                    .overlay(alignment: .topTrailing) {
                        Circle().fill(Palette.signal).frame(width: 5, height: 5).offset(x: 1, y: -1)
                    }
                MonoLabel("Ищет команду", size: 9.5)
            }
            if mode == .roles {
                HStack(spacing: 6) {
                    Rectangle()
                        .fill(Palette.ink)
                        .frame(width: 10, height: 10)
                    MonoLabel("Роль", size: 9.5)
                }
            } else {
                HStack(spacing: 6) {
                    Rectangle()
                        .fill(Palette.signal)
                        .frame(width: 14, height: 2)
                    MonoLabel("Топ-3", size: 9.5)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.vertical, 10)
        .contentColumn()
        .overlay(alignment: .top) { Hairline(color: Palette.lineStrong) }
        .accessibilityHidden(true)
    }

    // MARK: Карточка выбранного узла

    @ViewBuilder
    private func selectionCard(_ selection: Selection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            switch selection {
            case .me(let me):
                meCard(me)
            case .person(let person):
                personCard(person)
            case .role(let role):
                roleCard(role)
            }
        }
        .padding(14)
        .background(Palette.paper)
        .overlay { Rectangle().strokeBorder(Palette.ink, lineWidth: 1.2) }
        .overlay(alignment: .topTrailing) {
            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    selectedID = nil
                }
                holder.scene.setSelection(nil)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Palette.graphite)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Закрыть")
        }
    }

    private func personCard(_ person: Person) -> some View {
        let report = store.match(for: person)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Monogram(initials: person.initials, size: 40)
                VStack(alignment: .leading, spacing: 3) {
                    Text(person.name)
                        .font(Typo.headline)
                        .foregroundStyle(Palette.ink)
                    Text(person.headline)
                        .font(Typo.footnote)
                        .foregroundStyle(Palette.graphite)
                        .lineLimit(2)
                    HStack(spacing: 4) {
                        ForEach(person.roles) { role in
                            RoleCode(role: role)
                        }
                    }
                    .padding(.top, 2)
                }
                Spacer(minLength: 28)
            }
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(report.reasons.prefix(2)), id: \.self) { reason in
                        Text(reason)
                            .font(Typo.footnote)
                            .foregroundStyle(Palette.ink)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 6) {
                    ScoreBadge(score: report.total)
                    NavigationLink(value: Route.person(person.id)) {
                        HStack(spacing: 6) {
                            Text("ПРОФИЛЬ")
                                .font(Typo.mono(11, weight: .bold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(Palette.onSignal)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Palette.signal)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func meCard(_ me: Person) -> some View {
        let strong = store.rankedPeople.filter { $0.report.total >= 70 }.count
        return VStack(alignment: .leading, spacing: 8) {
            MonoLabel("Это вы", color: Palette.signal, weight: .bold)
            Text(me.name)
                .font(Typo.headline)
                .foregroundStyle(Palette.ink)
            Text("Сильных совпадений рядом: \(strong). Оранжевые связи ведут к трём лучшим кандидатам.")
                .font(Typo.footnote)
                .foregroundStyle(Palette.graphite)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.trailing, 24)
        }
    }

    private func roleCard(_ role: Role) -> some View {
        let holders = store.people.filter { $0.roles.contains(role) }
        let vacancies = store.teams.reduce(0) { total, team in
            total + team.openSlots.filter { $0.role == role }.count
        }
        let bridges = holders.filter { $0.roles.count > 1 }.count
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(role.code)
                    .font(Typo.display(26, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                Text(role.title)
                    .font(Typo.subhead.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                    .padding(.trailing, 24)
            }
            HStack(spacing: 18) {
                stat(value: holders.count, label: Fmt.plural(holders.count, "человек", "человека", "человек"))
                stat(value: vacancies, label: Fmt.plural(vacancies, "вакансия", "вакансии", "вакансий"), accent: vacancies > 0)
                stat(value: bridges, label: Fmt.plural(bridges, "мост", "моста", "мостов"))
            }
        }
    }

    private func stat(value: Int, label: String, accent: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(Typo.display(22, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(accent ? Palette.signal : Palette.ink)
            MonoLabel(label, size: 9.5)
        }
    }

    // MARK: Построение графа

    private func rebuild() {
        guard let me = store.me else { return }
        var nodes: [GraphNodeSpec] = [
            GraphNodeSpec(id: "me", label: "ВЫ", style: .me, radius: 24, pinned: mode == .match)
        ]
        var edges: [GraphEdgeSpec] = []

        switch mode {
        case .match:
            let ranked = Array(store.rankedPeople.prefix(16))
            for (index, item) in ranked.enumerated() {
                let id = "p:" + item.person.id.uuidString
                let score = CGFloat(item.report.fraction)
                nodes.append(GraphNodeSpec(
                    id: id,
                    label: item.person.initials,
                    style: item.person.isLookingForTeam ? .available : .person,
                    radius: 15 + 7 * score,
                    pinned: false
                ))
                let weight: GraphEdgeSpec.Weight
                if index < 3 {
                    weight = .accent
                } else if score >= 0.7 {
                    weight = .strong
                } else if score >= 0.45 {
                    weight = .medium
                } else {
                    weight = .weak
                }
                edges.append(GraphEdgeSpec(from: "me", to: id, reach: 1 - score, minLength: 72, stiffness: 36, weight: weight))
            }
            // Те, кто уже в одной команде, слегка притягиваются друг к другу.
            let shown = Set(ranked.map { $0.person.id })
            for team in store.teams {
                let members = team.memberIDs.filter { shown.contains($0) }
                guard members.count > 1 else { continue }
                for i in 0..<(members.count - 1) {
                    for j in (i + 1)..<members.count {
                        edges.append(GraphEdgeSpec(
                            from: "p:" + members[i].uuidString,
                            to: "p:" + members[j].uuidString,
                            reach: 0,
                            minLength: 80,
                            stiffness: 6,
                            weight: .weak
                        ))
                    }
                }
            }

        case .roles:
            for role in Role.allCases {
                nodes.append(GraphNodeSpec(id: "r:" + role.rawValue, label: role.code, style: .role, radius: 20, pinned: false))
            }
            for person in store.people {
                let id = "p:" + person.id.uuidString
                nodes.append(GraphNodeSpec(
                    id: id,
                    label: person.initials,
                    style: person.isLookingForTeam ? .available : .person,
                    radius: 14,
                    pinned: false
                ))
                for (index, role) in person.roles.enumerated() {
                    edges.append(GraphEdgeSpec(
                        from: id,
                        to: "r:" + role.rawValue,
                        reach: 0,
                        minLength: index == 0 ? 52 : 92,
                        stiffness: index == 0 ? 36 : 14,
                        weight: index == 0 ? .medium : .weak
                    ))
                }
            }
            for (index, role) in me.roles.enumerated() {
                edges.append(GraphEdgeSpec(
                    from: "me",
                    to: "r:" + role.rawValue,
                    reach: 0,
                    minLength: index == 0 ? 58 : 92,
                    stiffness: index == 0 ? 36 : 14,
                    weight: .accent
                ))
            }
        }

        holder.scene.setGraph(nodes: nodes, edges: edges)
    }
}

/// Чертёжная сетка под графом.
struct BlueprintGrid: View {
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 24
            let centerX = size.width / 2
            let centerY = size.height / 2
            var minor = Path()
            var major = Path()

            var index = 0
            var x = centerX
            while x <= size.width {
                addVertical(x, index: index, height: size.height, minor: &minor, major: &major)
                x += step
                index += 1
            }
            index = 1
            x = centerX - step
            while x >= 0 {
                addVertical(x, index: index, height: size.height, minor: &minor, major: &major)
                x -= step
                index += 1
            }

            index = 0
            var y = centerY
            while y <= size.height {
                addHorizontal(y, index: index, width: size.width, minor: &minor, major: &major)
                y += step
                index += 1
            }
            index = 1
            y = centerY - step
            while y >= 0 {
                addHorizontal(y, index: index, width: size.width, minor: &minor, major: &major)
                y -= step
                index += 1
            }

            context.stroke(minor, with: .color(Palette.line), lineWidth: 0.5)
            context.stroke(major, with: .color(Palette.lineStrong), lineWidth: 0.5)

            var cross = Path()
            cross.move(to: CGPoint(x: centerX - 8, y: centerY))
            cross.addLine(to: CGPoint(x: centerX + 8, y: centerY))
            cross.move(to: CGPoint(x: centerX, y: centerY - 8))
            cross.addLine(to: CGPoint(x: centerX, y: centerY + 8))
            context.stroke(cross, with: .color(Palette.signal), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }

    private func addVertical(_ x: CGFloat, index: Int, height: CGFloat, minor: inout Path, major: inout Path) {
        if index % 5 == 0 {
            major.move(to: CGPoint(x: x, y: 0))
            major.addLine(to: CGPoint(x: x, y: height))
        } else {
            minor.move(to: CGPoint(x: x, y: 0))
            minor.addLine(to: CGPoint(x: x, y: height))
        }
    }

    private func addHorizontal(_ y: CGFloat, index: Int, width: CGFloat, minor: inout Path, major: inout Path) {
        if index % 5 == 0 {
            major.move(to: CGPoint(x: 0, y: y))
            major.addLine(to: CGPoint(x: width, y: y))
        } else {
            minor.move(to: CGPoint(x: 0, y: y))
            minor.addLine(to: CGPoint(x: width, y: y))
        }
    }
}
