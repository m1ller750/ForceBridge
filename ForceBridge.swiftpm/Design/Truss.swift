import SwiftUI

// Команда изображается как ферма Уоррена: каждая роль — треугольная панель.
// Закрашенная панель — роль закрыта участником, пунктирная — вакансия.

struct TrussGeometry {
    let count: Int
    let rect: CGRect

    var panelWidth: CGFloat {
        rect.width * 2 / CGFloat(max(count, 1) + 1)
    }

    /// Вершины i-го треугольника: чётные смотрят вершиной вверх, нечётные — вниз.
    func triangle(_ index: Int) -> [CGPoint] {
        let w = panelWidth
        let x0 = rect.minX
        if index % 2 == 0 {
            let k = CGFloat(index / 2)
            return [
                CGPoint(x: x0 + k * w, y: rect.maxY),
                CGPoint(x: x0 + (k + 1) * w, y: rect.maxY),
                CGPoint(x: x0 + (k + 0.5) * w, y: rect.minY)
            ]
        } else {
            let k = CGFloat((index - 1) / 2)
            return [
                CGPoint(x: x0 + (k + 0.5) * w, y: rect.minY),
                CGPoint(x: x0 + (k + 1.5) * w, y: rect.minY),
                CGPoint(x: x0 + (k + 1) * w, y: rect.maxY)
            ]
        }
    }

    func centroid(_ index: Int) -> CGPoint {
        let t = triangle(index)
        return CGPoint(x: (t[0].x + t[1].x + t[2].x) / 3, y: (t[0].y + t[1].y + t[2].y) / 3)
    }

    /// Треугольник, сжатый к центру масс, — «панель» внутри рамы.
    func panel(_ index: Int, shrink: CGFloat) -> [CGPoint] {
        let c = centroid(index)
        return triangle(index).map { point in
            CGPoint(x: c.x + (point.x - c.x) * shrink, y: c.y + (point.y - c.y) * shrink)
        }
    }

    /// Рама фермы: все рёбра треугольников.
    var framePath: Path {
        var path = Path()
        guard count > 0 else { return path }
        for index in 0..<count {
            path.addLines(triangle(index))
            path.closeSubpath()
        }
        return path
    }

    /// Уникальные узлы фермы.
    var nodes: [CGPoint] {
        guard count > 0 else { return [] }
        var result: [CGPoint] = []
        for index in 0..<count {
            for point in triangle(index) {
                let exists = result.contains { abs($0.x - point.x) < 0.5 && abs($0.y - point.y) < 0.5 }
                if !exists { result.append(point) }
            }
        }
        return result
    }
}

struct PolygonShape: Shape {
    var points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }
}

/// Компактный глиф состава команды для списков.
struct TrussGlyph: View {
    /// true — роль закрыта, false — вакансия.
    let states: [Bool]
    var lineWidth: CGFloat = 1

    var body: some View {
        Canvas { context, size in
            guard !states.isEmpty else { return }
            let inset: CGFloat = 1
            let geometry = TrussGeometry(
                count: states.count,
                rect: CGRect(x: inset, y: inset, width: size.width - inset * 2, height: size.height - inset * 2)
            )
            context.stroke(geometry.framePath, with: .color(Palette.ink), lineWidth: lineWidth)
            for (index, filled) in states.enumerated() {
                let panel = PolygonShape(points: geometry.panel(index, shrink: 0.5)).path(in: .zero)
                if filled {
                    context.fill(panel, with: .color(Palette.ink))
                } else {
                    context.fill(panel, with: .color(Palette.signalSoft))
                    context.stroke(panel, with: .color(Palette.signal), style: StrokeStyle(lineWidth: lineWidth, dash: [2.5, 2]))
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Состав команды: занято \(states.filter { $0 }.count) из \(states.count)")
    }
}

/// Большая интерактивная схема команды.
struct TrussDiagram: View {
    let slots: [Slot]
    let memberInitials: (Slot) -> String?
    @Binding var selection: UUID?
    @State private var assembled = false

    var body: some View {
        GeometryReader { proxy in
            let rect = CGRect(x: 10, y: 12, width: proxy.size.width - 20, height: proxy.size.height - 24)
            let truss = TrussGeometry(count: slots.count, rect: rect)
            ZStack(alignment: .topLeading) {
                truss.framePath
                    .stroke(Palette.ink, lineWidth: 1.4)
                ForEach(Array(slots.enumerated()), id: \.element.id) { index, slot in
                    panel(index: index, slot: slot, truss: truss, size: proxy.size)
                }
                ForEach(Array(truss.nodes.enumerated()), id: \.offset) { _, point in
                    Circle()
                        .fill(Palette.paper)
                        .overlay { Circle().strokeBorder(Palette.ink, lineWidth: 1.4) }
                        .frame(width: 9, height: 9)
                        .position(point)
                        .allowsHitTesting(false)
                }
            }
        }
        .onAppear {
            assembled = true
        }
    }

    @ViewBuilder
    private func panel(index: Int, slot: Slot, truss: TrussGeometry, size: CGSize) -> some View {
        let points = truss.panel(index, shrink: 0.78)
        let center = truss.centroid(index)
        let filled = slot.memberID != nil
        let isSelected = selection == slot.id
        let anchor = UnitPoint(
            x: size.width > 0 ? center.x / size.width : 0.5,
            y: size.height > 0 ? center.y / size.height : 0.5
        )
        ZStack(alignment: .topLeading) {
            PolygonShape(points: points)
                .fill(filled ? Palette.ink : Palette.signalSoft)
            PolygonShape(points: points)
                .stroke(
                    isSelected ? Palette.signal : (filled ? Palette.ink : Palette.signal),
                    style: StrokeStyle(lineWidth: isSelected ? 3 : 1.2, dash: filled || isSelected ? [] : [4, 3])
                )
            VStack(spacing: 1) {
                Text(slot.role.code)
                    .font(Typo.mono(11, weight: .bold))
                if let initials = memberInitials(slot) {
                    Text(initials)
                        .font(Typo.mono(9, weight: .medium))
                        .opacity(0.75)
                } else {
                    Text("—")
                        .font(Typo.mono(9, weight: .medium))
                }
            }
            .foregroundStyle(filled ? Palette.paper : Palette.signal)
            .position(center)
            .allowsHitTesting(false)
        }
        .contentShape(PolygonShape(points: truss.triangle(index)))
        .onTapGesture {
            selection = (selection == slot.id) ? nil : slot.id
        }
        .scaleEffect(assembled ? 1 : 0.4, anchor: anchor)
        .opacity(assembled ? 1 : 0)
        .animation(.spring(response: 0.5, dampingFraction: 0.72).delay(Double(index) * 0.07), value: assembled)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText(slot))
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityAction {
            selection = (selection == slot.id) ? nil : slot.id
        }
    }

    private func accessibilityText(_ slot: Slot) -> String {
        if slot.memberID != nil {
            return "\(slot.role.title): занято"
        }
        return "\(slot.role.title): вакансия"
    }
}
