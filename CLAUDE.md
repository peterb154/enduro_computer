# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Current state & commands

Phase 1 (Trail MVP) is built and verified on the phone (walk + bicycle): HR from any BLE HR device (tested with a Garmin watch broadcasting HR), background GPS ride stats, raw `.jsonl` log + GPX export, lock screen Live Activity. Not yet tested on the motorcycle. Next: Phase 2, starting with the replay harness, using real ride logs from the Files app.

Commit and push straight to `main` (no branches/PRs) until the app works on the bike.

- `project.yml` is the source of truth for the Xcode project (XcodeGen). `TrailDash.xcodeproj` and `Info.plist` are generated and gitignored; never edit them by hand.
- Regenerate after adding/removing files or changing `project.yml`: `xcodegen generate`
- Open: `open TrailDash.xcodeproj`
- Build for the phone: `xcodebuild -scheme TrailDash -destination 'id=<UDID>' -derivedDataPath build -allowProvisioningUpdates -allowProvisioningDeviceRegistration build`
- Install + launch: `xcrun devicectl device install app --device <UDID> build/Build/Products/Debug-iphoneos/TrailDash.app && xcrun devicectl device process launch --device <UDID> com.peterb154.TrailDash`
- Unit tests (Swift Testing), run on the phone: `xcodebuild test -scheme TrailDash -destination 'id=<UDID>' -derivedDataPath build -allowProvisioningUpdates`; add `-only-testing:TrailDashTests/<Suite>/<test>()` for one test. Simulator also works with `-destination 'platform=iOS Simulator,name=iPhone 18 Pro'` once its runtime mounts.
- Find the UDID: `xcrun devicectl list devices` (target phone is an iPhone 13: no Dynamic Island, so Live Activities show on the lock screen only)
- BLE and real GPS only work on the physical iPhone, not the simulator.
- Signing: free Apple ID (personal team). Installs expire after 7 days; reinstall from Xcode. No TestFlight until a paid account exists.

# TrailDash (working name)

## What this is

A personal iOS app for a handlebar-mounted iPhone on a 2024 KTM 300 XC. It shows heart rate and race-specific timing data at a glance while riding off-road. It will never ship to the App Store. It is installed on one device from Xcode.

The owner directs the work and reviews code but does not hand-write Swift. Explain non-obvious decisions briefly in commit messages and PR-style summaries, not in long code comments.

## Platform & stack

- iOS 17+, SwiftUI, Swift Concurrency (async/await), `@Observable`
- Apple frameworks only. No third-party dependencies unless clearly justified and approved first.
  - CoreLocation — GPS (background location mode, "Always" authorization)
  - CoreBluetooth — heart rate strap (standard Heart Rate Service)
  - ActivityKit + WidgetKit extension — Live Activity / Dynamic Island HR display
  - CoreMotion — motion detection for sprint enduro auto-start
  - SwiftData (or plain files) — ride/session storage
- Units: imperial (mph, miles) throughout the UI. Store raw data in SI internally.

## Hardware assumptions

- iPhone in a TPU bar pad with an inductive charger. The phone is always charging while riding, so battery life is not a constraint and GPS runs at best accuracy.
- Chest-strap HR monitor (e.g., Polar H10) over BLE. Standard service `0x180D`, measurement characteristic `0x2A37`. Parse the flags byte correctly: 8- vs 16-bit HR value, and ignore RR intervals for now. Auto-reconnect on drop.
- In-ride input: **on-screen buttons first.** Gloves, mud, and water make the touchscreen unreliable, so buttons must be huge, few, and placed at the screen edges, and every press gets a haptic/audio confirmation. If this proves unusable on the bike, fall back to a bar-mounted BLE button (cheap remote presenting as an HID keyboard or consumer-control device, captured in the foreground via `pressesBegan`, with a configurable mapping). Route in-ride actions (drop lap point, manual lap, arm, stop) through one set of named actions so a BLE button can be added later without touching mode logic. "Bar button" below means whichever input is in use.
- Severe vibration (2-stroke). Nothing to do in code, but don't design features that depend on fine touch input or reading small text.

## Modes

One app, three modes. Shared plumbing: location stream, HR stream, raw logger, display. Each mode is a separate state machine.

### 1. Trail (free ride / exploring)

- Navigation happens in onX Offroad, which is in the foreground. This app runs in the background.
- Start/stop a session. Log GPS track and HR continuously.
- **Live Activity** showing current HR (compact Dynamic Island + lock screen), plus elapsed time and distance in the expanded view.
- Stats at end: distance, moving time, total time, avg/max HR.

