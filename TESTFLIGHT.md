# MinMaxCal public beta submission

Draft copy for **App Store Connect > MinMaxCal > TestFlight**, under **Additional > Test Information**. Copy each field without its heading. Review the beta terms before adopting them. These TestFlight terms do not replace the repository's source licence or a custom App Store EULA. Keep reviewer contact details current in App Store Connect.

## Beta App Description

See today and tomorrow at a glance. MinMaxCal brings your iPhone's calendars and reminders into one agenda, merges matching events and keeps overdue reminders visible. Open an item for its details, join a meeting or complete a reminder with Undo. Choose the calendars and reminder lists you want to see in Settings.

The included Apple Watch app gives you a read-only agenda from the watch's own calendars and reminders. It works independently of the iPhone app, with no settings sync or complications in this beta.

Requires iOS 26 or later, with watchOS 26 or later for the optional Watch app. No MinMaxCal account, subscription or Mac is required. Your system accounts supply the calendar data; MinMaxCal has no developer-operated server and does not send calendar or reminder content to its developer. Mac-only features such as full-screen takeovers, calendar mirroring and meeting coaching are not part of this mobile beta.

Please send feedback through TestFlight using test events and reminders, excluding private calendar details from screenshots.

## What to Test

Please test Calendar and Reminders permissions independently, today and tomorrow's agenda, matching events across calendars, overdue reminders, calendar/list selection, meeting links, reminder completion and Undo. Check that changes in Calendar or Reminders appear after returning to the app. If you have an Apple Watch, test its read-only agenda and permissions too. Include your device model, OS version and reproduction steps without private event content.

The public release workflow supplies version-specific What to Test text automatically; this is a suggested manual alternative.

## Beta App Review Notes

MinMaxCal is a native iPhone calendar and reminder agenda with an optional Apple Watch companion. There is no app login, demo account or server to configure. A Mac is not required. Review on an iPhone running iOS 26 or later; the optional Watch app requires watchOS 26 or later and reads the watch's system accounts.

1. In Apple's Calendar and Reminders apps, create disposable test events for today and tomorrow, a reminder due today and an overdue reminder. Use accounts you control. Calendar content is read through EventKit and is not supplied by the developer.
2. Open MinMaxCal and allow full Calendar access and Reminders access when requested. The permissions are independent: denying one leaves the other available. If access was denied, change it in system privacy settings and return to the app.
3. Check the agenda, open a row for details and use Settings to select calendars and reminder lists. Events are read-only. Reminders without a due date are intentionally omitted. Overdue reminders remain visible.
4. Complete a disposable reminder, then use Undo. Confirm the change in Apple's Reminders app. Edit a test event in Calendar and return to MinMaxCal to check that it refreshes.
5. Optionally add a meeting link you control to a test event and use its Join action. This opens the appropriate app or website; any meeting-provider login belongs to that service. Joining a meeting is not required to review the agenda.
6. If a compatible Apple Watch is available, install the included Watch app, grant its permissions and check today and tomorrow's read-only agenda. It uses the watch's calendars and reminders, with no iPhone settings sync or complications.

The Mac product has additional features that are deliberately absent from this iPhone and Watch beta. Contact mike@mikemcquaid.com if review needs assistance.

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
- **App Privacy, encryption and age rating:** complete the questionnaires for the shipped iPhone and Watch code. See the [release setup guide](ARCHITECTURE.md#set-up-testflight-releases) for the existing encryption declaration. Do not describe Mac-only recording or mirroring as mobile features.

For an eventual App Store listing, use **Productivity** as the primary category and optionally **Utilities** as the secondary. Suggested subtitle: **Your next event and reminder**. Capture real iPhone screenshots of the agenda, expanded event details and calendar selection using disposable data. Add a Watch agenda screenshot if presenting the Watch companion. Do not use Mac screenshots for the iPhone listing.

App Store screenshots and categories are not prerequisites for the first external TestFlight beta. Enhanced invitations can use those from the latest approved App Store version; screenshots in an unapproved draft do not appear there. See [Apple's test-information guide](https://developer.apple.com/help/app-store-connect/test-a-beta-version/provide-test-information/).

## Public build and invitation

With the existing internal group configured, create the configured external group (**Public Beta** by default, or the name in `TESTFLIGHT_PUBLIC_GROUP`), fill in the fields above and dispatch **Release** from `main` with a fresh version. The workflow assigns the eligible build to that group and submits it for beta review. Internal-only builds from routine `main` commits cannot be used for external testing.

After approval, enable the group's public link, choose **Open to Anyone**, set a **10,000** tester limit and share the link. Testers install TestFlight and accept the invitation without joining your App Store Connect organisation. Future official releases use the same group and reach testers after any required Apple approval. The full setup and recovery instructions are in [Architecture](ARCHITECTURE.md#set-up-testflight-releases).
