import Foundation

/// A finger on the surface in normalized coordinates: x grows to the right, y grows away from the user.
public struct Touch: Equatable {
    public var id: Int
    public var x: Double
    public var y: Double

    public init(id: Int, x: Double, y: Double) {
        self.id = id
        self.x = x
        self.y = y
    }
}

public enum Control: String, Equatable, CaseIterable {
    case volume
    case brightness
}

public enum EdgeAction: Equatable {
    case slideBegan(Control)
    /// Positive steps raise the value. Fine steps are a quarter of a normal step.
    case step(Control, count: Int, fine: Bool)
    case slideEnded
    case toggleMute
    case playPause
    case nextTrack
    case previousTrack
}

public enum Surface: Equatable {
    case trackpad
    case magicMouse
}

public struct EdgeConfig: Equatable {
    /// Width of the left and right slide zones as a fraction of the surface width.
    public var edgeWidth = 0.08
    /// Multiplies how much a given finger travel changes the value.
    public var sensitivity = 1.0
    public var swapSides = false
    public var bottomQuarterOnly = false
    public var preciseSliding = false
    public var mediaStrip = true
    public var reverseSwipe = false
    public var doubleTapPlayPause = true
    public var quickMute = true
    public var surface = Surface.trackpad

    public init() {}
}

/// Turns touch frames from one device into edge actions.
///
/// Only single-finger gestures count. A second finger cancels the gesture and the
/// engine ignores the surface until every finger lifts, so normal multi-finger
/// gestures never trigger anything.
public final class EdgeGestureEngine {
    public var config: EdgeConfig

    /// Finger travel that confirms a slide or a swipe direction.
    static let slideActivation = 0.025
    /// Finger travel for one full step at sensitivity 1. About 16 steps span the surface.
    static let stepDistance = 0.06
    static let swipeDistance = 0.18
    static let tapSlop = 0.02
    static let tapDuration = 0.3
    static let doubleTapInterval = 0.4
    /// Directional dominance required before a slide or swipe is accepted.
    static let dominance = 1.5
    static let cornerMinX = 0.85
    static let cornerMinY = 0.8
    static let bottomQuarter = 0.25
    /// Magic Mouse edges respond only on the top part, away from where the palm rests.
    static let mouseEdgeMinY = 0.55

    private enum Phase {
        case pending
        case sliding(Control, anchorY: Double)
        case done
    }

    private enum TapZone {
        case topRightCorner
        case bottomStrip
    }

    private struct Track {
        let id: Int
        let startX: Double
        let startY: Double
        let startTime: Double
        let edge: Control?
        let media: Bool
        let tapZone: TapZone?
        var phase: Phase
        var maxTravel = 0.0
    }

    private var track: Track?
    private var waitingForAllUp = false
    private var lastTap: (zone: TapZone, time: Double)?

    public init(config: EdgeConfig = EdgeConfig()) {
        self.config = config
    }

    /// Feeds one frame of touching fingers.
    /// - Parameters:
    ///   - gateOpen: false while a required modifier key is not held; new gestures are then ignored.
    ///   - fineHeld: true while the fine-control modifiers are held.
    public func process(touches: [Touch], time: Double, gateOpen: Bool = true, fineHeld: Bool = false) -> [EdgeAction] {
        var actions: [EdgeAction] = []

        if touches.isEmpty {
            finish(time: time, into: &actions)
            waitingForAllUp = false
            return actions
        }
        if touches.count > 1 {
            cancel(into: &actions)
            waitingForAllUp = true
            return actions
        }
        if waitingForAllUp { return actions }

        let touch = touches[0]
        if track?.id != touch.id {
            // A different finger without a lift in between is a new gesture, not a tap.
            if track != nil { cancel(into: &actions) }
            track = begin(touch, time: time, gateOpen: gateOpen)
        }
        update(with: touch, fineHeld: fineHeld, into: &actions)
        return actions
    }

