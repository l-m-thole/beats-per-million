# Launch & running — Beats per Million

How the app goes online and stays there. The one-time setup is done (steps 0,
1 and 5; step 2 only matters for *Connect Spotify*). A re-deploy is one line
(step 3), followed by a short smoke test (step 4).

**Now:** personal, non-commercial project · **v5.0.0** online at
<https://beatspermillion.shinyapps.io/dance/> since Tue 10 Nov 2026, public
launch the same day (preview from 26 Oct) · shinyapps.io **Basic** plan from
10 Nov (500 active hours a month), paid by us for two months · public repo
<https://github.com/l-m-thole/climate_playlist> · Spotify is the default
player, *Connect Spotify* is off online · SoundCloud is hidden
(`SHOW_SOUNDCLOUD` in `R/config.R`).

## Status (10 Nov 2026)

- [x] **Preview, 26 Oct 2026 — v4.0.0:** seven eras (new: Industrial,
      1850–today, from CMIP7), library fixes, SoundCloud hidden, CMIP7
      citation, year labels, Spotify login note; link shared with friends.
- [x] **v4.1.0 (27 Oct):** *Playlist length* Standard / Long (2× songs); songs
      follow the curve (a faster song when the tempo rises).
- [x] **v4.1.1 (27 Oct):** *🖼 Show album covers* moved onto the CO₂ plot;
      test fixed for Shiny 1.14. Pushed and deployed.
- [x] **v4.1.2 (29 Oct):** docs brought up to date (README, LAUNCH,
      DEVELOPMENT, MUSIC_SETUP, LICENSE); no app changes, no deploy needed.
- [x] Online settings (`deploy/deploy_shinyapps.R`): `DEFAULT_PLAYER = "spotify"`,
      `SPOTIFY_LOGIN = "off"`, `CONTACT` = the gmail address. shinyapps.io
      *Instance Idle Timeout*: 5 min (26 Oct).
- [x] Song library READY for Spotify and YouTube (step 6).
- [x] **shinyapps.io Basic from Tue 10 Nov 2026:** 500 active hours a month,
      paid by us for two months, with instance settings to match (see
      *Hosting*).
- [x] **v5.0.0 released, Tue 10 Nov 2026** (tag `v5.0.0`); GitHub repo public.
- [ ] **Public launch, Tue 10 Nov 2026** (see *Launch day* below).
- [ ] **Decide in December** (before Basic renews on 10 Jan 2027): back to
      Free, or keep Basic (see *Hosting*).
- [ ] Optional: ~30 more songs, mostly 60–74 BPM, so *Long* playlists match as
      tightly as Standard ones (step 6).

## Launch day (10 Nov 2026)

Version 5.0.0 was released on Tue 10 Nov from the branch `release/v5.0.0`
(planned for Mon 9 Nov); the public launch is the same day.

Before the release:

- [x] Hosting decided: shinyapps.io Basic for two months, paid by us (see
      *Hosting*).
- [x] Library check READY (step 6).

Tue 10 Nov — release v5.0.0:

- [x] Upgrade the shinyapps.io account to Basic (monthly) and set the app's
      instance settings (see *Hosting*).
- [x] Merge the monthly Mauna Loa pull request (`refresh-co2`), if NOAA had
      posted October by then.
- [x] Merge `release/v5.0.0` into `main`, deploy (step 3, runs the tests) and
      smoke test on a desktop and a phone (step 4).
- [x] Push `main` and the tag `v5.0.0`; make the GitHub repo public.

Tue 10 Nov — public launch:

- [ ] Share the plain link (not `?testers`).

Keep an eye on the active hours (shinyapps.io dashboard) and the logs
(*Good to know*), especially in the first days.

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

Only needed for *Connect Spotify* online (`SPOTIFY_LOGIN <- "testers"` or
`"on"` in the deploy script). It is `"off"` for now, so this can wait.

## 3. Deploy (2 min, repeat after every change)

```r
source("deploy/deploy_shinyapps.R")
```

It checks everything (the tests too), uploads only the files the app needs
plus a server-only `.Renviron` (app settings, plus the Spotify keys only while
a Spotify login is on — never your YouTube, GetSongBPM or SoundCloud keys), and
prints the links:

