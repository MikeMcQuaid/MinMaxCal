# MinMaxCal

📅 A minimum, maximal calendar.

MinMaxCal lives in the menu bar, not the Dock. Most of the time it is a
few characters: the next thing on your calendar and how long until it.
When that thing is due it takes over every display with everything you
need and one click to get where you are going.

It reads the calendars and reminder lists macOS already has (iCloud,
Google, Exchange, CalDAV and local) through EventKit, so there is nothing
to sign into and nothing it stores of yours beyond which lists you chose.

[ARCHITECTURE.md](ARCHITECTURE.md) owns how it works; this document owns
what it does and the order the pieces land in.

## 📋 Requirements

- macOS 27 or later.
- Full access to Calendars and to Reminders, asked for on first launch.
  Nothing works without Calendars; reminders are optional.
- Optional: the Zoom app for Zoom calls and Microsoft Edge for Google Meet
  and Jitsi calls. Links for anything else, or when those apps are
  missing, open in the default browser.

## ✨ Features

### 👀 Glance

The menu bar item shows the app icon, then the next item's title and the
time until it starts: `Weekly planning 1h52`. The title keeps its
beginning and end and drops the middle (`Quarterly rev…th finance`), so
a run of similarly prefixed meetings still tells apart. The countdown
uses the two largest units that apply and reads like a clock once hours
are involved, so minutes after hours carry no unit: `2d3h`, `1h52`,
`45m`, `<1m`. It ticks on the minute.

The text is shown exactly when there is a next item: the soonest event
or timed reminder that has not yet ended, across every selected
calendar and list, today or tomorrow. Once an event starts the countdown
turns into the time until it ends (`Weekly planning 28m`), so the title
always answers "how long have I got". The text is absent, leaving the
icon alone, when no calendar or list is selected, when nothing timed is
left today or tomorrow, when the only candidates are all-day events or
reminders without a due time, or when everything left is an event whose
only title is a generic one such as `Busy`.

### 🗓️ Agenda

Clicking the item opens the agenda: today and tomorrow, in time order,
laid out as a table: a small calendar or reminder icon per calendar in
its colour (overlapping when a meeting is in several), the title, an action column holding the join
button or a reminder's tick, then the start time and the end time in
columns of their own so every row lines up. The countdown lives in the
menu bar alone. The Tomorrow header carries the full date (`Monday 24th
August 2026`). Clicking a row expands it with the
same details the takeover shows: calendars, location, organiser,
attendees, your response, how it repeats and the notes with their
links. Attendees start as counts per response (accepted, tentative,
declined, unanswered) and click through to everyone by name; an
attendee the invitation only knows as `firstname.lastname@…` is shown
as `Firstname Lastname`. Scheduling tools' notices about the block they
created are left out of the notes, and so is the call's own joining
boilerplate once the join button carries the link. The
location drops the words that only say where you already are (your
city, region and local postcodes, editable in Settings) and opens the
full address in Apple Maps. Right-clicking a row offers those details
and **Preview Takeover**, which shows that very item as a takeover
without recording anything. Past events and completed reminders are
not listed. An overdue reminder is not past until it is done, so it
stays at the top with its tick until ticked. Ticking a reminder
completes it in Reminders immediately; the row stays, struck through,
for five minutes with an undo button in the tick's place in case it
was a slip.

The same meeting often exists in several calendars at once: a work
invitation, its copy in a shared team calendar and a "Busy" block in a
personal calendar. The agenda shows one row per meeting. Items merge
when they carry the same invitation identifier (the iCalendar UID the
system exposes, which the same invite keeps in every calendar it lands
in), and also when they have exactly the same start and end and their
titles match or one of the titles is generic (`Busy`, `Untitled`, `New
Event`, `Private`, `Tentative` and blank, editable in Settings). The
merged row takes the most specific title and every member's calendar
colours; its details, attendees and your response come from the members
with a real title, so a `Busy` copy never decides whether you accepted
an invitation. Two different real meetings at the same time stay two
rows. An event whose only title is generic is not a meeting at all: a
lone `Busy` block is hidden, and several `Busy` blocks at the same time
are hidden too rather than merged into one `Busy` row.

Invitations you have not answered, or answered tentatively, are listed
with that status and never taken over. Declined and cancelled events are
not listed. Unanswered invitations can only be answered in Calendar, as
before.

### 🖥️ Takeover

When it is time, MinMaxCal covers every connected display, over
full-screen apps and whichever Space is showing, with one panel:

- The title and the time range, laid out as the agenda row is.
- The calendars it is in, its location and its organiser. The location
  is a link: a web address opens itself, anything else (an address, a
  room, a place name) is searched in Apple Maps.
- The attendees as counts per response, clicking through to names,
  your own response and how the item repeats.
- The notes, with links clickable. Notes that arrive as HTML are shown
  as their text and links, with the markup, styling and any embedded
  resources left out.
- One primary button: **Join** for a meeting with a call link and
  **Complete** for a reminder. Return presses it, Escape dismisses.
