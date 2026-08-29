# Agent Instructions for MikeMcQuaid/MinMaxCal

Most importantly: run `script/style --fix` before finishing any change,
read `README.md` and `ARCHITECTURE.md` before changing anything and
update them in the same commit when behaviour they describe changes.
This repository is readme-driven: documentation leads, code follows.

MinMaxCal is a native SwiftUI macOS menu bar app showing the next
calendar event or reminder, the coming agenda and a full-screen takeover
when something is due. See the Status section of `README.md` for the
slice order.

Write sentence-case imperative commit messages without
conventional-commit prefixes such as `feat:`, `fix:` or `chore:`.

## Commands

- `script/bootstrap`: install `Brewfile` dependencies and generate
  `MinMaxCal.xcodeproj` with XcodeGen
- `script/build [version]`: build the app with xcodebuild, with the
  project's version or the given one; `MinMaxCal.app` in the
  repository root symlinks its output
- `script/install`: build, then copy the app into /Applications so
  the login item and the running copy survive rebuilds
- `script/zip`: zip the built app as `MinMaxCal-<version>.zip`
- `script/package`: sign the built app with the Developer ID
  certificate, notarise it and zip it; every step needs credentials
  from the environment
- `script/test`: run the unit tests
- `script/analyze`: static analysis (SwiftLint analyzer and, on the
  host or CI, periphery for dead code)
- `script/style`: run all linters; `--fix` also applies safe fixes
- `script/icons`: render `App/Icons` to PNG previews in
  `.test-scratch` at menu bar and Dock sizes

## Repository Structure

- `README.md`: user-facing features; the product specification
- `ARCHITECTURE.md`: system design, packages and data flows
- `AGENTS.md`: this file; `CLAUDE.md` is a symlink to it
- `Package.swift`, `Sources/`, `Tests/`: the Swift package targets
- `App/`: the app shell; `project.yml` defines the XcodeGen target
  (the generated `.xcodeproj` stays gitignored); `App/Icons` holds
  the icon sources and `App/Assets.xcassets` the catalogue
- `script/`: development tasks
- `Brewfile`: development dependencies
- `.github/workflows/tests.yml`: CI; `release.yml`: the release
  pipeline, dispatched with a version

## Code Standards

- Swift 6.4 with strict concurrency: App and Features targets use
  MainActor default isolation; Domain and Data are nonisolated, and
  `EventKitCalendarSource` is the only actor
- Every SwiftLint and SwiftFormat rule is enabled; disable per line
  with a comment explaining why (configuration excludes only rules
  that conflict with other enabled rules or tools, with reasons)
- SwiftLint needs the full Xcode selected via xcode-select;
  CommandLineTools alone cannot load SourceKit
- UK English (organised, colour) in documentation, comments and UI
  strings; proper nouns keep their official spellings
- Keep comments minimal; prefer self-documenting code
- Two-space indentation, four-space for Swift (see `.editorconfig`)

### UI Principles

- One implementation per concern: the agenda row, the join button,
  the complete button, the calendar marks and the item details
  (with its notes and location links) each have exactly one shared
  view used by the agenda and the takeover alike. Before
  adding a second approach to any such concern, get explicit
  confirmation.
- The menu bar title is the app: it must be correct within a minute
  of any change and never wider than the configured limit. Anything
  that delays or widens it is a bug.
- Buttons follow Apple HIG and Liquid Glass, in that order, then
  this app's conventions: at most one primary action per surface,
  rendered prominent and bound to Return (Join, Complete); every
  other button is plain glass, icon-only with hover help when the
  icon is unambiguous and short text otherwise. Escape dismisses a
  takeover from any display. In a row of actions the primary button
  trails and Dismiss leads, as in a system dialog.
- Button and menu titles use title case (`Choose Calendars…`,
  `5 Minutes`); toggles, labels, footers and help use sentence case.
- Every clickable row is a button for the pointer, the keyboard and
  VoiceOver alike: it highlights under the pointer (a quaternary
  fill, no animation, as a menu does), `focusable(interactions:
  .activate)` lets Full Keyboard Access reach it, Return and Space
  activate it, and it is an accessible element with a label, a
  default action and a hint that contains its children
  (`.contain`, never `.combine`, which would swallow the buttons
  inside it). A takeover announces itself through
  `AccessibilityNotification` and marks its panel modal.