| Link | For |
|---|---|
| `…/dance/` | everyone (no *Connect Spotify*) |
| `…/dance/?testers` | your ≤ 5 testers: shows *Connect Spotify* and *Save to Spotify* (only with `SPOTIFY_LOGIN <- "testers"`) |
| `…/dance/?player=youtube` | opens with *Play via YouTube* (handy for testing) |
| `…/dance/?about` | opens *About & privacy* (use as privacy-policy link) |

Re-run the same line after changing code or `data/song_library.csv`.

## 4. Smoke test after a deploy (5 min)

Open the plain link on a desktop and a phone, and once with `?player=youtube`:

- all 7 era buttons show a plot and a playlist; *Playlist length: Long*
  doubles the songs and keeps your place in time;
- **▶ Play via Spotify**: song 1 plays (the whole song if you're logged in to
  Spotify in that browser, otherwise 30 s), runs into song 2 by itself, and the
  ball moves along the CO₂ curve;
- the same with **▶ Play via YouTube** (pressing Play accepts YouTube's terms);
- *About this era*, *💡 How it works* and *About & privacy* open; the footer
  shows the data sources (incl. CMIP7), the GetSongBPM link and *Suggest a
  song*.

**Player decision (26 Oct):** Spotify stays the default — whole songs for
visitors logged in to Spotify, 30-s previews for everyone else, with a login
note at the ▶ Play gate, under the player and in *About*; YouTube is one click
away under *Play via*. If auto-advance ever stops on phones for every player,
the fix is to reuse one player per page instead of rebuilding it for every song.

## 5. GetSongBPM key (10 min) — after step 3

The app footer links to getsongbpm.com, so the app's public URL can serve as
the required backlink.

1. Register at [getsongbpm.com/api](https://getsongbpm.com/api):
   *Website URL* and *Backlink URL* = your app URL.
2. Activate the key from the email, add `GETSONGBPM_KEY=...` to your **local**
   `.Renviron`, restart R, run `source("data-raw/enrich_song_library.R")`.

Checked on 7 Oct: the link is in the plain HTML served at that address, so a
link checker can see it. If they still don't accept it, use a public page
instead: the GitHub repo, public since 10 Nov 2026 (the README has a
GetSongBPM section), or a one-page GitHub Pages / Quarto site with the link.

## 6. Get the library ready (ongoing)

```r
source("data-raw/check_song_library.R")
```

Prints what to fix, where songs are missing, and a **READY / NOT YET** verdict;
details go to `output/library_check/`. Set `PUBLIC_POOL <- "youtube"` at the top
if YouTube becomes the default player, and `CHECK_LINKS <- TRUE` now and then
to test every link online (no keys needed).

**Launch criteria** (per-period scaling, the app default): no rows with errors ·
every slot gets a song within ±3 BPM · at least 3 songs within ±3 BPM per slot.
±3 BPM is the matcher's first window (`MATCH_TOLS` in `R/config.R`); when it
has no unused song it widens to ±5, then ±10 BPM.

Status on 27 Oct 2026 (348 songs, all with a Spotify link, 342 with a YouTube
link; `data/youtube_blocked.csv` is empty):

- **READY** for Spotify and YouTube: all 409 standard slots get a song within
  ±3 BPM, with at least 3 to choose from.
- **Long playlists** (information only, Spotify pool): 86–100 % of the slots
  within ±3 BPM, depending on era and shuffle (Early Humans and Cenozoic are
  the thinnest). About 30 more songs would close the gaps: 60–64 BPM +6,
  65–69 +11, 70–74 +5, 75–79 +4, 80–84 +2, 100–104 +2.
- *Global* scaling can't be fully covered by any library: on the global scale
  every ice-core era sits at ~60–66 BPM, so those playlists drift to faster
  songs. Expected, not a launch criterion.

## Hosting

- **Plan (from 10 Nov 2026):** shinyapps.io **Basic**, USD 49 a month (plus
  VAT if charged), paid by us for two months. 500 active hours per billing
  cycle (Free 25, Starter 100). The cycle started with the upgrade on 10 Nov;
  it renews on 10 Dec and 10 Jan 2027. A downgrade or cancellation takes
  effect at once, with no partial refund.
- **App settings** (shinyapps.io → *Applications* → `dance` → *Settings*):
  instance size **xlarge** (2 GB, room for three R processes); under
  *Advanced*, **Max Worker Processes 3** and **Instance Load Factor 100 %**, so
  a second instance only starts when the first one is full; *Instance Idle
  Timeout* 5 min. Keep it to one instance (no *Add instance*).
- **Active hours** count per instance while it's up — not per worker or per
  visitor. Listening keeps it up (`player.js` reports progress about twice a
  second), then it sleeps after the 5-min idle timeout. Every extra instance
  counts its own hours. One instance busy around the clock uses the 500 hours
  in ~21 days. On Free, visitors see "application not available" once the
  hours are used up; Posit's current pages don't say what happens on a paid
  plan (older ones mentioned an overage charge), so check the usage every few
  days, especially in the first week.
- **After the two months — decide in December** (before the 10 Jan renewal):
  - *Back to Free:* first set the instance size back to *large* (or smaller)
    and Max Worker Processes to 1 — the downgrade is refused while the app
    uses paid settings — then *Account → Billing* → Free. Free accounts move
    to Connect Cloud on 28 Jan 2027 (see *Coming*).
  - *Keep Basic* (e.g. if PAGES or the Oeschger Centre help with the costs):
    nothing to do; it moves to Connect Cloud *Enhanced* on 31 Mar 2027 and
    keeps its price through the 2029 renewal. Cancelling a paid plan loses
    that price.
- **Coming:** Posit is moving shinyapps.io into Posit Connect Cloud. Free
  accounts move automatically on **28 Jan 2027** (Connect Cloud Free: 20 usage
  credits a month, public GitHub repos only); Starter and Basic on
  31 Mar 2027 — don't cancel a paid shinyapps.io plan before then, or its
  price is lost. Old shinyapps.io links redirect.
- **Options checked (Oct 2026):** a paid plan (shinyapps.io Starter USD 13 a
  month = 100 h, Basic USD 49 = 500 h; yearly billing is cheaper); a server or
  platform from a partner (Shiny Server, Posit Connect or Docker); free
  container hosts such as Render (sleeps after 15 min, ~1 min to wake up);
  Shinylive, i.e. the app running in the browser (works unchanged, but the
  first load takes ~45 s on a desktop and 2–3 min on a phone). Help with
  hosting costs stays a plain thank-you in *About* — see the platform rules in
  [`DEVELOPMENT.md`](DEVELOPMENT.md#platform-rules--privacy-keep-these).

## Good to know

- **Active hours:** Basic has 500 per billing cycle (Free 25). The app is
  "active" while anyone has it open (plus the idle timeout, 5 min since
  26 Oct), so one hour of listening ≈ one active hour per instance, however
  many people listen at once. Check usage in the shinyapps.io dashboard, or
  in R: `rsconnect::showUsage(appName = "dance", account = "beatspermillion",
  from = "7d", interval = "1d")`; more under *Hosting*.
- **Logs:** `rsconnect::showLogs(appName = "dance", account = "beatspermillion")`.
- **Blocked YouTube videos** found by visitors are remembered only until the
  server restarts or you re-deploy; the link check (`CHECK_LINKS <- TRUE`)
  finds them up front so you can fix them in the CSV.
- **Visitors never share a Spotify login.** Locally the login is cached on your
  Mac as before; on the server each browser gets its own, kept in memory only.
- **Settings without code changes:** see `.Renviron.example` (`BPM_*`
  variables) — the deploy script writes them for the server.
- **Link previews** are cached by WhatsApp, Signal, Slack etc., so after
  changing `www/og-image.png` an old card can show for a while. If the app was
  asleep, the very first preview may come out blank — share it again.
- **Suggest a song** goes to `CONTACT` by email; set `SUGGEST_URL` in the
  deploy script to use a form instead. The tempos listed with it are worked
  out on every deploy for the pool of `DEFAULT_PLAYER`.
