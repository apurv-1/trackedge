# Contributing to TrackEdge

Thanks for helping.
Bug reports, gesture ideas, and pull requests are all welcome.

## Setup

You need macOS 13 or later and Xcode 15 or later (or the matching Command Line Tools).

```bash
git clone https://github.com/apurv-1/trackedge.git
cd trackedge
make test
make run
```

`make run` builds `build/TrackEdge.app` and opens it.
macOS asks for Accessibility access on first launch.
Because local builds are signed ad hoc, macOS may ask again after each rebuild.
If gestures stop working, remove TrackEdge from System Settings > Privacy & Security > Accessibility and add it again.

## Layout

- `Sources/CMultitouch` is a small C bridge to Apple's private MultitouchSupport framework.
  It loads the framework at runtime with `dlopen`, so a missing symbol disables touch input instead of crashing the app.
- `Sources/TrackEdgeCore` holds the gesture engine.
  It turns touch frames into actions and has no AppKit dependency, so every gesture rule has a unit test.
- `Sources/TrackEdge` is the menu bar app.
  It owns devices, system actions, the event tap, and the SwiftUI interface.

## Rules for changes

- Gesture behavior changes need a test in `Tests/TrackEdgeCoreTests`.
- Keep the app free of network access, analytics, and third-party dependencies.
- Use conventional commit prefixes such as `feat:`, `fix:`, `docs:`, `chore:`, and `refactor:`.
- Sign off your commits with `git commit -s` to accept the [Developer Certificate of Origin](https://developercertificate.org).

## Code of conduct

This project follows the [Contributor Covenant 2.1](https://www.contributor-covenant.org/version/2/1/code_of_conduct/).
Report problems to the maintainer listed in `SECURITY.md`.
