import SpriteKit
import UIKit

// «Карта сил» на SpriteKit: силовой граф людей и ролей.
// Узлы отталкиваются друг от друга (закон Кулона), связи работают как пружины (закон Гука).
// Длина пружины зависит от совместимости — сильные совпадения оказываются ближе.

struct GraphNodeSpec {
    enum Style { case me, person, available, role }

    let id: String
    let label: String
    let style: Style
    let radius: CGFloat
    let pinned: Bool
}

struct GraphEdgeSpec {
    enum Weight: CaseIterable { case strong, medium, weak, accent }

    let from: String
    let to: String
    /// 0…1 — доля свободного радиуса сцены, добавляемая к минимальной длине.
    let reach: CGFloat
    let minLength: CGFloat
    let stiffness: CGFloat
    let weight: Weight
}

final class ForceGraphScene: SKScene {
    /// Вызывается при касании узла (nil — касание пустого места).
    var onSelect: ((String?) -> Void)?

    private final class Body {
        let id: String
        let label: String
        let node: SKNode
        let style: GraphNodeSpec.Style
        let radius: CGFloat
        let charge: CGFloat
        var pinned: Bool
        var velocity = CGVector.zero

        init(id: String, label: String, node: SKNode, style: GraphNodeSpec.Style, radius: CGFloat, charge: CGFloat, pinned: Bool) {
            self.id = id
            self.label = label
            self.node = node
            self.style = style
            self.radius = radius
            self.charge = charge
            self.pinned = pinned
        }
    }

    private struct Link {
        let a: Int
        let b: Int
        let reach: CGFloat
        let minLength: CGFloat
        let stiffness: CGFloat
        let weight: GraphEdgeSpec.Weight
    }

    private var bodies: [Body] = []
    private var indexByID: [String: Int] = [:]
    private var links: [Link] = []
    private var edgeShapes: [GraphEdgeSpec.Weight: SKShapeNode] = [:]
    private let edgeLayer = SKNode()
    private let nodeLayer = SKNode()
    private var selectionRing: SKShapeNode?
    private var selectedID: String?

    private var heat: CGFloat = 1
    private var lastTime: TimeInterval = 0
    private var dragIndex: Int?
    private var touchStart: CGPoint = .zero
    private var touchMoved = false
    private var isDark = false

    // Физика (единицы — пункты и секунды).
    private let repulsion: CGFloat = 1_400_000
    private let collision: CGFloat = 540
    private let centering: CGFloat = 4
    private let walls: CGFloat = 360
    private let maxSpeed: CGFloat = 1_200

    override init(size: CGSize) {
        super.init(size: size)
        setUpScene()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setUpScene()
    }

    private func setUpScene() {
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        scaleMode = .resizeFill
        backgroundColor = .clear
        edgeLayer.zPosition = 0
        nodeLayer.zPosition = 10
        addChild(edgeLayer)
        addChild(nodeLayer)
        for weight in GraphEdgeSpec.Weight.allCases {
            let shape = SKShapeNode()
            shape.lineCap = .round
            shape.isAntialiased = true
            shape.fillColor = .clear
            edgeLayer.addChild(shape)
            edgeShapes[weight] = shape
        }
        applyEdgeStyles()
    }

    override func didMove(to view: SKView) {
        isUserInteractionEnabled = true
        view.isMultipleTouchEnabled = false
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        heat = max(heat, 0.5)
    }

    // MARK: - Цвета

    private var inkColor: UIColor { isDark ? UIColor(hex: 0xEDEAE2) : UIColor(hex: 0x151514) }
    private var paperColor: UIColor { isDark ? UIColor(hex: 0x1B1B19) : UIColor(hex: 0xF8F6F0) }
    private var signalColor: UIColor { isDark ? UIColor(hex: 0xFF5C1A) : UIColor(hex: 0xFF4F00) }
    private let signalInk = UIColor(hex: 0x151514)

