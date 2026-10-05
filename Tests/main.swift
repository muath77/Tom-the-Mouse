import Foundation
import CoreGraphics

var failures = 0
var checks = 0
func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    checks += 1
    if !condition() { failures += 1; print("FAIL: \(message)") }
}

var tracker = GestureTracker()
expect(tracker.move(to: CGPoint(x: 100, y: 0), threshold: 55, natural: false) == nil, "Motion without a hold cannot trigger")
tracker.begin(at: CGPoint(x: 300, y: 300))
expect(tracker.move(to: CGPoint(x: 330, y: 302), threshold: 55, natural: false) == nil, "Small click jitter is preserved")
expect(tracker.end() == false, "Releasing below threshold is a click")

tracker.begin(at: .zero)
expect(tracker.move(to: CGPoint(x: 60, y: 58), threshold: 55, natural: false) == nil, "Ambiguous diagonal motion waits")
expect(tracker.move(to: CGPoint(x: 80, y: 58), threshold: 55, natural: false) == .right, "Direction resolves after diagonal movement")
expect(tracker.move(to: CGPoint(x: -200, y: 0), threshold: 55, natural: false) == nil, "A hold fires only once even when reversed")
expect(tracker.end(), "A gesture release cannot turn into a click")

for (point, expected) in [(CGPoint(x: -70, y: 0), GestureDirection.left),
                          (CGPoint(x: 70, y: 0), .right),
                          (CGPoint(x: 0, y: -70), .up),
                          (CGPoint(x: 0, y: 70), .down)] {
    tracker.begin(at: .zero)
    expect(tracker.move(to: point, threshold: 55, natural: false) == expected, "Direct direction \(expected.rawValue)")
    _ = tracker.end()
}

tracker.begin(at: CGPoint(x: -500, y: -200))
expect(tracker.move(to: CGPoint(x: -560, y: -200), threshold: 55, natural: true) == .right, "Natural motion reverses horizontal direction across displays")
_ = tracker.end()
tracker.begin(at: .zero)
expect(tracker.move(to: CGPoint(x: 0, y: -55), threshold: 55, natural: true) == .up, "Natural mode keeps vertical direction")
_ = tracker.end()
expect(!tracker.isHeld, "Release clears the hold")
tracker.begin(at: .zero)
expect(tracker.move(to: CGPoint(x: 0, y: 55), threshold: 55, natural: false) == .down, "The next hold can trigger independently")

_ = tracker.end()
tracker.begin(at: .zero)
for _ in 0..<10 {
    expect(tracker.moveBy(dx: 5, dy: 0, threshold: 55, natural: false) == nil, "Small relative deltas accumulate below threshold")
}
expect(tracker.moveBy(dx: 5, dy: 0, threshold: 55, natural: false) == .right, "Accumulated motion triggers even with a stationary visible cursor")
expect(tracker.moveBy(dx: 100, dy: 0, threshold: 55, natural: false) == nil, "Relative movement still fires once")
_ = tracker.end()
tracker.begin(at: .zero)
expect(tracker.moveBy(dx: 0, dy: -55, threshold: 55, natural: true) == .up, "New press clears the previous accumulated movement")
// Exercise actual CGEvent fields without posting events to the user's desktop.
func wheel(_ delta: Int64 = 3) -> CGEvent {
    let event = CGEvent(source: nil)!
    event.type = .scrollWheel
    event.flags = []
    event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: delta)
    event.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: delta * 10)
    event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: Double(delta) + 0.5)
    event.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: 2)
    return event
}
for delta: Int64 in [3, -3] {
    let event = wheel(delta)
    expect(ScrollReversal.apply(to: event, enabled: true), "Discrete vertical wheel is reversed")
    expect(event.getIntegerValueField(.scrollWheelEventDeltaAxis1) == -delta, "Line delta changes sign")
    expect(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1) == -delta * 10, "Pixel delta changes sign")
    expect(event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1) == -(Double(delta) + 0.5), "Precise delta changes sign")
    expect(event.getIntegerValueField(.scrollWheelEventDeltaAxis2) == 2, "Horizontal scrolling is unchanged")
}
let disabled = wheel()
expect(!ScrollReversal.apply(to: disabled, enabled: false), "Disabled reversal passes through")
expect(disabled.getIntegerValueField(.scrollWheelEventDeltaAxis1) == 3, "Disabled reversal preserves movement")
for field: CGEventField in [.scrollWheelEventIsContinuous, .scrollWheelEventScrollPhase, .scrollWheelEventMomentumPhase] {
    let event = wheel()
    event.setIntegerValueField(field, value: 1)
    expect(!ScrollReversal.apply(to: event, enabled: true), "Continuous and phase events pass through")
    expect(event.getIntegerValueField(.scrollWheelEventDeltaAxis1) == 3, "Trackpad and momentum movement is preserved")
}
for flag: CGEventFlags in [.maskControl, .maskCommand, .maskAlternate, .maskShift] {
    let event = wheel()
    event.flags = flag
    expect(!ScrollReversal.apply(to: event, enabled: true), "Modifier shortcuts pass through")
    expect(event.getIntegerValueField(.scrollWheelEventDeltaAxis1) == 3, "Modifier scrolling is preserved")
}
let other = wheel()
other.type = .mouseMoved
expect(!ScrollReversal.apply(to: other, enabled: true), "Non-scroll events pass through")
let horizontal = wheel(0)
horizontal.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: 0)
expect(!ScrollReversal.apply(to: horizontal, enabled: true), "Horizontal-only scrolling passes through")
expect(horizontal.getIntegerValueField(.scrollWheelEventDeltaAxis2) == 2, "Horizontal-only delta is preserved")
if failures > 0 { exit(1) }
print("PASS: \(checks) gesture and scroll behavior checks")
