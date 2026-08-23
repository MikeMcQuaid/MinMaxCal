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
- `script/build`: build the app with xcodebuild; `MinMaxCal.app` in
  the repository root symlinks its output
- `script/install`: build, then copy the app into /Applications so
  the login item and the running copy survive rebuilds
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
- `.github/workflows/tests.yml`: CI

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
  the countdown text and the calendar colour dots each have exactly
  one shared view used by the agenda and the takeover alike. Before
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
  takeover from any display.
- A takeover is the one surface allowed to interrupt; everything
  else stays in the menu bar item and never steals focus or
  activates the app without a click.

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