    func setDark(_ dark: Bool) {
        isDark = dark
        applyEdgeStyles()
        for body in bodies {
            applyStyle(to: body)
        }
        updateSelectionRing()
    }

    private func applyEdgeStyles() {
        for (weight, shape) in edgeShapes {
            switch weight {
            case .strong:
                shape.strokeColor = inkColor.withAlphaComponent(0.72)
                shape.lineWidth = 1.6
            case .medium:
                shape.strokeColor = inkColor.withAlphaComponent(0.4)
                shape.lineWidth = 1
            case .weak:
                shape.strokeColor = inkColor.withAlphaComponent(0.24)
                shape.lineWidth = 0.8
            case .accent:
                shape.strokeColor = signalColor
                shape.lineWidth = 1.8
            }
        }
    }

    // MARK: - Построение графа

    func setGraph(nodes: [GraphNodeSpec], edges: [GraphEdgeSpec]) {
        var previous: [String: CGPoint] = [:]
        for body in bodies {
            previous[body.id] = body.node.position
        }
        nodeLayer.removeAllChildren()
        selectionRing = nil
        bodies = []
        indexByID = [:]
        dragIndex = nil

        let spread = max(60, min(size.width, size.height) * 0.3)
        for spec in nodes {
            let node = makeNode(spec)
            if let prior = previous[spec.id] {
                node.position = prior
            } else if spec.pinned {
                node.position = .zero
            } else {
                let angle = CGFloat.random(in: 0..<(2 * CGFloat.pi))
                let distance = CGFloat.random(in: (spread * 0.5)...spread)
                node.position = CGPoint(x: cos(angle) * distance, y: sin(angle) * distance)
            }
            nodeLayer.addChild(node)
            let body = Body(
                id: spec.id,
                label: spec.label,
                node: node,
                style: spec.style,
                radius: spec.radius,
                charge: spec.style == .role ? 2.2 : 1,
                pinned: spec.pinned
            )
            indexByID[spec.id] = bodies.count
            bodies.append(body)
            applyStyle(to: body)
        }

        links = edges.compactMap { edge -> Link? in
            guard let a = indexByID[edge.from], let b = indexByID[edge.to], a != b else { return nil }
            return Link(a: a, b: b, reach: edge.reach, minLength: edge.minLength, stiffness: edge.stiffness, weight: edge.weight)
        }

        if let selectedID, indexByID[selectedID] == nil {
            self.selectedID = nil
        }
        updateSelectionRing()
        heat = 1
        redrawEdges()
    }

    private func makeNode(_ spec: GraphNodeSpec) -> SKNode {
        let container = SKNode()
        container.name = spec.id

        let shape: SKShapeNode
        if spec.style == .role {
            let side = spec.radius * 2
            shape = SKShapeNode(rectOf: CGSize(width: side, height: side))
        } else {
            shape = SKShapeNode(circleOfRadius: spec.radius)
        }
        shape.name = "shape"
        shape.lineWidth = spec.style == .me ? 2 : 1.4
        shape.isAntialiased = true
        container.addChild(shape)

        let label = SKLabelNode()
        label.name = "label"
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        container.addChild(label)

        if spec.style == .available {
            let dot = SKShapeNode(circleOfRadius: 3.5)
            dot.name = "dot"
            dot.position = CGPoint(x: spec.radius * 0.72, y: spec.radius * 0.72)
            dot.lineWidth = 1.5
            container.addChild(dot)
        }
        return container
    }

