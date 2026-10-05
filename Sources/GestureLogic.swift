import Foundation
import CoreGraphics

enum GestureDirection: String {
    case left, right, up, down

    var title: String {
        switch self {
        case .left: return "Previous desktop"
        case .right: return "Next desktop"
        case .up: return "Mission Control"
        case .down: return "App windows"
        }
    }
}

/// One action per hold. A press that never crosses the threshold remains a click.
struct GestureTracker {
    private(set) var isHeld = false
    private(set) var didTrigger = false
    private var origin = CGPoint.zero
    private var accumulatedPosition = CGPoint.zero

    mutating func begin(at point: CGPoint) {
        origin = point
        accumulatedPosition = point
        isHeld = true
        didTrigger = false
    }

    /// Relative movement continues accumulating even when the event tap holds
    /// the visible pointer still. Absolute cursor positions cannot measure that.
    mutating func moveBy(dx: Double, dy: Double, threshold: Double, natural: Bool) -> GestureDirection? {
        guard isHeld else { return nil }
        accumulatedPosition.x += dx
        accumulatedPosition.y += dy
        return move(to: accumulatedPosition, threshold: threshold, natural: natural)
    }

    mutating func move(to point: CGPoint, threshold: Double, natural: Bool) -> GestureDirection? {
        guard isHeld, !didTrigger else { return nil }
        let dx = point.x - origin.x
        let dy = point.y - origin.y
        // Require a clear direction; a diagonal near 45 degrees waits for more motion.
        let horizontal = abs(dx) >= threshold && abs(dx) > abs(dy) * 1.2
        let vertical = abs(dy) >= threshold && abs(dy) > abs(dx) * 1.2
        guard horizontal || vertical else { return nil }
        didTrigger = true
        if vertical { return dy < 0 ? .up : .down }
        let direction: GestureDirection = dx < 0 ? .left : .right
        guard natural else { return direction }
        return direction == .left ? .right : .left
    }

    mutating func end() -> Bool {
        let wasGesture = didTrigger
        isHeld = false
        didTrigger = false
        return wasGesture
    }
}