- Presentation animates briefly (a 0.2 second fade) and not at all
  when Reduce Motion is on.
- A takeover is the one surface allowed to interrupt; everything
  else stays in the menu bar item and never steals focus or
  activates the app without a click. When a takeover is dismissed,
  completed or snoozed, the front goes back to the app that had it;
  Join leaves the front to the call's app.

### Performance

The app is always running, so an idle minute is the budget.

- An idle minute costs one EventKit fetch (by decision) and
  arithmetic: no file read, no JSON decode and no formatter, regex or
  detector construction happens on a tick.
- Trigger streams buffer `newest(1)`; a rebuild never queues behind
  another, however many notifications a sync posts.
- Costly Foundation objects (`NSDataDetector`, `NumberFormatter`,
  the HTML importer's output) are built once and cached; a view body
  never constructs one.
- Anything a takeover panel shows is computed once, never once per
  display.
- Sleeps carry a tolerance where lateness is harmless (the minute
  tick, five seconds) and none where it is not (the takeover alarm).
  App Nap may slow the menu bar but never a takeover: the alarm holds
  a `ProcessInfo` activity for its final five minutes and sleeps with
  zero tolerance. The app does not opt out of App Nap as a whole
  (`NSAppSleepDisabled` stays unset).
- A rebuild publishes only the values that changed.
- Settings text fields commit on Return or focus loss
  (`TextField(value:format:)`), never per keystroke.
- Measure on the host after `script/install`: Activity Monitor's
  Energy Impact should idle near zero and Instruments (Time Profiler,
  SwiftUI, Energy Log) shows anything a unit test cannot.

### Platform Notes

Hard-won on macOS 27 beta; check before assuming they expired.

- EventKit exposes no travel time, no conference URL and no snooze;
  `README.md` records the decisions taken for each (no leave alert,
  links parsed from URL, location and notes, app-local snooze). Do
  not reach for private API or KVC to get around any of them.
- `EKEvent`, `EKReminder` and `EKCalendar` objects must not cross
  threads; only Domain values leave the EventKit actor.
- Recurring events share `calendarItemIdentifier`; identity always
  includes `occurrenceDate`.
- `calendarItemExternalIdentifier` is the invitation's iCalendar UID
  and is the first merge key; it can be nil for local events.
- An `EKEventStore` created without requesting access can build
  events for tests but cannot save, list calendars or set attendees.
- Calendar access cannot be granted inside a sandvault session: TCC
  prompts need the host user's GUI session. Agents run unit tests;
  `script/install` and a real launch are how the host user checks
  the app against real calendars.
- `LSUIElement` apps open windows behind the frontmost app unless
  `NSApp.activate()` runs first; Settings and the takeover do this,
  the agenda popover never does.
- `MenuBarExtra` in window style cannot be opened or closed from
  code; design nothing that needs it.
- `SMAppService.mainApp` registers whatever path the running bundle
  has; only the /Applications copy may register, never a build
  directory.
- SwiftUI `List`/`Section` crash AppKit's outline diff when rows are
  removed conditionally; the agenda is a plain `ScrollView`.
- A `Label` as the `MenuBarExtra` label shows its icon only, and
  `.task`/`.onAppear` on that label never run; the label is a bare
  `Image` then `Text`, and the refresh loop starts from the app.
- The `MenuBarExtra` window proposes no height to flexible views, so
  a `ScrollView` there collapses to nothing; the agenda's carries
  `fixedSize(horizontal: false, vertical: true)` under its
  `frame(maxHeight:)` to size to its rows up to the cap.
- `Text("\(someInt)")` applies digit grouping; use `String(_:)`.
- Trailing closures after multiline calls fight SwiftFormat; keep
  them single-line or make the closure a non-final argument.
- Length-limit splits use cross-file extensions; same-file grouping
  extensions are banned by SwiftLint.
- `SettingsStore.changes` (`UserDefaults.didChangeNotification`) is
  the cross-module signal bus for settings. The stream subscribes
  when first iterated, not when created, so start consuming before
  writing; a test that writes first hangs forever.
- `UserDefaults` is not `Sendable` on the macOS 27 SDK, which is why
  `SettingsStore` is `@MainActor` rather than a nonisolated class.
- A MainActor type cannot conform to a `Sendable` port in an isolated
  way (`cannot form main actor-isolated conformance ... to
  SendableMetatype-inheriting protocol`); test fakes guard their state
  with `Mutex` from `Synchronization` instead.
- Under MainActor default isolation a nested type gets the default
  too; a nonisolated enum's nested structs each need `nonisolated`
  before they can conform to `FormatStyle`.
- Swift `Regex` is not `Sendable`, so a nonisolated `static let`
  regex is rejected; `NSDataDetector` and `NSRegularExpression` are
  `Sendable` and may be statics. Domain builds its regex literals per
  call; Features holds them on MainActor types.
- SwiftLint's `nesting` rule allows one level of nested types, so a
  `ParseableFormatStyle` is its own `ParseStrategy` rather than
  nesting one.
- `NSAnimationContext.runAnimationGroup`'s completion handler is a
  nonisolated `@Sendable` closure, so it cannot capture windows; take
  a `@MainActor @Sendable` closure instead (which may capture them)
  and call it from an explicitly `@Sendable` handler through
  `MainActor.assumeIsolated`.
- `NSRunningApplication.activate(from:options:)` hands the front to
  another app only while this app is active; call it before the
  takeover windows fade, not after.
- A menu bar app with its popover closed is an App Nap candidate,
  and a napped app's timers run seconds late. Activity Monitor's
  Energy tab shows an App Nap column. `ProcessInfo.beginActivity`
  with `.userInitiated` also blocks idle system sleep; use
  `.userInitiatedAllowingIdleSystemSleep`.
- xcodebuild sandboxes the macro plugin server too, so `@Observable`
  fails with `produced malformed response` in a sandvault session;
  `script/build` passes `OTHER_SWIFT_FLAGS=$(inherited)
  -disable-sandbox`. The `$(inherited)` matters: overriding the flags
  outright drops the package's default isolation settings.
- XcodeGen's `info.path` and `entitlements.path` generate those files;
  hand-written ones are referenced through `INFOPLIST_FILE` and
  `CODE_SIGN_ENTITLEMENTS` and excluded from the sources.
- SwiftFormat's `propertyTypes` rule guesses a type from a static
  member's name, so a factory such as `Fixtures.ledgerStore()` needs
  an explicit type annotation or it becomes `: Fixtures`.
- `--enable all` in `.swiftformat` cannot be narrowed by `--disable`;
  clashes are settled on the SwiftLint side or per line.
- `rm` is interactive in the sandbox shell; use `rm -f` in scripts
  and agent commands or a deletion silently does nothing.
- `cannot execute tool 'metal' due to missing Metal Toolchain` can
  break app builds inside a sandbox when the host user has the
  toolchain mounted. Eject the host user's mount, as the host user,
  then ask for the component again inside the sandbox:

  ```bash
  cd ~/Library/Developer/DVTDownloads/MetalToolchain/mounts
  diskutil eject <hash>
  xcodebuild -downloadComponent MetalToolchain  # in the sandbox
  ```

## Required Before Each Commit

- Run `script/style --fix` and resolve anything it cannot fix
- Run `script/test` and `script/analyze` when Swift changed
- Run `script/icons` and look at the output when an icon changed
- Reread changed documentation for UK English, working links and
  72-column wrapping of this file
- Confirm `README.md` and `ARCHITECTURE.md` still describe behaviour
  after your change

## Key Guidelines

1. Documentation first: update `README.md` and `ARCHITECTURE.md`
   before writing code whose behaviour they describe.
2. Anything calendar or reminder related that the public system APIs
   do not provide is a decision for the user, not a computation to
   invent: ask before building a substitute.
3. Derive everything from EventKit on demand; cache nothing across
   launches except the selection, the rules and the takeover ledger.
   Within a launch the stores that own those files keep a copy in
   memory and write through.
4. Keep dependency directions clean: Domain depends on nothing,
   Data and Features depend on Domain and App composes them.
5. Treat invitation content as untrusted: titles, notes and URLs
   render as text and only the detector's own URLs are ever opened.
6. Follow YAGNI and DRY: build only what the current slice needs and
   inline variables and functions used only once. For non-trivial
   parsing, prefer widely used, well maintained libraries, Apple's
   own first, over bespoke reimplementations.
7. Never place app files in bare `/tmp`: per-user scratch belongs in
   that user's macOS temporary directory and test scratch in the
   gitignored `.test-scratch` of the checkout, which each run sweeps.
8. Keep diffs minimal and follow existing structure.
