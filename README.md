# Mario Kart Lounge Team Scores

Reads Mario Kart World Competitive Lounge results screens with the iPhone camera or photo
library, groups players into teams by the tag at the start of their name, and ranks teams
by total score.

**Web app:** https://micaelacq.github.io/mario-kart-scores/
Open it in Safari on your iPhone and choose **Share → Add to Home Screen**.

## Features

- **12 or 24 player** modes.
- **Formats:** FFA, 2v2, 3v3, 4v4, 6v6, plus 8v8 and 12v12 in 24-player mode.
- **Tag length** from 1 to 4 characters (default 2). Leading `[`, `(` and symbols are skipped.
- **Camera or Photos**: pick several photos at once when 24 players need more than one screenshot.
- **Works on photos of the TV**: finds the results rows from the score column, then reads each row's name and score separately (handles glare, tilt, dark text on coloured bars and the white text on your own row). Score digits are matched against the game's digit shapes, measured from real results-screen photos.
- When you scan race after race, players are matched by name; once the lobby is full, a misread name is paired with the most likely player instead of being added twice, and each player's name is the reading seen most often across scans.
- Reads only each player's **name** and the **score on the right**. Ignores the position number, character icon and the up/down/dot movement markers.
- Names under each team are shown without the tag (it's already the team heading).
- If the reader confuses look-alike characters in a tag (e.g. IJ read as 1J), teams with those tags are merged automatically.
- When all players are in but there are more teams than the format allows (a tag was misread), each stray player is placed in the team with room whose tag looks most similar, and flagged with **?** so you can check it.
- Reads each player's **running total**. A new scan updates players already in the list and adds new ones.
- **Editable player list** for fixing misread names or scores (the tag is the start of the name). Standings update as you type.
- Warns when the number of players or teams doesn't match the selected mode.
- Copy the standings as text.

## What's in this repo

| Path | What it is |
| --- | --- |
| `index.html` + icons + `manifest.webmanifest` | The web app, served by GitHub Pages. Text is read on the phone with Tesseract.js. |
| `ios/MKTeamScores/` | Native SwiftUI app using Apple's Vision text recognition. See its [README](ios/MKTeamScores/README.md) for build steps (needs a Mac with Xcode 16+). |

## GitHub Pages

Settings → Pages → **Deploy from a branch** → `main` / **(root)**.
