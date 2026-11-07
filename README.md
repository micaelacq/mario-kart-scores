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
- Reads each player's **running total**. A new scan updates players already in the list and adds new ones.
- **Editable player list** for fixing misread names, scores or tags. Standings update as you type.
- Warns when the number of players or teams doesn't match the selected mode.
- Copy the standings as text.

## What's in this repo

| Path | What it is |
| --- | --- |
| `index.html` + icons + `manifest.webmanifest` | The web app, served by GitHub Pages. Text is read on the phone with Tesseract.js. |
| `ios/MKTeamScores/` | Native SwiftUI app using Apple's Vision text recognition. See its [README](ios/MKTeamScores/README.md) for build steps (needs a Mac with Xcode 16+). |

## GitHub Pages

Settings → Pages → **Deploy from a branch** → `main` / **(root)**.