- For reminders, **Snooze** for 5, 15 or 60 minutes, as often as you
  like. Snoozing is the app's own: the reminder in Reminders is not
  changed, and the takeover comes back at the chosen time even across
  a relaunch.

Two moments trigger a takeover, each switchable in Settings:

1. **Start** of an accepted event. Accepted means your attendee entry
   says so, you are the organiser or the event has no attendees at all
   (your own events).
2. **Due time** of a reminder in a selected list.

A takeover shows once per occurrence per trigger: dismissing it on one
display dismisses it everywhere and it does not return after a relaunch.
A takeover whose moment passed while the Mac was asleep still shows on
wake, however long the sleep, since the app noticed nothing in between.
One whose moment passed while the app was not running still shows on
launch if the moment was within the last ten minutes; older ones are
skipped, since the agenda already lists anything overdue. Items due at
the same time queue up: dismissing the first shows the next.

**Join** recognises the call and opens it where you want it:

| Link | Opens in |
|---|---|
| Zoom (`zoom.us/j/…`, `*.zoom.us/j/…`, `zoommtg://`) | the Zoom app, straight into the meeting with its passcode |
| Google Meet (`meet.google.com/…`) | Microsoft Edge |
| Jitsi (`meet.jit.si/…` and any host listed in Settings) | Microsoft Edge |
| the event's own URL, when it is a web address | the default browser |

Call links are found in the event's URL, location and notes, in that
order, so an agenda link in the URL field does not hide the Zoom link
in the notes. A plain web link in the location or notes (a scheduling
tool's planner, a document) is never mistaken for a call: it stays a
link in the details. The same join button sits on agenda rows.

### ⚙️ Settings

Settings opens from the agenda's footer or Cmd-, and has four tabs:

- **Calendars**: every calendar and reminder list on the Mac grouped
  by account, with a checkbox each, its icon in the calendar's colour
  (a calendar leaf for events, a list for reminders), and beneath the
  name where it lives (iCloud, Exchange, CalDAV, Local, Subscribed,
  Birthdays) and whether it is read-only. Nothing is selected until you
  choose; the agenda stays empty rather than guessing.
- **Takeover**: the two triggers and the snooze durations, each
  explained in place. To see a takeover, right-click any agenda row and
  choose Preview Takeover: a real takeover on every display built from
  that item, whose Complete and Snooze only dismiss it and which is
  never remembered as dismissed.
- **Matching**: the generic titles that merge into a real one, the
  home terms dropped from locations (a trailing `*` matches a prefix,
  so `EH*` drops Edinburgh postcodes) and the Jitsi hosts that open in
  Edge, each a comma-separated list.
- **General**: launch at login, the menu bar title length and the
  permissions the app holds, each with a button to the relevant System
  Settings pane when something is missing.

### 🟢 Always there

MinMaxCal registers itself as a login item the first time the installed
app runs, so it is in the menu bar from the moment you log in; the
General tab turns that off. When macOS requires you to approve the login
item, the tab says so and opens the Login Items pane. A quit app alerts
nothing, which is why it starts at login rather than relying on being
remembered.

The menu bar icon is a calendar leaf with a single filled day, drawn as a
template image so it follows the menu bar's light and dark appearance.
The app icon is the same leaf on a Liquid Glass tile for the Finder,
Launchpad and the Applications folder; the app never shows in the Dock.

## 📦 Installation

Releases will ship as a Homebrew cask. Until then:

```bash
script/bootstrap
script/install
```

The first launch asks for Calendars, then Reminders. Grant full access to
both, or Calendars alone if you do not use Reminders.

## 🛠️ Development

- `script/bootstrap`: install `Brewfile` dependencies and generate the
  Xcode project with XcodeGen
- `script/build`: build the app; `MinMaxCal.app` in the repository
  root symlinks its output for quick development runs
- `script/install`: build, then copy the app to /Applications
- `script/test`: unit tests
- `script/style [--fix]`: SwiftLint and SwiftFormat, every rule on
- `script/analyze`: static analysis and dead code
- `script/icons`: render the icon sources to PNG previews at menu bar and
  Dock sizes for review

See [AGENTS.md](AGENTS.md) for the conventions and
[ARCHITECTURE.md](ARCHITECTURE.md) for the design.

## 🚧 Status

Both slices are implemented and covered by unit tests, in this order,
each usable on its own:

1. **Glance and agenda**: permissions, the Calendars tab, the menu bar
   title and countdown, the agenda with merging and reminder checkboxes,
   launch at login and both icons.
2. **Takeover**: the full-screen panel on every display at event start
   and reminder due, join links, complete, snooze and dismiss.

What the tests cannot cover is still to be checked by hand against real
calendars and displays after `script/install`: the permission prompts,
the menu bar label's rendering, the takeover windows over full-screen
apps and the Zoom, Edge and browser hand-offs.

## 📄 Licence

[AGPL-3.0](LICENSE).
