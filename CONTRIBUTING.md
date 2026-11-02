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

## Releasing

Releases are cut by hand, never on push.
Only the repository owner can run the release, and only from `main`.

1. Open Actions > Release > Run workflow.
2. Pick `patch`, `minor`, or `major`.
   The workflow raises that part of the latest `vX.Y.Z` tag, so the first `major` release is `1.0.0`.
3. The workflow runs the tests, builds a universal app, and stamps the version.
4. It regenerates `CHANGELOG.md` from the commit messages since the last release and commits it to `main`.
   GitHub signs that commit, and the workflow stops if `main` moved during the run.
5. It publishes a GitHub release on that commit with `TrackEdge.zip`, the versioned zip, its SHA-256 checksum, and that version's changelog as notes.
   `releases/latest/download/TrackEdge.zip` then serves the new version.

Pull `main` after a release to get the changelog commit.
To preview the next changelog locally, run `scripts/changelog.sh`.
Commit subjects become changelog entries, so write them for readers: `feat:` lists under Features, `fix:` under Fixes, and a `!` after the type marks a breaking change.

To let a bot or another maintainer release, set the repository variable `RELEASE_ACTORS` to a comma-separated list of GitHub logins with no spaces.
Include the owner in that list to keep the owner's access.
A bot can then start the workflow through the API, for example with `gh workflow run release.yml -f bump=patch`.
