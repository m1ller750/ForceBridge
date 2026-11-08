import SwiftUI

// Фирменный мотив — ферма Уоррена: команда как конструкция из панелей.
// Закрашенная панель — место занято, пунктирная — кого-то ещё не хватает.

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

    var framePath: Path {
        var path = Path()
        guard count > 0 else { return path }
        for index in 0..<count {
            path.addLines(triangle(index))
            path.closeSubpath()
        }
        return path
    }

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

/// Компактный глиф для списков: сколько людей ищут и сколько уже есть.
struct TrussGlyph: View {
    /// true — место занято, false — ищут человека.
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
        .accessibilityHidden(true)
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

/// Индикатор работы ИИ: по ферме бежит оранжевая панель.
struct TrussScanner: View {
    var panels: Int = 9
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.12)) { timeline in
            let step = reduceMotion ? 0 : Int(timeline.date.timeIntervalSinceReferenceDate / 0.12) % (panels * 2)
            let active = step < panels ? step : panels * 2 - step - 1
            TrussGlyph(states: (0..<panels).map { $0 != active })
        }
        .accessibilityHidden(true)
    }
}