    private func applyStyle(to body: Body) {
        guard let shape = body.node.childNode(withName: "shape") as? SKShapeNode,
              let label = body.node.childNode(withName: "label") as? SKLabelNode else { return }
        let fill: UIColor
        let stroke: UIColor
        let text: UIColor
        switch body.style {
        case .me:
            fill = signalColor
            stroke = inkColor
            text = signalInk
        case .person, .available:
            fill = paperColor
            stroke = inkColor
            text = inkColor
        case .role:
            fill = inkColor
            stroke = inkColor
            text = paperColor
        }
        shape.fillColor = fill
        shape.strokeColor = stroke
        let fontSize: CGFloat = body.style == .person || body.style == .available ? 10.5 : 12
        label.attributedText = NSAttributedString(
            string: body.label,
            attributes: [
                .font: UIFont.monospacedSystemFont(ofSize: fontSize, weight: .bold),
                .foregroundColor: text
            ]
        )
        if let dot = body.node.childNode(withName: "dot") as? SKShapeNode {
            dot.fillColor = signalColor
            dot.strokeColor = paperColor
        }
    }

    // MARK: - Выделение

    func setSelection(_ id: String?) {
        selectedID = id
        updateSelectionRing()
    }

    private func updateSelectionRing() {
        selectionRing?.removeFromParent()
        selectionRing = nil
        guard let id = selectedID, let index = indexByID[id] else { return }
        let body = bodies[index]
        let ring: SKShapeNode
        if body.style == .role {
            let side = body.radius * 2 + 12
            ring = SKShapeNode(rectOf: CGSize(width: side, height: side))
        } else {
            ring = SKShapeNode(circleOfRadius: body.radius + 6)
        }
        ring.strokeColor = signalColor
        ring.fillColor = .clear
        ring.lineWidth = 2
        ring.zPosition = -1
        body.node.addChild(ring)
        let grow = SKAction.scale(to: 1.12, duration: 0.6)
        grow.timingMode = .easeInEaseOut
        let shrink = SKAction.scale(to: 1.0, duration: 0.6)
        shrink.timingMode = .easeInEaseOut
        ring.run(SKAction.repeatForever(SKAction.sequence([grow, shrink])))
        selectionRing = ring
    }

    // MARK: - Симуляция

    override func update(_ currentTime: TimeInterval) {
        let rawDelta = lastTime == 0 ? 1.0 / 60.0 : currentTime - lastTime
        lastTime = currentTime
        let dt = CGFloat(min(max(rawDelta, 1.0 / 240.0), 1.0 / 30.0))
        guard !bodies.isEmpty else { return }
        if heat < 0.004 && dragIndex == nil { return }
        step(dt)
        redrawEdges()
        if dragIndex == nil {
            heat *= pow(0.986, dt * 60)
        } else {
            heat = max(heat, 0.3)
        }
    }

