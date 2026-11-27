# MinMaxCal public beta submission

Draft copy for **App Store Connect > MinMaxCal > TestFlight**, under **Additional > Test Information**. Copy each field without its heading. Review the beta terms before adopting them. These TestFlight terms do not replace the repository's source licence or a custom App Store EULA. Keep reviewer contact details current in App Store Connect.

## Beta App Description

See today and tomorrow at a glance. MinMaxCal brings your Mac or iPhone's calendars and reminders into one agenda, merges matching events and keeps overdue reminders visible. Open an item for its details, join a meeting or complete a reminder with Undo. Choose the calendars and reminder lists you want to see in Settings.

On Mac, your next item and countdown stay in the menu bar. Full-screen takeovers help you arrive on time. Optional calendar mirroring copies events between calendars, and optional meeting coaching transcribes audio and measures speaking time locally. These Mac features are not included on iPhone or Watch.

The included Apple Watch app gives you a read-only agenda from the watch's own calendars and reminders. It works independently of the iPhone app, with no settings sync or complications in this beta.

Requires macOS 26 or later on an Apple silicon Mac, or iOS 26 or later, with watchOS 26 or later for the optional Watch app. No MinMaxCal account or subscription is required. The iPhone app does not require a Mac. Your system accounts supply the calendar data; MinMaxCal has no developer-operated server and does not send calendar or reminder content to its developer.

Please send feedback through TestFlight using test events and reminders, excluding private calendar details from screenshots.

## What to Test

Please test Calendar and Reminders permissions independently, today and tomorrow's agenda, matching events across calendars, overdue reminders, calendar/list selection, meeting links, reminder completion and Undo. Check that changes in Calendar or Reminders appear after returning to the app. If you have an Apple Watch, test its read-only agenda and permissions too. Include your device model, OS version and reproduction steps without private event content.

On Mac, also test the menu bar countdown, takeovers, snoozing and optional launch at login. Test calendar mirroring only with disposable calendars and review Compare before enabling Sync. If testing coaching, download the models in Settings and record only with participants' knowledge and permission.

The public release workflow supplies version-specific What to Test text automatically; this is a suggested manual alternative.

## Beta App Review Notes

MinMaxCal has native Mac and iPhone apps with an optional Apple Watch companion. There is no app login, demo account or server to configure. Use your own disposable calendar and reminder data. The apps read each device's system accounts independently. Follow the steps for the platform under review below.

### iPhone and Watch

A Mac is not required. Review on an iPhone running iOS 26 or later; the optional Watch app requires watchOS 26 or later and reads the watch's system accounts.

1. In Apple's Calendar and Reminders apps, create disposable test events for today and tomorrow, a reminder due today and an overdue reminder. Use accounts you control. Calendar content is read through EventKit and is not supplied by the developer.
2. Open MinMaxCal and allow full Calendar access and Reminders access when requested. The permissions are independent: denying one leaves the other available. If access was denied, change it in system privacy settings and return to the app.
3. Check the agenda, open a row for details and use Settings to select calendars and reminder lists. Events are read-only. Reminders without a due date are intentionally omitted. Overdue reminders remain visible.
4. Complete a disposable reminder, then use Undo. Confirm the change in Apple's Reminders app. Edit a test event in Calendar and return to MinMaxCal to check that it refreshes.
5. Optionally add a meeting link you control to a test event and use its Join action. This opens the appropriate app or website; any meeting-provider login belongs to that service. Joining a meeting is not required to review the agenda.
6. If a compatible Apple Watch is available, install the included Watch app, grant its permissions and check today and tomorrow's read-only agenda. It uses the watch's calendars and reminders, with no iPhone settings sync or complications.

### Mac

Review on an Apple silicon Mac running macOS 26 or later. Quit any existing direct-download MinMaxCal copy before opening the TestFlight build. MinMaxCal is a menu bar app and has no Dock icon or main window.

1. In Calendar and Reminders, create disposable events starting a few minutes from now and a reminder due today. Launch MinMaxCal, grant full Calendar access and optionally grant Reminders access. Click its menu bar item to open the agenda.
2. Open Settings from the agenda footer or Cmd-, choose calendars and lists, then check the agenda and countdown. Complete a test reminder and use Undo. Login launch is opt-in in General for this build.
3. Let a disposable event reach its start time to see the takeover on each display. Check Dismiss, Snooze and Escape. Add a meeting link you control to test Join; any provider login belongs to that service.
4. Optional mirroring: create disposable source and destination calendars, choose them in Sync and inspect Compare before enabling Sync. Use one Mac for mirroring. This intentionally writes copies through EventKit to your selected destination calendar and its provider.
5. Optional coaching: open Coaching in Settings, download the speech models and grant microphone and system-audio permissions when prompted. Test with audio you are authorised to record. Processing is local; model downloads require internet access. Coaching is not required to review the agenda or takeovers.

