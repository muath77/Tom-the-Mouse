import CoreGraphics

enum ScrollReversal {
    /// Reverse standard wheel events in place, preserving trackpad gestures,
    /// momentum, horizontal scrolling, and modifier-based zoom/navigation.
    @discardableResult
    static func apply(to event: CGEvent, enabled: Bool) -> Bool {
        guard enabled, event.type == .scrollWheel,
              event.getIntegerValueField(.scrollWheelEventIsContinuous) == 0,
              event.getIntegerValueField(.scrollWheelEventScrollPhase) == 0,
              event.getIntegerValueField(.scrollWheelEventMomentumPhase) == 0,
              event.flags.intersection([.maskControl, .maskCommand, .maskAlternate, .maskShift]).isEmpty else {
            return false
        }
        // Apps consume different representations of the same wheel movement.
        // Read all three before writing so they stay consistent.
        let lines = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
        let points = event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1)
        let precise = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1)
        guard lines != 0 || points != 0 || precise != 0 else { return false }
        event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: 0 &- lines)
        event.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: 0 &- points)
        event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: -precise)
        return true
    }
}