### 2. Hare scramble

A timed race over a multi-mile woods loop. Laps are counted at a scoring chute.

- **Lap gate:** The rider presses the bar button when passing the scoring chute on lap 1 ("drop lap point"). The app records that location and the heading at that moment. The start line is not the lap point, because the first lap may include a start loop.
- **Lap detection rules:** A lap is counted when ALL are true:
  - within ~30 m of the lap point (configurable)
  - heading within ±60° of the recorded heading (configurable)
  - at least a minimum time AND minimum distance since the last lap (defaults: 5 min, 1.0 mi, both configurable). Woods loops often double back near the scoring area.
- Manual lap button as a fallback (long-press on bar button, or similar).
- **Display (large, high-contrast):** HR (biggest), current lap time, last lap time, avg speed (current lap and race), lap count. Optional race clock with time remaining if the race duration is set pre-race.

### 3. Sprint enduro

Several timed tests (8+ is common), ridden once each **in order**, separated by untimed transfer sections. Score is the sum of test times. Reference: moto-tally "Check-by-Check Score" view (e.g. 2025 Bartlett Enduro, IERA): K checks are untimed, E checks are the timed tests.

- **Arm → auto-start:** The rider arms the test (bar button). The clock starts when the bike starts moving: GPS speed > ~5 mph sustained ~1 s. Because GPS lags ~1 s, backdate the start to the first fix of the current rolling streak (speed ≥ min moving speed), capped at 3 s. Fix timestamps are measurement times, so this also removes delivery lag. CoreMotion onset detection is deferred: 2-stroke idle vibration makes accelerometer onset unreliable. Revisit only if replayed logs show GPS-only starts are off.
- **Stop:** The rider presses the bar button after crossing the finish. The run is saved and the app returns to idle, ready to arm again.
- Tests are numbered, not lettered. The app auto-advances Test 1, 2, 3, … after each run, with −/+ to correct if a test is skipped or cancelled. No fixed test count.
- **Display:** HR, elapsed time, avg speed, test distance.
- Post-session: per-test times plus running total, like moto-tally's check-by-check view.

## GPS handling (important)

- Request best accuracy with `activityType = .otherNavigation`.
- **Filter noise:** Drop fixes with `horizontalAccuracy` worse than a threshold (start at 20 m, configurable). Do not accumulate distance when speed is near zero; stopped jitter inflates distance. Under tree cover, accuracy degrades, so be conservative.
- Distance by haversine between accepted consecutive fixes.
- Avg speed = distance / total elapsed time (includes stops, which is what matters in racing). Track moving avg speed separately.
- Keep lap-detection and timing logic in pure Swift types with no CoreLocation dependency, so they can be unit-tested.

## Raw logging & replay (build this first)

- Log every raw location fix, HR sample, motion event, and button press with timestamps, from every session, regardless of mode.
- Export as GPX (track + HR extension) and a raw CSV/JSON. Share via the share sheet.
- **Replay harness:** A test target that feeds recorded raw logs through the mode state machines and asserts laps/runs detected. Tuning thresholds happens against recordings at the desk, not by riding laps.

## Display principles

- Readable at arm's length through goggles in sun and shade. Huge numerals, minimal labels, dark background, no decorative UI.
- Landscape and portrait both supported. The bar pad orientation is TBD.
- Screen never sleeps while the app is open (`isIdleTimerDisabled`), not just during a session.
- Visual + haptic/audio cue on lap counted, test armed, test started, and test stopped. The rider can't read confirmations mid-race.

## Build phases

1. **Phase 1 — Trail MVP (priority; needed within a few weeks for an Idaho singletrack trip):** HR strap connection, background GPS logging, Live Activity with HR, session start/stop, raw logging + GPX export.
2. **Phase 2 — Race infrastructure:** big on-screen action buttons (BLE bar button only if those fail on the bike), big-number race display, replay test harness.
3. **Phase 3 — Hare scramble mode.**
4. **Phase 4 — Sprint enduro mode.**
5. Later / maybe: session history & comparison views, external high-rate GPS receiver support.

Don't start a later phase until the earlier one works on the bike.

## Working conventions

- Small, reviewable changes. Summarize what changed and why at the end of each task.
- Unit tests for all timing, distance, filtering, and lap/test detection logic.
- All thresholds live in one settings struct with sensible defaults, editable in a settings screen.
- If a requirement here seems wrong or a better approach exists, say so before building it.
- Ask before adding dependencies, entitlements, or capabilities not listed above.
