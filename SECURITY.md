# Security policy

TrackEdge needs Accessibility access, because it reads trackpad touches and posts media key events.
That access is powerful, so we treat security reports seriously.

## What TrackEdge does with that access

- It reads raw touch positions from the trackpad and keeps them only in memory.
- It posts system media key events for volume, brightness, mute, and playback.
- While a slide is active, it holds back pointer movement events so the cursor stays still.
- It makes no network connections and writes nothing except its own preferences.

## Reporting a vulnerability

Please use GitHub's private vulnerability reporting on this repository instead of a public issue.
We aim to reply within seven days.