Contact mike@mikemcquaid.com if review needs assistance.

## Beta Licence Agreement

MinMaxCal is provided by Mike McQuaid under the GNU Affero General Public License, version 3, with the repository's additional Apple distribution permission. The licence, permission and corresponding source are available at https://github.com/MikeMcQuaid/MinMaxCal in `LICENSE` and `LICENSE-EXCEPTION`. Third-party components retain their respective licences. These beta notes impose no additional restrictions on rights granted by those licences.

This is pre-release software. Features may change, builds expire and continued availability or compatibility is not promised. Use disposable reminders when testing completion and Undo. Keep backups of information you rely on. Warranty and liability are governed by the applicable software licence and any rights that cannot be excluded under applicable law.

Apple's TestFlight terms govern its distribution service. Calendar providers, meeting services and other apps you choose have their own terms. MinMaxCal's data handling is described at https://github.com/MikeMcQuaid/MinMaxCal/blob/main/PRIVACY.md.

Feedback is voluntary. Do not include confidential calendar content. There is no confidentiality requirement for this public beta. Contact: Mike McQuaid, mike@mikemcquaid.com.

## Other fields and preparation

- **Feedback email:** `mike@mikemcquaid.com`.
- **Review contact:** Mike McQuaid and that email; enter your reachable telephone number privately in App Store Connect.
- **Sign-in:** no MinMaxCal account or developer-supplied credentials are required. Explain the reviewer's own test calendar setup in the notes above.
- **Privacy Policy URL:** `https://github.com/MikeMcQuaid/MinMaxCal/blob/main/PRIVACY.md`. Publish any policy updates on `main` and confirm the URL opens without signing in. Provide an accessible privacy link inside the app as well.
- **Marketing/support URL:** `https://github.com/MikeMcQuaid/MinMaxCal`.
- **App Privacy, encryption and age rating:** complete the questionnaires for the shipped Mac, iPhone and Watch code. See the [release setup guide](ARCHITECTURE.md#set-up-testflight-releases) for the existing encryption declaration. Describe recording and mirroring as Mac-only features.

For an eventual App Store listing, use **Productivity** as the primary category and optionally **Utilities** as the secondary. Suggested subtitle: **Your next event and reminder**. Capture real iPhone screenshots of the agenda, expanded event details and calendar selection using disposable data. Add a Watch agenda screenshot if presenting the Watch companion. Do not use Mac screenshots for the iPhone listing.

For the Mac listing, capture the menu bar agenda, a takeover and calendar selection on Mac using disposable data. Keep Mac and iPhone screenshots in their respective platform listings.

App Store screenshots and categories are not prerequisites for the first external TestFlight beta. Enhanced invitations can use those from the latest approved App Store version; screenshots in an unapproved draft do not appear there. See [Apple's test-information guide](https://developer.apple.com/help/app-store-connect/test-a-beta-version/provide-test-information/).

## Public build and invitation

To test the private Mac build, configure the Mac signing secrets and automatic distribution for the internal group. Wait for CI to pass on a current `main` push that changes app Swift code or Swift package dependencies. It uploads private Mac and iPhone builds. Install TestFlight on the Mac and use your existing internal invitation. No external group setup or beta review is needed for this private upload.

When ready for public Mac testing, use the configured external group (**Public Beta** by default, or the name in `TESTFLIGHT_PUBLIC_GROUP`), update the fields above and dispatch **Release** from `main` with a fresh version. The workflow assigns both eligible platform builds to that group and submits them for beta review before publishing the GitHub release. Internal-only builds from routine `main` commits cannot be used for external testing. A paired release uses two of the three public upload slots allowed in 24 hours.

The existing public invitation is https://testflight.apple.com/join/XhQqMckH. After Mac beta approval, reuse it and check that any group device criteria allow Mac testers. If creating a new group, enable its public link, choose **Open to Anyone** and set a **10,000** tester limit. Testers install TestFlight and accept the invitation without joining your App Store Connect organisation. Future official releases use the same group and reach testers after any required Apple approval. The full setup and recovery instructions are in [Architecture](ARCHITECTURE.md#set-up-testflight-releases).
