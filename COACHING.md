# Meeting coaching on Mac

Coaching is optional and disabled by default. Enable it in
**Settings → Coaching**. While disabled it creates no capture, model
or history workers and requests no additional permissions. iPhone and
Apple Watch behaviour is unchanged.

Saved speech models are checked locally when coaching is enabled.
If models are missing, choose **Download Speech Models** in Settings.
Downloads persist outside the app and checkout, so rebuilding does not
remove them. Start never downloads models. Set your transcript name,
speaking share target (default 40%) and turn cue (default 60 seconds).

## Record and review

When coaching is enabled, use the **Events / Record** pill at the top
right of the menu bar panel to switch views. The recording indicator
appears on the left only while recording. Selecting Record opens setup
without starting capture. **Start Meeting** always needs an explicit
choice. Start and End remain accessible in the footer, including while
viewing old summaries.

Use the clear button beside **Other person** for a group call; clearing
the suggested name keeps remote speakers separate.

Recording always captures all system audio alongside your microphone,
including other tabs and unrelated audio. Echo reduction is enabled
automatically.

Upcoming meetings use the same today-and-tomorrow agenda as Events.
Every event with a **Join** button appears and can be selected,
including all-day events, generic links and events without attendees.
Selecting a meeting fills in its details and offers **Join** without
starting capture. Silent start notifications still require a timed event
with a recognised conference URL and offer **Record** and **Not Now**
when prompts and notifications are enabled. Clicking the body asks for
confirmation. Meetings already underway appear without a late prompt.
Changed or deleted events are rechecked before recording. **Record when
joining** is on by default while coaching is enabled. Untick it in
Coaching settings for ordinary Join buttons; turning it off does not
stop a recording already running. The Join button’s label and help
identify whether it will record. Joining before the scheduled start can
still start recording explicitly.

Event takeovers default to **Join and Record** when coaching is enabled
and idle and Record when joining is on. It is the blue primary action,
with a smaller secondary **Join** beside it. Download models in Settings
before the recording action becomes available. The recording choice
joins the call and then starts capture; any recording failure appears on
Record. Previews show the same controls without starting capture or
changing the takeover ledger. Takeovers while already recording retain
the ordinary Join action. Turning Record when joining off makes Join
primary and leaves Join and Record available as a secondary choice.

Start requests Microphone and System Audio Recording Only access.
macOS lists audio-only access under Screen & System Audio Recording,
but no screen images or video are captured. Use **Enable Notifications**
in Coaching settings for silent start-time prompts and coaching cues.
Denying notifications leaves recording and inline cues usable.

Missing or late playback reference marks microphone speech
**Unverified microphone**, hides affected shares and suspends coaching
until uncertainty leaves the five-minute window. Silent system audio
cannot be distinguished from a capture problem. Your call app’s mute
button does not mute MinMaxCal’s microphone capture.

Live statistics show speaking shares, current turns and longest turns
for you and remote speakers. Shares exclude silence; overlapping voices
each count. Turns end when another voice speaks or a pause exceeds
0.75 seconds. Silent cues need a new target crossing and are at least
two minutes apart.

Expand **Meeting history**, then click a meeting to drop down its
details in place. Each row has **Copy Transcript** and a bin button,
usable while the details are closed. Delete asks for confirmation
beneath that row. The current recording stays visible above history.
Use **Copy Transcript** to copy timestamped English words, or expand
Transcript to read them inline. Rename speakers inline or choose an
optional calendar invitee suggestion. Names apply retrospectively to
displayed and copied text.

Saved meetings expire 48 hours after recording ends by default,
including transcripts, summaries, statistics and speaker names. Change
**Keep meetings** in Coaching settings to 48 hours, 7 days or 30 days.
Meetings cannot be kept indefinitely. Removed retention preferences
reset to 48 hours. Expiry deletes the whole saved meeting, including
meetings without transcripts. While coaching is off or the Mac is
asleep, overdue meetings are removed when coaching next runs. Copies you
paste elsewhere are unchanged. Older summaries without transcripts still
load until they expire. Raw audio is never saved or uploaded. Tell
participants you are analysing and transcribing the meeting and review
text before sharing.

Models and history persist inside
`~/Library/Containers/com.mikemcquaid.MinMaxCal/Data/Library`:

- Models: `Application Support/FluidAudio/Models`
- History: `Application Support/MinMaxCal/Meetings`

App sandboxes are separate. Models and history in another app’s container
remain intact and are not reused automatically.

End drains processing and saves the summary. Closing the panel continues
recording; Quit and disabling coaching stop and save. Checkpoints every
15 seconds preserve partial history after failure. If recording stops
with a warning, choose **Restart Recording** in the footer to start a
fresh recording of the same meeting. The partial recording stays in
history; audio from the gap cannot be recovered. Restart is always an
explicit choice. Delete a saved meeting with the bin button, then the
inline **Delete** confirmation; **Cancel** leaves it intact.

The speech model has a one-hour speaker session. The detector resets
hourly and recording continues in the same meeting with fresh
remote-speaker labels. Earlier names and transcript timestamps stay
intact. Microphone capture, echo reduction and transcription continue
through resets. A countdown beside the recording indicator shows when
the next reset is due. Real audio routes and permission prompts need
testing in the host GUI session.

Hourly resets keep each diarizer session within
[LS-EEND’s supported duration][session-limit].

[session-limit]: https://github.com/FluidInference/FluidAudio/blob/v0.17.7/Documentation/Diarization/LS-EEND.md
