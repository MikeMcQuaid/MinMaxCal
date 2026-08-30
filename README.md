# MinMaxCal

📅 Minimal menu bar calendar, maximal full-screen takeover when due.

MinMaxCal lives in the menu bar, not the Dock. Most of the time it is a
few characters: the next thing on your calendar and how long until it.
When that thing is due it takes over every display with everything you
need and one click to get where you are going.

## 💡 Motivation

Calendar apps either hide in a window you forgot to look at or nag with
notifications you learnt to swipe away. MinMaxCal does one thing at
each extreme: a glance costs nothing, and a due meeting cannot be
missed. It reads the calendars and reminder lists macOS already has
(iCloud, Google, Exchange, CalDAV and local) through EventKit, so
there is nothing to sign into and nothing leaves the Mac.

This document is the product specification: what the app does and the
order the pieces land in. [ARCHITECTURE.md](ARCHITECTURE.md) owns how
it works.

## ✨ Features

### 👀 Glance

The menu bar item shows the app icon, then the next item's title and
the time until it starts: `Weekly planning 1h52`.

- The title keeps its beginning and end and drops the middle
  (`Quarterly rev…th finance`), so similarly prefixed meetings still
  tell apart. Its width never exceeds the limit set in Settings.
- The countdown uses the two largest units that apply and reads like a
  clock once hours are involved: `2d3h`, `1h52`, `45m`, `<1m`. It ticks
  on the minute.
- The next item is the soonest event that has not ended, or a timed
  reminder no more than one hour overdue, across every selected
  calendar and list, today or tomorrow. Once an event starts the
  countdown turns into the time until it ends, so the title always
  answers "how long have I got".
- The icon stands alone when nothing qualifies: no calendar or list
  selected, nothing timed left today or tomorrow, only all-day events
  or reminders without a due time, or only events whose title is
  generic (`Busy`).

### 🗓️ Agenda

Clicking the item opens today and tomorrow in time order as a table: a
calendar or reminder icon per calendar in its colour (overlapping when
a meeting is in several), the title, a join button or a reminder's
tick, then the start and end times in columns of their own. The
Tomorrow header carries the full date (`Monday 24th August 2026`).

- Every row is a button: it lights up under the pointer, Full Keyboard
  Access reaches it, Return, Space and VoiceOver's activate expand it,
  and the join or complete button inside stays a control of its own.
- An expanded row shows the same details as the takeover: calendars,
  location, organiser, attendees, your response, how it repeats and
  the notes with their links. Attendees start as counts per response
  (accepted, tentative, declined, unanswered) and click through to
  names; `firstname.lastname@…` shows as `Firstname Lastname`.
- The notes leave out scheduling tools' notices about the block they
  created and the call's own joining boilerplate once the join button
  carries the link.
- The location drops the words that only say where you already are
  (your city, region and local postcodes, editable in Settings) and
  opens the full address in Apple Maps.
- Right-clicking a row offers the details and **Preview Takeover**,
  which shows that item as a takeover without recording anything.
- Past events and completed reminders are not listed. An overdue
  reminder stays at the top with its tick until done. Ticking
  completes it in Reminders immediately; the row stays, struck
  through, for five minutes with an undo button in case of a slip.
- Invitations you have not answered, or answered tentatively, are
  listed with that status and never taken over. Declined and cancelled
  events are not listed.

The same meeting often exists in several calendars: a work invitation,
its copy in a shared team calendar and a `Busy` block in a personal
one. The agenda shows one row per meeting:

- Items merge when they share an invitation identifier (the iCalendar
  UID the same invite keeps in every calendar), and also when they
  have exactly the same start and end and their titles match or one is
  generic (`Busy`, `Untitled`, `New Event`, `Private`, `Tentative` and
  blank, editable in Settings).
- The merged row takes the most specific title and every member's
  calendar colours; its details, attendees and response come from the
  member with a real title, so a `Busy` copy never decides whether you
  accepted.
- Two different real meetings at the same time stay two rows. A lone
  `Busy` block is not a meeting and is hidden, and so are several at
  the same time rather than merging into one `Busy` row.

### 🖥️ Takeover

When it is time, MinMaxCal covers every connected display, over
full-screen apps and whichever Space is showing, with one panel:

- The title and time range, laid out as the agenda row is, then the
  same details the agenda expands to. The location is a link: a web
  address opens itself, anything else is searched in Apple Maps. Notes
  that arrive as HTML show as their text and links only.
- One primary button, **Join** for a meeting with a call link and
  **Complete** for a reminder, at the right with **Dismiss** at the
  left as in any macOS dialog. Return presses it, Escape dismisses.
- For reminders, **Snooze** for 5, 15 or 60 minutes, as often as you
  like. Snoozing is the app's own: Reminders is not changed, and the
  takeover comes back at the chosen time even across a relaunch.