    private func step(_ dt: CGFloat) {
        let count = bodies.count
        var forces = [CGVector](repeating: .zero, count: count)
        var positions = bodies.map { $0.node.position }

        // Отталкивание и столкновения.
        for i in 0..<count {
            for j in (i + 1)..<count {
                var dx = positions[i].x - positions[j].x
                var dy = positions[i].y - positions[j].y
                var distanceSquared = dx * dx + dy * dy
                if distanceSquared < 0.01 {
                    dx = CGFloat.random(in: -1...1)
                    dy = CGFloat.random(in: -1...1)
                    distanceSquared = dx * dx + dy * dy + 0.01
                }
                let distance = sqrt(distanceSquared)
                var magnitude = repulsion * bodies[i].charge * bodies[j].charge / max(distanceSquared, 400)
                let minimum = bodies[i].radius + bodies[j].radius + 10
                if distance < minimum {
                    magnitude += (minimum - distance) * collision
                }
                let fx = magnitude * dx / distance
                let fy = magnitude * dy / distance
                forces[i].dx += fx
                forces[i].dy += fy
                forces[j].dx -= fx
                forces[j].dy -= fy
            }
        }

        // Пружины.
        let halfWidth = max(size.width / 2 - 24, 40)
        let halfHeight = max(size.height / 2 - 24, 40)
        let span = max(min(halfWidth, halfHeight) - 16, 80)
        for link in links {
            let dx = positions[link.b].x - positions[link.a].x
            let dy = positions[link.b].y - positions[link.a].y
            let distance = max(sqrt(dx * dx + dy * dy), 0.01)
            let rest = link.minLength + link.reach * max(span - link.minLength, 0)
            let magnitude = link.stiffness * (distance - rest)
            let fx = magnitude * dx / distance
            let fy = magnitude * dy / distance
            forces[link.a].dx += fx
            forces[link.a].dy += fy
            forces[link.b].dx -= fx
            forces[link.b].dy -= fy
        }

        // Центрирование и мягкие стенки.
        for i in 0..<count {
            let point = positions[i]
            let r = bodies[i].radius
            forces[i].dx -= point.x * centering
            forces[i].dy -= point.y * centering
            if point.x > halfWidth - r { forces[i].dx -= (point.x - (halfWidth - r)) * walls }
            if point.x < -halfWidth + r { forces[i].dx += (-halfWidth + r - point.x) * walls }
            if point.y > halfHeight - r { forces[i].dy -= (point.y - (halfHeight - r)) * walls }
            if point.y < -halfHeight + r { forces[i].dy += (-halfHeight + r - point.y) * walls }
        }

        // Интегрирование (полунеявный Эйлер с затуханием).
        let damping = pow(0.82, dt * 60)
        for i in 0..<count {
            let body = bodies[i]
            if body.pinned || i == dragIndex {
                body.velocity = .zero
                continue
            }
            var vx = (body.velocity.dx + forces[i].dx * heat * dt) * damping
            var vy = (body.velocity.dy + forces[i].dy * heat * dt) * damping
            let speed = sqrt(vx * vx + vy * vy)
            if speed > maxSpeed {
                vx *= maxSpeed / speed
                vy *= maxSpeed / speed
            }
            body.velocity = CGVector(dx: vx, dy: vy)
            positions[i] = CGPoint(x: positions[i].x + vx * dt, y: positions[i].y + vy * dt)
            body.node.position = positions[i]
        }
    }

    private func redrawEdges() {
        var paths: [GraphEdgeSpec.Weight: CGMutablePath] = [:]
        for weight in GraphEdgeSpec.Weight.allCases {
            paths[weight] = CGMutablePath()
        }
        for link in links {
            guard let path = paths[link.weight] else { continue }
            path.move(to: bodies[link.a].node.position)
            path.addLine(to: bodies[link.b].node.position)
        }
        for (weight, path) in paths {
            guard let shape = edgeShapes[weight] else { continue }
            if weight == .weak {
                shape.path = path.copy(dashingWithPhase: 0, lengths: [4, 4])
            } else {
                shape.path = path
            }
        }
    }

    // MARK: - Касания

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)
        touchStart = point
        touchMoved = false
        dragIndex = hitIndex(at: point)
        if let index = dragIndex {
            bodies[index].velocity = .zero
            heat = max(heat, 0.3)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let index = dragIndex else { return }
        let point = touch.location(in: self)
        if hypot(point.x - touchStart.x, point.y - touchStart.y) > 6 {
            touchMoved = true
        }
        guard touchMoved else { return }
        let halfWidth = size.width / 2
        let halfHeight = size.height / 2
        bodies[index].node.position = CGPoint(
            x: min(max(point.x, -halfWidth), halfWidth),
            y: min(max(point.y, -halfHeight), halfHeight)
        )
        heat = max(heat, 0.3)
        redrawEdges()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if !touchMoved {
            let id = dragIndex.map { bodies[$0].id }
            setSelection(id)
            onSelect?(id)
        }
        dragIndex = nil
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        dragIndex = nil
    }

    private func hitIndex(at point: CGPoint) -> Int? {
        var bestIndex: Int?
        var bestDistance = CGFloat.greatestFiniteMagnitude
        for (index, body) in bodies.enumerated() {
            let position = body.node.position
            let distance = hypot(position.x - point.x, position.y - point.y)
            if distance <= body.radius + 14 && distance < bestDistance {
                bestDistance = distance
                bestIndex = index
            }
        }
        return bestIndex
    }
}
