# Launch checklist — Beats per Million

How to get the app online as a test version now, test the players, and launch
once the song library is ready. Steps 1–3 take about 20 minutes and only need
doing once; after that a re-deploy is one line.

**Current plan:** personal project · test version on shinyapps.io · Spotify
login off for now (invited testers later) · test Spotify vs YouTube, then pick
the default player.

## Status (7 Oct 2026)

- [x] Launch-prep code on branch `feature/launch-prep`, pushed to GitHub
- [x] `renv.lock` complete (`httr2`, `openssl`)
- [x] shinyapps.io account `beatspermillion`, app `dance` deployed:
      <https://beatspermillion.shinyapps.io/dance/>
- [x] Keys in your local `.Renviron`: Spotify ID + secret, YouTube, GetSongBPM
- [x] Live app shows the gmail contact, no Spotify login, Spotify as default
      player (checked 7 Oct, 14:08)
- [ ] Commit + push the latest edits (contact → gmail, docs) so GitHub matches
      what's online
- [ ] Player test with friends (step 4) → set `DEFAULT_PLAYER`
- [ ] Spotify tester login (optional): `SPOTIFY_LOGIN <- "testers"`, step 2,
      re-deploy
- [ ] Library (step 6): fix the 11 unlinked rows, add ~3 songs at 60–69 BPM,
      run the check once with `CHECK_LINKS <- TRUE`
- [ ] Merge `feature/launch-prep` into `main` after the test round

---

## 0. Before the first deploy (5 min)

`renv.lock` must list every package the app imports — the server installs
exactly what it lists (it was missing `httr2` until 7 Oct). In RStudio, from the
project:

```r
install.packages("rsconnect")   # if needed
renv::snapshot()                # adds httr2, openssl, rsconnect, testthat
testthat::test_dir("tests/testthat")
```

Commit `renv.lock`. The deploy script refuses to run while the lockfile is
incomplete or out of sync with your library, so you can't forget this.

## 1. shinyapps.io account (10 min, once)

1. Sign up at [shinyapps.io](https://www.shinyapps.io) (free plan: 5 apps,
   25 active hours a month).
2. Account name: **beatspermillion**. The app name (`dance`) isn't chosen on
   the website: it is `APP_NAME` in the deploy script, and shinyapps.io creates
   the app on the first deploy. Together:
   `https://beatspermillion.shinyapps.io/dance/`.
3. *Account → Tokens → Show → Copy to clipboard*, paste the
   `rsconnect::setAccountInfo(...)` line into the R console and run it. The
   token is stored on your Mac, not in the repo.
4. In `deploy/deploy_shinyapps.R` check `ACCOUNT` and `APP_NAME`, set `CONTACT` (an email or
   URL people can reach you at; it appears in *About & privacy*).

## 2. Spotify dashboard (5 min, once)