Two moments trigger a takeover, each switchable in Settings:

1. **Start** of an accepted event: your attendee entry says so, you are
   the organiser or the event has no attendees at all.
2. **Due time** of a reminder in a selected list.

How it behaves:

- The panel arrives on the second. For the last five minutes before a
  takeover the app asks macOS not to nap it; the rest of the time it
  naps like any menu bar app, so the title may run seconds behind.
- It fades in and out, or simply appears with Reduce Motion on, plays
  an alert sound at the alert volume (Glass, another system sound, one
  from `~/Library/Sounds` or none) and VoiceOver announces what is
  starting or due.
- Dismissing, completing or snoozing hands the front back to the app
  you were in; joining leaves that to the call's app.
- It shows once per occurrence per trigger: dismissing it on one
  display dismisses it everywhere and it does not return after a
  relaunch. Items due at the same time queue up.
- A moment that passed while the Mac slept still shows on wake, however
  long the sleep. One that passed while the app was not running shows
  on launch if it was within the last ten minutes; older ones are
  skipped, since the agenda lists anything overdue.
- A clock change or a new time zone re-plans the agenda and the next
  takeover straight away.

**Join** recognises the call and opens it where you want it:

| Link | Opens in, unless Settings says otherwise |
|---|---|
| Zoom (`zoom.us/j/…`, `*.zoom.us/j/…`, `zoommtg://`) | the Zoom app, straight into the meeting with its passcode |
| Microsoft Teams (`teams.microsoft.com/l/meetup-join/…`, `teams.microsoft.com/meet/…`, `teams.live.com/meet/…` and the US government hosts) | the Teams app, straight into the meeting with its passcode, or Microsoft Edge when Teams is not installed |
| Google Meet (`meet.google.com/…`) | Microsoft Edge |
| Jitsi (`meet.jit.si/…`) | Microsoft Edge |
| FaceTime (`facetime.apple.com/join…`) | FaceTime |
| the event's own URL, when it is a web address | the default browser |

Call links are found in the event's URL, location and notes, in that
order, so an agenda link in the URL field does not hide the Zoom link
in the notes. A plain web link in the location or notes (a planner, a
document) is never mistaken for a call, and a Teams chat or channel
link is not a call. A Zoom or Teams link sent anywhere but its own app
opens as the meeting's web address. Links for anything else, or when
the chosen app is missing, open in the default browser. The same join
button sits on agenda rows.

### ⌨️ Shortcuts

Five actions in the Shortcuts app, in Spotlight and to Siri, each doing
exactly what the menu bar and the takeover do:

- **Get Next Item**: the item the menu bar shows, as a value with its
  title, kind, start, end, countdown and join link. Notes, location and
  attendees stay in the app, since they are the invitation's own text.
- **Join Next Meeting**: opens the next item with a call link in the
  app the Join tab chose.
- **Complete Next Reminder**: ticks the first incomplete reminder in
  the agenda, the overdue one when there is one.
- **Snooze Takeover**: snoozes the reminder takeover on screen for one
  of the configured durations.
- **Preview Takeover**: shows the next item as a takeover, recording
  nothing.

An action with nothing to act on says so rather than doing nothing.
Assign any of them a keyboard shortcut for a system-wide join key, or
chain them with Shortcuts' own actions (Set Focus, a Slack status) for
what MinMaxCal itself will never do.

### 🟢 Always there

- MinMaxCal registers itself as a login item the first time the
  installed app runs; the General tab turns that off and, when macOS
  requires you to approve the login item, says so and opens the Login
  Items pane. A quit app alerts nothing, which is why it starts at
  login rather than relying on being remembered.
- The menu bar icon is a calendar leaf with a single filled day, a
  template image that follows the menu bar's appearance.
- The app icon puts a white leaf inside orange full-screen corners on
  a blue Liquid Glass tile, with the dark and mono appearance variants
  newer macOS versions ask for; the app never shows in the Dock.

## 🚫 Out of Scope

Anything EventKit does not expose is either derived by a rule written
above or left out, never fetched through private API:

- **Accounts, servers and sync.** The app reads what macOS already has
  and nothing leaves the Mac. Chain a Shortcut for anything that
  should.
- **Storing your calendar.** Nothing is kept across launches except
  which calendars you chose, the Matching rules and the ledger of
  takeovers shown and snoozed.
- **Travel time and leave alerts.** EventKit does not expose travel
  time; the takeover is at the start, not before it.
- **Answering invitations.** Unanswered invitations show their status
  and are answered in Calendar, as before.
- **Snoozing in Reminders.** Snooze is the app's own and never edits
  the reminder.
- **Guessing a calendar selection.** Nothing is selected until you
  choose; the agenda stays empty rather than guessing.
- **Interrupting for anything but a takeover.** The agenda never
  steals focus or activates the app without a click.
