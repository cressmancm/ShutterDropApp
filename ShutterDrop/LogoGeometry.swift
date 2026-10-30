import CoreGraphics

/// ShutterDrop's mark on a 100-unit grid, y down: a seven-blade iris, partly
/// closed, with a drop in the opening.
///
/// It is drawn the way a real iris works. Each blade's edge is one circular
/// arc that forms a side of the opening and sweeps on out to the rim, so the
/// opening is a rounded heptagon and the edges pinwheel. Every blade is the
/// same, because each lies over one neighbour and under the other.
///
/// The app icon, the README logo and the lockups in docs/brand are rendered
/// from this file too, so keep it free of UIKit and SwiftUI.
nonisolated enum LogoGeometry {
    static let bladeCount = 7
    /// Where the blades meet the barrel.
    static let rimRadius: CGFloat = 38
    /// The corners of the opening.
    static let openingRadius: CGFloat = 19
    /// The curve of each blade edge.
    static let edgeRadius: CGFloat = 44
    /// The line between blades, drawn in the tile colour.
    static let gap: CGFloat = 1.6
    static let tileCornerRadius: CGFloat = 22.4

    private static let centre = CGPoint(x: 50, y: 50)

    /// One closed path per blade: the part of it you can see.
    static func blades() -> [CGPath] {
        let corners = (0..<bladeCount).map { i -> CGPoint in
            let a = (-90 + CGFloat(i) * 360 / CGFloat(bladeCount)) * .pi / 180
            return CGPoint(x: centre.x + openingRadius * cos(a), y: centre.y + openingRadius * sin(a))
        }
        let edges = (0..<bladeCount).map { edge(from: corners[$0], to: corners[($0 + 1) % bladeCount]) }
        return (0..<bladeCount).map { i in
            let over = edges[i], own = edges[(i + 1) % bladeCount]   // the neighbour's edge lies over this blade
            let path = CGMutablePath()
            path.move(to: over.end)
            path.addArc(center: over.circle, radius: edgeRadius, startAngle: angle(over.end, over.circle),
                        endAngle: angle(over.rim, over.circle), clockwise: !over.forward)
            path.addArc(center: centre, radius: rimRadius, startAngle: angle(over.rim, centre),
                        endAngle: angle(own.rim, centre), clockwise: false)
            path.addArc(center: own.circle, radius: edgeRadius, startAngle: angle(own.rim, own.circle),
                        endAngle: angle(own.start, own.circle), clockwise: own.forward)
            path.closeSubpath()
            return path
        }
    }

    /// A drop centred in the opening: a round base of radius 9 with its tip
    /// 18 above the base's centre; the sides are tangents from the tip.
    static func drop() -> CGPath {
        let radius: CGFloat = 9, tip: CGFloat = 18
        let base = CGPoint(x: 50, y: 50 + (tip - radius) / 2)
        let phi = acos(radius / tip)
        let path = CGMutablePath()
        path.move(to: CGPoint(x: base.x, y: base.y - tip))
        path.addArc(center: base, radius: radius, startAngle: -.pi / 2 + phi, endAngle: -.pi / 2 - phi, clockwise: false)
        path.closeSubpath()
        return path
    }

    /// A blade edge: the arc of radius `edgeRadius` through two neighbouring
    /// corners of the opening, bulging outward, carried on to the rim.
    private struct Edge {
        let start: CGPoint, end: CGPoint, rim: CGPoint, circle: CGPoint
        /// Whether start to end runs the way angles increase.
        let forward: Bool
    }

    private static func edge(from start: CGPoint, to end: CGPoint) -> Edge {
        let mid = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
        let halfChord = hypot(end.x - start.x, end.y - start.y) / 2
        let toCentre = hypot(centre.x - mid.x, centre.y - mid.y)
        let offset = (edgeRadius * edgeRadius - halfChord * halfChord).squareRoot()
        let circle = CGPoint(x: mid.x + (centre.x - mid.x) / toCentre * offset,
                             y: mid.y + (centre.y - mid.y) / toCentre * offset)
        let forward = normalized(angle(end, circle) - angle(start, circle) + .pi) - .pi > 0

        // The two places this edge's circle crosses the rim; keep the one reached first going on from `end`.
        let dx = centre.x - circle.x, dy = centre.y - circle.y, d = hypot(dx, dy)
        let along = (edgeRadius * edgeRadius - rimRadius * rimRadius + d * d) / (2 * d)
        let across = (edgeRadius * edgeRadius - along * along).squareRoot()
        let foot = CGPoint(x: circle.x + along * dx / d, y: circle.y + along * dy / d)
        let crossings = [CGPoint(x: foot.x + across * dy / d, y: foot.y - across * dx / d),
                         CGPoint(x: foot.x - across * dy / d, y: foot.y + across * dx / d)]
        let travel = { (p: CGPoint) in normalized((forward ? 1 : -1) * (angle(p, circle) - angle(end, circle))) }
        let rim = travel(crossings[0]) < travel(crossings[1]) ? crossings[0] : crossings[1]
        return Edge(start: start, end: end, rim: rim, circle: circle, forward: forward)
    }

    private static func angle(_ p: CGPoint, _ c: CGPoint) -> CGFloat { atan2(p.y - c.y, p.x - c.x) }

    private static func normalized(_ a: CGFloat) -> CGFloat {
        let turn = 2 * CGFloat.pi
        return (a.truncatingRemainder(dividingBy: turn) + turn).truncatingRemainder(dividingBy: turn)
    }
}
