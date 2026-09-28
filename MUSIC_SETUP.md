# Music setup: players, API keys and song links

How to get the in-app player working and fill `data/song_library.csv` with
links. Everything runs from the project root in RStudio.

## 1. Get the code

The player work is on the branch `feature/player-progress`:

```bash
git fetch
git checkout feature/player-progress
```

Then install the packages the app needs (first time only):

```r
renv::restore()
```

## 2. How the app plays songs

Each song in the playlist is matched to a song from `data/song_library.csv`
with a similar BPM. The app uses one player per song, the first one that works:

1. **Spotify, full songs**: only after you click *Connect Spotify* (needs
   Spotify Premium).
2. **YouTube**: full songs, no login needed.
3. **SoundCloud**: full songs, no login needed.
4. **Spotify preview**: 30 seconds only. The app never starts it by itself.

While a song plays, the ball on the CO₂ curve moves through that song's time
window. Each song plays for at most 3 minutes, then the next one starts
(untick *Auto-play next song* to stop that).

**➕ Save to Spotify** (next to 📥 CSV) saves the current period's songs as a
private playlist in your Spotify account. It doesn't open anything; you get a
notification with a link.

## 3. API keys

Keys go in a file called `.Renviron` in the project folder. Git ignores that
file, so **never commit keys and never paste them into the repo**. Share keys
privately (e.g. a password manager), not by email or Slack.

```r
usethis::edit_r_environ("project")
```

Put these lines in the file, save it, then restart R (Session → Restart R):

```
SPOTIFY_CLIENT_ID=...
SPOTIFY_CLIENT_SECRET=...
YOUTUBE_API_KEY=...
```

| Key | Used for | Where it comes from |
|---|---|---|
| `SPOTIFY_CLIENT_ID` / `SPOTIFY_CLIENT_SECRET` | finding Spotify links, the full Spotify player, *Save to Spotify* | Lena's Spotify developer app (ask Lena) |
| `YOUTUBE_API_KEY` | finding YouTube links | Google Cloud (ask Lena, or make your own for free) |

**Spotify: extra step for anyone other than Lena.** Lena's Spotify app is in
development mode, so it only works for Spotify accounts she has added. Send
Lena the **email address of your Spotify account**; she adds it in the
[Spotify dashboard](https://developer.spotify.com/dashboard) → the app →
*User Management* (max. 5 people). The full in-app player also needs **your**
account to have Spotify Premium; without Premium, YouTube still plays full
songs.

**Your own YouTube key (optional, free):**
[console.cloud.google.com](https://console.cloud.google.com) → create a
project → *APIs & Services* → enable **YouTube Data API v3** → *Credentials* →
*Create credentials* → *API key*.

Check that R sees the keys (should print `TRUE TRUE TRUE`):

```r
nzchar(Sys.getenv(c("SPOTIFY_CLIENT_ID", "SPOTIFY_CLIENT_SECRET", "YOUTUBE_API_KEY")))
```

## 4. Fill in the song links

Add songs to `data/song_library.csv`: at least `song_title`, `artist` and the
song's `bpm`. Then let the script find the links:

```r
source("data-raw/enrich_song_library.R")
```

- It only fills **empty** cells, so links typed by hand are never overwritten.
- It keeps a backup of the CSV in `data/backups/` before changing anything.
- A link is only accepted when **both** title and artist match; karaoke,
  cover, live and remix versions are skipped.
- **YouTube's free quota is about 100 songs a day.** When it runs out the
  script says so and stops that step. Run it again the next day to continue.
- Steps without a key (BPM lookup, SoundCloud) are skipped; that's fine.

**Check the results** (the script also prints the rows that need a look):

```r
log <- read.csv("data/song_library_enrich_log.csv")
View(log)                 # matched_title / matched_artist = what was found
subset(log, flag != "")   # no confident match -> fill these by hand
```

If a match is wrong, clear that cell in `song_library.csv` (or paste the right
link) and run the script again. Commit the updated `song_library.csv` when
you're happy with it.

## 5. Run the app

```r
shiny::runApp()
```

The app opens in your normal browser on `http://127.0.0.1:4321`. It has to be
the browser, because the Spotify player doesn't work in RStudio's Viewer.

To get full Spotify songs, click **Connect Spotify** in the *Listen* panel and
log in. You only need to do that once; the login is remembered.

## Troubleshooting

| What you see | What to do |
|---|---|
| Only 30-second previews | That song only has a Spotify link. Add a `youtube_url`, or connect Spotify (Premium). |
| Pressing play opens Spotify | Same as above: Spotify's preview player does this for songs without a preview. |
| "INVALID_CLIENT: Invalid redirect URI" | In the Spotify dashboard, the Redirect URI must be exactly `http://127.0.0.1:4321/`. |
| Spotify says 403 / "user not registered" | Ask Lena to add your Spotify email under *User Management*. |
| "needs a Spotify Premium account" | The full player needs Premium; use YouTube links instead. |
| "YouTube daily quota used up" | Normal; run the script again tomorrow. |
| "This YouTube video can't be played here" | The uploader blocked embedding; paste a different YouTube link for that song. |
| Keys are `FALSE` in the check above | `.Renviron` must be in the project folder; restart R after editing it. |
