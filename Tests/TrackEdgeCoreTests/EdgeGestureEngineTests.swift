import XCTest
@testable import TrackEdgeCore

final class EdgeGestureEngineTests: XCTestCase {
    private var engine: EdgeGestureEngine!
    private var time = 0.0

    override func setUp() {
        engine = EdgeGestureEngine()
        time = 0
    }

    /// Moves one finger from `from` to `to` in small frames, then lifts it.
    @discardableResult
    private func stroke(id: Int = 1, from: (Double, Double), to: (Double, Double), frames: Int = 40,
                        duration: Double = 0.5, lift: Bool = true, fine: Bool = false, gate: Bool = true) -> [EdgeAction] {
        var actions: [EdgeAction] = []
        for i in 0...frames {
            let t = Double(i) / Double(frames)
            let touch = Touch(id: id, x: from.0 + (to.0 - from.0) * t, y: from.1 + (to.1 - from.1) * t)
            actions += engine.process(touches: [touch], time: time + duration * t, gateOpen: gate, fineHeld: fine)
        }
        time += duration
        if lift {
            actions += engine.process(touches: [], time: time)
        }
        return actions
    }

    private func tap(id: Int, at point: (Double, Double)) -> [EdgeAction] {
        let actions = stroke(id: id, from: point, to: point, frames: 2, duration: 0.08)
        time += 0.1
        return actions
    }

    private func steps(_ actions: [EdgeAction], _ control: Control) -> Int {
        actions.reduce(0) { total, action in
            if case let .step(c, count, _) = action, c == control { return total + count }
            return total
        }
    }

    func testRightEdgeSlideUpRaisesVolume() {
        let actions = stroke(from: (0.97, 0.2), to: (0.97, 0.6))
        XCTAssertEqual(actions.first, .slideBegan(.volume))
        XCTAssertEqual(actions.last, .slideEnded)
        XCTAssertEqual(steps(actions, .volume), 6)
    }

    func testLeftEdgeSlideDownLowersBrightness() {
        let actions = stroke(from: (0.03, 0.7), to: (0.03, 0.3))
        XCTAssertEqual(actions.first, .slideBegan(.brightness))
        XCTAssertEqual(steps(actions, .brightness), -6)
    }

    func testSwapSides() {
        engine.config.swapSides = true
        XCTAssertEqual(stroke(from: (0.97, 0.2), to: (0.97, 0.6)).first, .slideBegan(.brightness))
        XCTAssertEqual(stroke(from: (0.03, 0.2), to: (0.03, 0.6)).first, .slideBegan(.volume))
    }

    func testSensitivityScalesSteps() {
        engine.config.sensitivity = 2
        XCTAssertEqual(steps(stroke(from: (0.97, 0.2), to: (0.97, 0.6)), .volume), 12)
    }

    func testPreciseSlidingUsesQuarterSteps() {
        engine.config.preciseSliding = true
        let actions = stroke(from: (0.97, 0.2), to: (0.97, 0.6))
        XCTAssertEqual(steps(actions, .volume), 24)
        XCTAssertTrue(actions.allSatisfy { if case let .step(_, _, fine) = $0 { return fine } else { return true } })
    }

    func testFineModifierUsesQuarterSteps() {
        XCTAssertEqual(steps(stroke(from: (0.97, 0.2), to: (0.97, 0.6), fine: true), .volume), 24)
    }

    func testMiddleOfSurfaceDoesNothing() {
        XCTAssertEqual(stroke(from: (0.5, 0.2), to: (0.5, 0.8)), [])
    }

    func testHorizontalMoveFromEdgeDoesNothing() {
        XCTAssertEqual(stroke(from: (0.97, 0.5), to: (0.6, 0.5)), [])
    }

    func testSecondFingerCancelsSlideUntilAllLift() {
        var actions = stroke(from: (0.97, 0.2), to: (0.97, 0.4), lift: false)
        actions += engine.process(touches: [Touch(id: 1, x: 0.97, y: 0.4), Touch(id: 2, x: 0.5, y: 0.5)], time: time)
        XCTAssertEqual(actions.last, .slideEnded)
        // The remaining finger must not restart a slide.
        XCTAssertEqual(stroke(id: 1, from: (0.97, 0.4), to: (0.97, 0.8), lift: false), [])
        XCTAssertEqual(engine.process(touches: [], time: time), [])
    }

    func testBottomQuarterOnlyIgnoresHighStarts() {
        engine.config.bottomQuarterOnly = true
        XCTAssertEqual(stroke(from: (0.97, 0.5), to: (0.97, 0.9)), [])
        XCTAssertEqual(stroke(from: (0.97, 0.15), to: (0.97, 0.5)).first, .slideBegan(.volume))
    }

    func testGateClosedIgnoresGestures() {
        XCTAssertEqual(stroke(from: (0.97, 0.2), to: (0.97, 0.6), gate: false), [])
    }

    func testBottomSwipeSkipsTracks() {
        XCTAssertEqual(stroke(from: (0.3, 0.05), to: (0.7, 0.05)), [.nextTrack])
        XCTAssertEqual(stroke(id: 2, from: (0.7, 0.05), to: (0.3, 0.05)), [.previousTrack])
    }

    func testReverseSwipe() {
        engine.config.reverseSwipe = true
        XCTAssertEqual(stroke(from: (0.3, 0.05), to: (0.7, 0.05)), [.previousTrack])
    }

    func testMediaStripCanBeDisabled() {
        engine.config.mediaStrip = false
        XCTAssertEqual(stroke(from: (0.3, 0.05), to: (0.7, 0.05)), [])
        XCTAssertEqual(tap(id: 1, at: (0.5, 0.05)) + tap(id: 2, at: (0.5, 0.05)), [])
    }

    func testDoubleTapTopRightCornerMutes() {
        XCTAssertEqual(tap(id: 1, at: (0.95, 0.95)), [])
        XCTAssertEqual(tap(id: 2, at: (0.95, 0.95)), [.toggleMute])
    }

    func testSlowSecondTapDoesNotMute() {
        _ = tap(id: 1, at: (0.95, 0.95))
        time += 1
        XCTAssertEqual(tap(id: 2, at: (0.95, 0.95)), [])
    }

    func testQuickMuteCanBeDisabled() {
        engine.config.quickMute = false
        XCTAssertEqual(tap(id: 1, at: (0.95, 0.95)) + tap(id: 2, at: (0.95, 0.95)), [])
    }

    func testDoubleTapBottomPlaysOrPauses() {
        XCTAssertEqual(tap(id: 1, at: (0.5, 0.05)), [])
        XCTAssertEqual(tap(id: 2, at: (0.5, 0.05)), [.playPause])
    }

    func testSingleTapBottomDoesNothing() {
        XCTAssertEqual(tap(id: 1, at: (0.5, 0.05)), [])
        time += 1
        XCTAssertEqual(tap(id: 2, at: (0.5, 0.5)), [])
    }

    func testMagicMouseUsesTopEdgesOnly() {
        engine.config.surface = .magicMouse
        XCTAssertEqual(stroke(from: (0.97, 0.1), to: (0.97, 0.5)), [])
        XCTAssertEqual(stroke(from: (0.97, 0.6), to: (0.97, 0.95)).first, .slideBegan(.volume))
        XCTAssertEqual(stroke(from: (0.3, 0.05), to: (0.7, 0.05)), [])
    }
}