    /// Drops the current gesture, for example when the device goes away.
    public func reset() -> [EdgeAction] {
        var actions: [EdgeAction] = []
        cancel(into: &actions)
        waitingForAllUp = false
        return actions
    }

    private func begin(_ touch: Touch, time: Double, gateOpen: Bool) -> Track {
        guard gateOpen else {
            return Track(id: touch.id, startX: touch.x, startY: touch.y, startTime: time,
                         edge: nil, media: false, tapZone: nil, phase: .done)
        }
        let trackpad = config.surface == .trackpad
        let bottomHeight = config.edgeWidth * 1.6

        var verticalOK = true
        if config.bottomQuarterOnly && touch.y > Self.bottomQuarter { verticalOK = false }
        if !trackpad && touch.y < Self.mouseEdgeMinY { verticalOK = false }

        var edge: Control?
        if verticalOK && touch.x <= config.edgeWidth {
            edge = config.swapSides ? .volume : .brightness
        } else if verticalOK && touch.x >= 1 - config.edgeWidth {
            edge = config.swapSides ? .brightness : .volume
        }

        let inCorner = trackpad && touch.x >= Self.cornerMinX && touch.y >= Self.cornerMinY
        let inBottom = trackpad && touch.y <= bottomHeight

        var tapZone: TapZone?
        if inCorner && config.quickMute {
            tapZone = .topRightCorner
        } else if inBottom && config.mediaStrip && config.doubleTapPlayPause {
            tapZone = .bottomStrip
        }

        return Track(id: touch.id, startX: touch.x, startY: touch.y, startTime: time,
                     edge: edge, media: inBottom && config.mediaStrip, tapZone: tapZone, phase: .pending)
    }

    private func update(with touch: Touch, fineHeld: Bool, into actions: inout [EdgeAction]) {
        guard var current = track else { return }
        let dx = touch.x - current.startX
        let dy = touch.y - current.startY
        current.maxTravel = max(current.maxTravel, (dx * dx + dy * dy).squareRoot())

        switch current.phase {
        case .pending:
            if let control = current.edge, abs(dy) >= Self.slideActivation, abs(dy) >= Self.dominance * abs(dx) {
                current.phase = .sliding(control, anchorY: touch.y)
                actions.append(.slideBegan(control))
            } else if current.media, abs(dx) >= Self.swipeDistance, abs(dx) >= Self.dominance * abs(dy) {
                let forward = (dx > 0) != config.reverseSwipe
                actions.append(forward ? .nextTrack : .previousTrack)
                current.phase = .done
            }
        case let .sliding(control, anchorY):
            let fine = config.preciseSliding || fineHeld
            let full = Self.stepDistance / max(config.sensitivity, 0.1)
            let unit = fine ? full / 4 : full
            let count = Int((touch.y - anchorY) / unit)
            if count != 0 {
                actions.append(.step(control, count: count, fine: fine))
                current.phase = .sliding(control, anchorY: anchorY + Double(count) * unit)
            }
        case .done:
            break
        }
        track = current
    }

    private func finish(time: Double, into actions: inout [EdgeAction]) {
        guard let ended = track else { return }
        track = nil

        if case .sliding = ended.phase {
            actions.append(.slideEnded)
            return
        }
        guard let zone = ended.tapZone,
              time - ended.startTime <= Self.tapDuration,
              ended.maxTravel <= Self.tapSlop else { return }

        if let previous = lastTap, previous.zone == zone, time - previous.time <= Self.doubleTapInterval {
            lastTap = nil
            actions.append(zone == .topRightCorner ? .toggleMute : .playPause)
        } else {
            lastTap = (zone, time)
        }
    }

    private func cancel(into actions: inout [EdgeAction]) {
        if let current = track, case .sliding = current.phase {
            actions.append(.slideEnded)
        }
        track = nil
        lastTap = nil
    }
}
