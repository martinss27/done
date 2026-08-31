# Done

An iOS habit app built on one rule: you don't get your other apps back
until you've done the habit. Read for five minutes, then YouTube unlocks.

No accounts, no server. Everything lives on the device.

## Run it

Requires Xcode (App Store) and an iPhone on a cable.

```sh
brew install xcodegen   # once
xcodegen generate       # writes Done.xcodeproj
open Done.xcodeproj
```

Pick your iPhone in the toolbar, press ⌘R.

Signed with a free personal team, so a build expires after 7 days —
plug the phone back in and run again. A paid account raises that to a year.

## Check the logic

Streak and progress rules are pure functions with a plain-Swift check,
no test framework:

```sh
swiftc -o /tmp/t Done/Habit.swift path/to/main.swift && /tmp/t
```

## Where it stands

- [x] Create habits (name + minutes per day)
- [x] Session timer that survives being paused — partial minutes are kept
- [x] Streaks: consecutive days add up, a gap resets
- [x] Local persistence (JSON, tolerant of new fields)
- [x] Three tabs: Blocks, Insights, Settings
- [ ] Block other apps until the habit is done
- [ ] Real per-app screen time

The last two need Apple's Screen Time API (`FamilyControls`,
`ManagedSettings`, `DeviceActivity`). That means a paid Apple Developer
Program membership, and the screen time numbers may only be drawn inside
a `DeviceActivityReport` extension — app names and icons never reach our
code, the system renders them. The Insights tab already has that layout,
filled with sample data.

Publishing to the App Store would additionally need Apple's approval for
the `com.apple.developer.family-controls` entitlement. Personal use does not.

## Layout

| Path | What |
|---|---|
| `Done/Habit.swift` | Model, streak and progress rules, JSON store |
| `Done/BlocksView.swift` | Habit cards with toggle and progress |
| `Done/SessionView.swift` | Countdown for one session |
| `Done/InsightsView.swift` | Screen time layout (sample data) |
| `project.yml` | Project spec — edit this, not the `.xcodeproj` |

`Done.xcodeproj` is generated and gitignored. Run `xcodegen generate`
after adding or renaming a file.