At [developer.spotify.com/dashboard](https://developer.spotify.com/dashboard) → your app:

1. *Settings → Edit → Redirect URIs*: **add**
   `https://beatspermillion.shinyapps.io/dance/` — exactly, with `https` and the
   final `/` (keep
   `http://127.0.0.1:4321/` for running locally). Save.
2. *User Management*: add the Spotify email of each tester (max. 5 accounts in
   development mode). Full songs in the app also need **their** Spotify Premium.

Skip this step if you'd rather have no Spotify login online: set
`SPOTIFY_LOGIN <- "off"` in the deploy script.

## 3. Deploy (2 min, repeat after every change)

```r
source("deploy/deploy_shinyapps.R")
```

It checks everything, uploads only the files the app needs plus a server-only
`.Renviron` (app settings + Spotify keys — never your YouTube, GetSongBPM or
SoundCloud keys), and prints the links:

| Link | For |
|---|---|
| `…/dance/` | everyone (no Spotify login shown) |
| `…/dance/?testers` | your ≤ 5 testers: shows *Connect Spotify* and *Save to Spotify* |
| `…/dance/?player=youtube` | opens with *Play via YouTube* (handy for testing) |
| `…/dance/?about` | opens *About & privacy* (use as privacy-policy link) |

Re-run the same line after changing code or `data/song_library.csv`.

## 4. Test the players, then decide (30–45 min)

Open the links on each device and fill in the table: ✓ works, ✗ doesn't,
**30s** = only a preview, **stops** = doesn't go on to the next song.
Press ▶ once on the first song, then let it run into the second and third.

| Device / browser | A. Spotify, not logged in | B. Spotify, logged in at open.spotify.com in the same browser | C. YouTube (`?player=youtube`) | D. Tester (`?testers` → Connect Spotify) |
|---|---|---|---|---|
| Mac – Chrome | | | | |
| Mac – Safari | | | | |
| Mac – Firefox | | | | |
| iPhone – Safari | | | | |
| Android – Chrome | | | | |

For each cell, check: does it **play**, **whole song or 30 s**, does it
**auto-advance**, does the **ball move** on the CO₂ curve.

**Then decide** (one line in `deploy/deploy_shinyapps.R`, re-deploy):

- B gives whole songs and keeps going on most desktops → keep
  `DEFAULT_PLAYER <- "spotify"`.
- Only YouTube plays whole songs and keeps going → `DEFAULT_PLAYER <- "youtube"`
  — and the library needs many more YouTube links (step 6).
- Auto-advance stops on phones for every player → tell Claude: the fix is to
  reuse one player per page instead of rebuilding it for every song.

Write the decision in the project notes, so the library work can follow it.

## 5. GetSongBPM key (10 min) — after step 3

The app footer links to getsongbpm.com, so the app's public URL can serve as
the required backlink.

1. Register at [getsongbpm.com/api](https://getsongbpm.com/api):
   *Website URL* and *Backlink URL* = your app URL.
2. Activate the key from the email, add `GETSONGBPM_KEY=...` to your **local**
   `.Renviron`, restart R, run `source("data-raw/enrich_song_library.R")`.

Checked on 7 Oct: the link is in the plain HTML served at that address, so a
link checker can see it. If they still don't accept it, use a public page
instead: make the GitHub repo public (the README has a GetSongBPM section) or a
one-page GitHub Pages / Quarto site with the link.

## 6. Get the library ready (ongoing)

```r
source("data-raw/check_song_library.R")
```

Prints what to fix, where songs are missing, and a **READY / NOT YET** verdict;
details go to `output/library_check/`. Set `PUBLIC_POOL <- "youtube"` at the top
if YouTube becomes the default player, and `CHECK_LINKS <- TRUE` now and then
to test every link online (no keys needed).

**Launch criteria** (per-period scaling, the app default): no rows with errors ·
every slot gets a song within ±5 BPM · at least 3 songs within ±5 BPM per slot.

Status on 7 Oct 2026 (231 songs):

- **11 songs have no link at all.** Most look like typos, which is why the
  enrichment found nothing — fix the spelling and re-run
  `data-raw/enrich_song_library.R`:
  *Another Bites The Dust* → Another **One** Bites the Dust ·
  *Dirt Off Your Sholder* → Shoulder · *A Whola Lotta Love* → Whole Lotta Love ·
  *Fleetwod Mac* → Fleetwood Mac · *I Know I'm No Good* → **You** Know I'm No Good ·
  *Tell Your Girlfriend* (Robyn) → **Call** Your Girlfriend ·
  *Since You've Been Gone* (Kelly Clarkson) → Since U Been Gone ·
  *Labrynth* → Labrinth · *Tom Rosentahl* → Tom Rosenthal.
  Check the other two by hand (*Back In The Mudd*, *How Do You Love Me Now*).
- **Spotify pool: nearly there.** 5 of 385 slots fall back; add about
  **3 songs at 60–69 BPM**.
- **YouTube pool: far off** — 127 of 385 slots fall back; roughly 70 more
  songs with a working YouTube link are needed, spread over 60–150 BPM. Only
  matters if YouTube becomes the default.
- 10 songs are outside 60–150 BPM — probably half/double time (the report
  suggests the value).
- *Global* scaling can't be fully covered by any library: on the global scale
  every ice-core era sits at ~60–66 BPM, so those playlists drift to faster
  songs. Expected, not a launch criterion.

## 7. Go public

1. `CONTACT` set, *About & privacy* read through (`?about`) — it is a
   reasonable starting text for a personal project, not legal advice.
2. `DEFAULT_PLAYER` set from step 4; library check says READY.
3. Re-deploy, then share the plain link (keep `?testers` for testers).

## Good to know

- **Active hours:** the free plan has 25 a month. The app is "active" while
  anyone has it open (plus 15 min), so one hour of listening ≈ one active hour,
  however many people listen at once. Check usage in the shinyapps.io
  dashboard; upgrade if a launch needs more.
- **Logs:** `rsconnect::showLogs(appName = "dance", account = "beatspermillion")`.
- **Blocked YouTube videos** found by visitors are remembered only until the
  server restarts or you re-deploy; the link check (`CHECK_LINKS <- TRUE`)
  finds them up front so you can fix them in the CSV.
- **Visitors never share a Spotify login.** Locally the login is cached on your
  Mac as before; on the server each browser gets its own, kept in memory only.
- **Settings without code changes:** see `.Renviron.example` (`BPM_*`
  variables) — the deploy script writes them for the server.