- **An updater.** Homebrew updates the app; releases carry no
  update mechanism of their own.
- **Notifications.** A takeover needs the app running, which is what
  launch at login is for; there is no helper, daemon or notification
  spool.

## 📋 Requirements

- macOS 27 or later.
- Full access to Calendars, and optionally to Reminders, asked for on
  first launch. Nothing works without Calendars.
- Optional: the Zoom app, Microsoft Teams and Microsoft Edge for
  opening calls in them.

## 📦 Installation

Every release on the
[releases page](https://github.com/MikeMcQuaid/MinMaxCal/releases) is
a `MinMaxCal-<version>.zip` holding `MinMaxCal.app`, signed with a
Developer ID certificate and notarised by Apple so it opens without a
Gatekeeper warning: unzip it and move the app to /Applications.

Releases will also ship as a Homebrew cask
(`brew install --cask minmaxcal`) as soon as the repository is notable
enough for
[Homebrew/homebrew-cask](https://github.com/Homebrew/homebrew-cask);
`brew upgrade` then updates the app.

To run the current source instead:

```bash
script/bootstrap
script/install
```

The first launch asks for Calendars, then Reminders. Grant full access
to both, or Calendars alone if you do not use Reminders.

## ⚙️ Configuration

Settings opens from the agenda's footer or Cmd-, and has six tabs:

- **Calendars**: every calendar on the Mac grouped by account under a
  Calendars heading, then every reminder list the same way under
  Reminders, with a checkbox each and an icon in the calendar's colour.
- **Takeover**: the two triggers, the sound (the system's alert sounds
  and any audio file in `~/Library/Sounds`, or none) and the snooze
  durations as a comma-separated list. Choosing a sound plays it, and
  the speaker button plays it again. Preview Takeover on any agenda
  row shows a real takeover from that item whose Complete and Snooze
  only dismiss it and which is never remembered as dismissed.
- **Join**: the app each kind of call opens in, one picker each for
  Zoom, Microsoft Teams, Google Meet, Jitsi, FaceTime and other links,
  offering the default browser, every installed app that can open a
  web address and, for Zoom, Teams and FaceTime, that service's own
  app.
- **Matching**: the generic titles that merge into a real one and the
  home terms dropped from locations (a trailing `*` matches a prefix,
  so `EH*` drops Edinburgh postcodes), each a comma-separated list.
- **General**: launch at login, the menu bar title length and the
  permissions the app holds, each with a button to the relevant System
  Settings pane when something is missing.
- **About**: the app icon, the version, links to the source and the
  licence, and the copyright.

Every text field applies when you press Return or leave it, not on
each keystroke.

## 🛠️ Development

- `script/bootstrap`: install `Brewfile` dependencies and generate the
  Xcode project with XcodeGen
- `script/build`: build the app, versioned `0.1.<build number>` where
  the build number counts `main`'s commits; `MinMaxCal.app` in the
  repository root symlinks its output
- `script/install`: build, then copy the app to /Applications
- `script/zip`: zip the built app as `MinMaxCal-<version>.zip`
- `script/package`: sign the built app with the Developer ID
  certificate, notarise it and zip it; needs the certificate and App
  Store Connect credentials in the environment
- `script/test`: unit tests
- `script/style [--fix]`: SwiftLint and SwiftFormat, every rule on
- `script/analyze`: static analysis and dead code
- `script/icons`: render the menu bar `Leaf.svg` and app `AppMark.svg`
  to PNG previews

See [AGENTS.md](AGENTS.md) for the conventions and
[ARCHITECTURE.md](ARCHITECTURE.md) for the design.

### 🚀 Releasing

Run the **Release** workflow from the Actions tab on `main`. There is
nothing to type: the workflow builds, signs and notarises the app,
tags the commit with its version and publishes a GitHub release
carrying `MinMaxCal-0.1.<build number>.zip` with generated notes. A
push that touches the workflow or the packaging scripts runs the same
job as a dry run that publishes nothing, and every CI run uploads the
zip it built as an artifact.

## 🚧 Status

Both slices are implemented and covered by unit tests, in this order,
each usable on its own:

1. **Glance and agenda**: permissions, the Calendars tab, the menu bar
   title and countdown, the agenda with merging and reminder
   checkboxes, launch at login and both icons.
2. **Takeover**: the full-screen panel on every display at event start
   and reminder due, join links, complete, snooze and dismiss.

What the tests cannot cover is checked by hand against real calendars
and displays after `script/install`: the permission prompts, the menu
bar label's rendering, the takeover windows over full-screen apps and
the Zoom, Teams, FaceTime, Edge and browser hand-offs.

## 📮 Contact

[Mike McQuaid](mailto:mike@mikemcquaid.com)

## 📄 Licence

[AGPL-3.0](LICENSE).
