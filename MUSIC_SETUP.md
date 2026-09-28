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
window. When a song ends, the next one starts (untick *Auto-play next song*
to stop that). **Play via** lets you choose Spotify, YouTube or SoundCloud; if
a song has no link for that service, the app uses the best one it has. Under
the player there is always a Spotify, YouTube and SoundCloud button: *Open* if
the song has a link, otherwise *Find* (a search on that site).

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

Or copy the template: `file.copy(".Renviron.example", ".Renviron")`.
Put these lines in the file (leave out the ones you don't have), save it, then
restart R (Session → Restart R):

```
SPOTIFY_CLIENT_ID=...
SPOTIFY_CLIENT_SECRET=...
YOUTUBE_API_KEY=...
GETSONGBPM_KEY=...
```

| Key | Used for | Where it comes from |
|---|---|---|
| `SPOTIFY_CLIENT_ID` / `SPOTIFY_CLIENT_SECRET` | finding Spotify links, the full Spotify player, *Save to Spotify* | Lena's Spotify developer app (ask Lena) |
| `YOUTUBE_API_KEY` | finding YouTube links | Google Cloud (ask Lena, or make your own for free) |
| `GETSONGBPM_KEY` | filling blank `bpm` cells | [getsongbpm.com/api](https://getsongbpm.com/api) (free, needs a public backlink — see below) |
| `SOUNDCLOUD_CLIENT_ID` / `SOUNDCLOUD_CLIENT_SECRET` | finding SoundCloud links (optional) | [developers.soundcloud.com](https://developers.soundcloud.com) (access by application) |

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

Add songs to `data/song_library.csv`: at least `song_title` and `artist`
(and the `bpm` if you know it). Then let the script fill the rest:

```r
source("data-raw/enrich_song_library.R")
```

- It only fills **empty** cells, so links typed by hand are never overwritten.
- It keeps a backup of the CSV in `data/backups/` before changing anything.
- A link is only accepted when **both** title and artist match; karaoke,
  cover, live and remix versions are skipped.
- **YouTube's free quota is about 100 songs a day.** When it runs out the
  script says so and stops that step. Run it again the next day to continue.
- Steps without a key are skipped; that's fine.
- With `GETSONGBPM_KEY` set, blank `bpm` cells are filled from GetSongBPM.
  Values outside 60–150 BPM are flagged in the log (probably half/double time).

### GetSongBPM key and the backlink

The GetSongBPM API is free, but **a public link back to
[getsongbpm.com](https://getsongbpm.com) is required**, or the key can be
suspended without notice. When you register you give a *Website URL* and a
*Backlink URL* (the public page where the link is). For this project:

1. Make sure a **public** page links to `https://getsongbpm.com`. The README
   has a "BPM data: GetSongBPM" section and the app footer links to it too.
   A private GitHub repo does **not** count — nobody outside can see it.
   Options: make the repo public; or a public GitHub Pages / Quarto page,
   personal website or public GitHub profile README with the link.
2. Register at [getsongbpm.com/api](https://getsongbpm.com/api): Website URL =
   the project page; Backlink URL = the exact page with the link (e.g.
   `https://github.com/<user>/climate_playlist#-bpm-data-getsongbpm`); your email.
3. Activate the key from the email, add `GETSONGBPM_KEY=...` to `.Renviron`,
   restart R, and run `source("data-raw/enrich_song_library.R")`.

Rate limit: 3,000 requests/hour — plenty for the library.

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
| Next song does not start | Tick *Auto-play next song*. The Spotify 30-s preview never auto-plays (by design); YouTube and full Spotify do. |
| Pressing play opens Spotify | Same as above: Spotify's preview player does this for songs without a preview. |
| "INVALID_CLIENT: Invalid redirect URI" | In the Spotify dashboard, the Redirect URI must be exactly `http://127.0.0.1:4321/`. |
| Spotify says 403 / "user not registered" | Ask Lena to add your Spotify email under *User Management*. |
| "needs a Spotify Premium account" | The full player needs Premium; use YouTube links instead. |
| "YouTube daily quota used up" | Normal; run the script again tomorrow. |
| "BPM (GetSongBPM) skipped: set GETSONGBPM_KEY" | Add the key to `.Renviron` and restart R. |
| "GetSongBPM refused the request (HTTP 401/403)" | Key not activated yet (check the email) or suspended — check the backlink is still public. |
| "This YouTube video can't be played here" | The uploader blocked embedding; paste a different YouTube link for that song. |
| Keys are `FALSE` in the check above | `.Renviron` must be in the project folder; restart R after editing it. |
