# Lounge Team Scores (iOS)

Native SwiftUI app that reads Mario Kart World Competitive Lounge results screens with the
iPhone camera or photo library, groups players into teams by the tag at the start of their
name, and ranks teams by total score.

A web version of the same app is at the root of this repo and runs in Safari at
https://micaelacq.github.io/mario-kart-scores/. It can be added to the Home Screen.

## Features

- **12 or 24 player** modes.
- **Formats:** FFA, 2v2, 3v3, 4v4, 6v6, plus 8v8 and 12v12 in 24-player mode.
- **Tag length** from 1 to 4 characters (default 2). Leading `[`, `(` and symbols are skipped.
- **Camera or Photos**: pick several photos at once when 24 players need more than one screenshot.
- Reads only each player's **name** and the **score on the right**. Ignores the position number, character icon and the up/down/dot movement markers.
- Names under each team are shown without the tag (it's already the team heading).
- If the reader confuses look-alike characters in a tag (e.g. IJ read as 1J), teams with those tags are merged automatically.
- When all players are in but there are more teams than the format allows (a tag was misread), each stray player is placed in the team with room whose tag looks most similar, and flagged with **?** so you can check it.
- Reads each player's **running total**. A new scan updates players already in the list and adds new ones.
- **Editable player list** for fixing misread names or scores (the tag is the start of the name). Standings update as you type.
- Warns when the number of players or teams doesn't match the selected mode.
- Share or copy the standings as text.
- Text is read on the phone by Apple's Vision framework. No network is needed.

## Build & install

Needs a Mac with **Xcode 16 or later** and an iPhone on **iOS 17 or later**.

1. Open `MKTeamScores.xcodeproj` in Xcode.
2. Select the **MKTeamScores** target, then **Signing & Capabilities**:
   - Choose your **Team** (a free Apple ID works).
   - Change **Bundle Identifier** from `com.example.MKTeamScores` to something unique,
     e.g. `com.yourname.MKTeamScores`.
3. Connect your iPhone, choose it as the run destination and press **Run** (⌘R).
4. On first install, trust the developer on the iPhone: **Settings → General → VPN & Device
   Management**. Developer Mode may also need to be turned on: **Settings → Privacy & Security
   → Developer Mode**.

Apps signed with a free Apple ID expire after 7 days. Run them from Xcode again to reinstall.

### If the project won't open

Create a new project in Xcode (**iOS → App**, Interface **SwiftUI**, name `MKTeamScores`).
Delete the generated `ContentView.swift` and `MKTeamScoresApp.swift`, then drag every file from
the `MKTeamScores/` folder into the project. Under the target's **Info** tab, add
**Privacy - Camera Usage Description**.

## Files

| File | Purpose |
| --- | --- |
| `MKTeamScoresApp.swift` | App entry point |
| `ContentView.swift` | The single screen: setup, scan, standings and player list |
| `ScoreStore.swift` | State, tag/team logic, persistence and merging scans |
| `ScoreParser.swift` | Turns lines of text into `(name, running total)` |
| `TextRecognizer.swift` | Vision text recognition; groups text boxes into rows |
| `CameraPicker.swift` | System camera wrapper |
