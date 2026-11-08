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

/// «Карта сил» на SpriteKit.
/// Режим «Категории»: объявления притягиваются к категориям, которые выбрал ИИ;
/// объявление сразу в нескольких категориях становится мостом между кластерами.
/// Режим «Совместимость»: вы в центре, чем выше процент ИИ — тем короче пружина.
struct ForceMapView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var colorScheme
    let isActive: Bool
    @StateObject private var holder = ForceSceneHolder()
    @State private var mode: Mode = .categories
    @State private var selectedID: String?

    enum Mode: String, CaseIterable, Identifiable {
        case categories, match

        var id: String { rawValue }

        var title: String {
            switch self {
            case .categories: return "Категории и мосты"
            case .match: return "Совместимость"
            }
        }
    }

    private enum Selection {
        case card(Card)
        case category(CategoryInfo, Int)
        case me
    }

    private var mapCards: [Card] {
        Array(store.feed.prefix(40))
    }

    private var scoredCards: [Card] {
        store.feed.filter { store.compat[$0.id] != nil }
    }

    private var graphSignature: Int {
        var hasher = Hasher()
        hasher.combine(mode)
        for card in mapCards {
            hasher.combine(card.id)
            hasher.combine(card.categories)
            hasher.combine(store.compat[card.id]?.score)
        }
        return hasher.finalize()
    }

    private var selection: Selection? {
        guard let id = selectedID else { return nil }
        if id == "me" { return .me }
        if id.hasPrefix("c:"), let uuid = UUID(uuidString: String(id.dropFirst(2))), let card = store.card(id: uuid) {
            return .card(card)
        }
        if id.hasPrefix("k:"), let category = store.category(String(id.dropFirst(2))) {
            let count = mapCards.filter { $0.categories.contains(category.key) }.count
            return .category(category, count)
        }
        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ZStack(alignment: .bottom) {
                BlueprintGrid()
                SpriteView(scene: holder.scene, isPaused: !isActive, options: [.allowsTransparency])
                    .accessibilityLabel(mode == .categories ? "Граф объявлений по категориям" : "Граф совместимости")
                if mode == .match && scoredCards.isEmpty {
                    matchPrompt
                        .padding(12)
                        .contentColumn()
                }
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
                MonoLabel("ForceBridge / 02", color: Palette.faint)
                Spacer()
                MonoLabel("Перетаскивайте узлы", color: Palette.faint)
            }
            Text("Карта сил")
                .font(Typo.display(36, weight: .heavy))
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            Text(mode == .categories
                 ? "Объявления притягиваются к категориям, которые выбрал ИИ. Карточка сразу в нескольких категориях — мост между областями."
                 : "Вы в центре. Связи — пружины: чем выше совместимость по оценке ИИ, тем ближе объявление.")
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
            if mode == .categories {
                HStack(spacing: 6) {
                    Rectangle()
                        .fill(Palette.ink)
                        .frame(width: 10, height: 10)
                    MonoLabel("Категория ИИ", size: 9.5)
                }
                HStack(spacing: 6) {
                    Circle()
                        .strokeBorder(Palette.ink, lineWidth: 1)
                        .frame(width: 11, height: 11)
                    MonoLabel("Объявление", size: 9.5)
                }
            } else {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Palette.signal)
                        .overlay { Circle().strokeBorder(Palette.ink, lineWidth: 1) }
                        .frame(width: 11, height: 11)
                    MonoLabel("Вы", size: 9.5)
                }
                HStack(spacing: 6) {
                    Rectangle()
                        .fill(Palette.signal)
                        .frame(width: 14, height: 2)
                    MonoLabel("Топ-3", size: 9.5)
                }
            }
            HStack(spacing: 6) {
                Circle()
                    .strokeBorder(Palette.ink, lineWidth: 1)
                    .frame(width: 11, height: 11)
                    .overlay(alignment: .topTrailing) {
                        Circle().fill(Palette.signal).frame(width: 5, height: 5).offset(x: 1, y: -1)
                    }
                MonoLabel("70%+", size: 9.5)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.vertical, 10)
        .contentColumn()
        .overlay(alignment: .top) { Hairline(color: Palette.lineStrong) }
        .accessibilityHidden(true)
    }

    private var matchPrompt: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                AIBadge()
                MonoLabel("Совместимость ещё не посчитана", color: Palette.ink, size: 10.5, weight: .semibold)
            }
            Text("ИИ оценит, насколько вы подходите под последние объявления. Это займёт несколько секунд.")
                .font(Typo.footnote)
                .foregroundStyle(Palette.graphite)
                .fixedSize(horizontal: false, vertical: true)
            Button(store.compatLoading.isEmpty ? "Рассчитать для 12 объявлений" : "ИИ считает…") {
                Task { await store.prefetchCompatibility(for: Array(store.feed.prefix(12))) }
            }
            .buttonStyle(.signal)
            .disabled(!store.compatLoading.isEmpty || store.feed.isEmpty)
        }
        .padding(14)
        .background(Palette.paper)
        .overlay { Rectangle().strokeBorder(Palette.ink, lineWidth: 1.2) }
    }

    // MARK: Карточка выбранного узла

    @ViewBuilder
    private func selectionCard(_ selection: Selection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            switch selection {
            case .card(let card):
                cardInfo(card)
            case .category(let category, let count):
                categoryInfo(category, count: count)
            case .me:
                meInfo
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

    private func cardInfo(_ card: Card) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                KindTag(kind: card.kind)
                Spacer(minLength: 28)
            }
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(card.title)
                        .font(Typo.headline)
                        .foregroundStyle(Palette.ink)
                        .lineLimit(2)
                    Text([card.authorName ?? "", card.placeText].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(Typo.footnote)
                        .foregroundStyle(Palette.graphite)
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                if let score = store.compat[card.id]?.score {
                    ScoreBadge(score: score)
                }
            }
            CategoryStrip(card: card)
            NavigationLink(value: Route.card(card.id)) {
                HStack(spacing: 6) {
                    Text("ОТКРЫТЬ")
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

    private func categoryInfo(_ category: CategoryInfo, count: Int) -> some View {
        let bridges = mapCards.filter { $0.categories.contains(category.key) && $0.categories.count > 1 }.count
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(category.code)
                    .font(Typo.display(24, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                Text(category.title)
                    .font(Typo.subhead.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                    .padding(.trailing, 24)
            }
            HStack(spacing: 18) {
                stat(count, Fmt.plural(count, "объявление", "объявления", "объявлений"))
                stat(bridges, Fmt.plural(bridges, "мост", "моста", "мостов"))
            }
            Button("Показать в ленте") {
                store.selectedCategories = [category.key]
                store.showToast("Фильтр включён", "Во вкладке «Объявления» — только «\(category.title)».")
            }
            .buttonStyle(.outlineCompact)
        }
    }

    private var meInfo: some View {
        let strong = store.compat.values.filter { $0.score >= 70 }.count
        return VStack(alignment: .leading, spacing: 6) {
            MonoLabel("Это вы", color: Palette.signal, weight: .bold)
            Text(store.me?.fullName ?? "")
                .font(Typo.headline)
                .foregroundStyle(Palette.ink)
            Text("Объявлений с совместимостью 70% и выше: \(strong). Оранжевые связи ведут к трём лучшим.")
                .font(Typo.footnote)
                .foregroundStyle(Palette.graphite)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.trailing, 24)
        }
    }

    private func stat(_ value: Int, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(Typo.display(22, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(Palette.ink)
            MonoLabel(label, size: 9.5)
        }
    }

    // MARK: Построение графа

    private func rebuild() {
        var nodes: [GraphNodeSpec] = []
        var edges: [GraphEdgeSpec] = []

        switch mode {
        case .categories:
            let cards = mapCards
            let used = Set(cards.flatMap { $0.categories })
            for category in store.categories where used.contains(category.key) {
                nodes.append(GraphNodeSpec(id: "k:" + category.key, label: category.code, style: .role, radius: 20, pinned: false))
            }
            for card in cards {
                let id = "c:" + card.id.uuidString
                let score = store.compat[card.id]?.score
                nodes.append(GraphNodeSpec(
                    id: id,
                    label: score.map { "\($0)" } ?? shortCode(card.kind),
                    style: (score ?? 0) >= 70 ? .available : .person,
                    radius: 15,
                    pinned: false
                ))
                for (index, key) in card.categories.enumerated() where used.contains(key) {
                    edges.append(GraphEdgeSpec(
                        from: id,
                        to: "k:" + key,
                        reach: 0,
                        minLength: index == 0 ? 54 : 88,
                        stiffness: index == 0 ? 36 : 16,
                        weight: card.categories.count > 1 ? .strong : .medium
                    ))
                }
            }

        case .match:
            nodes.append(GraphNodeSpec(id: "me", label: "ВЫ", style: .me, radius: 24, pinned: true))
            let ranked = scoredCards
                .sorted { (store.compat[$0.id]?.score ?? 0) > (store.compat[$1.id]?.score ?? 0) }
                .prefix(18)
            for (index, card) in ranked.enumerated() {
                let score = store.compat[card.id]?.score ?? 0
                let fraction = CGFloat(score) / 100
                let id = "c:" + card.id.uuidString
                nodes.append(GraphNodeSpec(
                    id: id,
                    label: "\(score)",
                    style: score >= 70 ? .available : .person,
                    radius: 15 + 7 * fraction,
                    pinned: false
                ))
                let weight: GraphEdgeSpec.Weight
                if index < 3 {
                    weight = .accent
                } else if score >= 70 {
                    weight = .strong
                } else if score >= 45 {
                    weight = .medium
                } else {
                    weight = .weak
                }
                edges.append(GraphEdgeSpec(from: "me", to: id, reach: 1 - fraction, minLength: 72, stiffness: 36, weight: weight))
            }
        }

        holder.scene.setGraph(nodes: nodes, edges: edges)
    }

    private func shortCode(_ kind: CardKind) -> String {
        switch kind {
        case .teammate: return "TM"
        case .research: return "RS"
        case .join: return "JN"
        }
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
