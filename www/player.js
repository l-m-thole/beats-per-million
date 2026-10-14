// =============================================================================
// Beats per Million - in-app player bridge
// -----------------------------------------------------------------------------
// The server renders ONE player per song, always from the service chosen in
// "Play via" (a playlist never mixes services - Spotify's and SoundCloud's
// terms don't allow it):
//   - Spotify full player (Spotify connected + Premium): the Web Playback SDK
//     turns this browser tab into a Spotify device - FULL tracks in-app.
//   - Spotify embed widget - 30-s previews (when not connected).
//   - YouTube (IFrame API) - full tracks, no login. The normal youtube.com
//     player: in a test with youtube-nocookie.com YouTube refused 22 of 23
//     songs (error 150). The ▶ Play gate already asks before anything loads.
//   - SoundCloud widget    - full tracks, no login.
//
// Privacy: the page itself loads NOTHING from Spotify, YouTube or SoundCloud.
// Embedded players sit behind a "▶ Play via ..." gate (rendered by the server,
// R/about.R player_gate()); pressing it is the visitor's OK for that service
// (remembered until the page is reloaded), and only then is the service's
// script fetched and its player created. The Spotify SDK script is fetched
// only after a Spotify login (when the server hands over a token).
//
// Reports to Shiny:
//   input$player_progress = {token, frac, pos, dur}  (~2x per second)
//   input$player_state    = {token, playing, t}      (play / pause, on change)
//   input$player_ended    = {token, t}                (song finished)
//   input$sp_device / input$sp_error / input$sp_token_request (SDK plumbing)
//
// player_state tells the app whether music is playing: a newly selected song
// only starts by itself while it is. A pause is reported only after the song
// really started (a player that is still loading doesn't count), and never
// for the pause the app makes itself at the end of a song or snippet.
//
// At the bottom: small helpers for the playlist table and Previous / Next.
// =============================================================================
(function () {
  var SEND_EVERY_MS = 500;   // progress throttle

  // ---- Third-party code: fetched only when a player is actually needed -----
  var SRC = {
    spotifyEmbed: "https://open.spotify.com/embed/iframe-api/v1",
    spotifySdk:   "https://sdk.scdn.co/spotify-player.js",
    youtube:      "https://www.youtube.com/iframe_api",
    soundcloud:   "https://w.soundcloud.com/player/api.js"
  };

  var scripts = {};   // src -> list of callbacks while loading, "done" when loaded
  function loadScript(src, onload) {
    var st = scripts[src];
    if (st === "done") { if (onload) onload(); return; }
    if (st) { if (onload) st.push(onload); return; }
    scripts[src] = onload ? [onload] : [];
    var s = document.createElement("script");
    s.src = src;
    s.async = true;
    s.onload = function () {
      var q = scripts[src];
      scripts[src] = "done";
      (q || []).forEach(function (f) { try { f(); } catch (e) {} });
    };
    s.onerror = function () { scripts[src] = null; };   // allow another try later
    document.head.appendChild(s);
  }

  // Services the visitor said OK to (pressed their ▶ Play) - this page only
  var consent = {};

  // Call cb once more than half of el is on screen: YouTube may only start
  // playing by itself when its player is visible (on phones the Listen panel
  // can be scrolled away while a song ends). Scrolls it into view first.
  function whenVisible(el, cb) {
    function share() {
      var r = el.getBoundingClientRect();
      var vw = window.innerWidth || document.documentElement.clientWidth;
      var vh = window.innerHeight || document.documentElement.clientHeight;
      if (!(r.width > 0 && r.height > 0)) return 0;
      var w = Math.max(0, Math.min(r.right, vw) - Math.max(r.left, 0));
      var h = Math.max(0, Math.min(r.bottom, vh) - Math.max(r.top, 0));
      return (w * h) / (r.width * r.height);
    }
    if (!el || share() > 0.5) return cb();
    try { el.scrollIntoView({ behavior: "smooth", block: "center" }); } catch (e) {}
    if (!("IntersectionObserver" in window)) {
      var tries = 0;
      var t = setInterval(function () {
        if (share() > 0.5 || ++tries > 40) { clearInterval(t); if (share() > 0.5) cb(); }
      }, 100);
      return;
    }
    var done = false;
    var io = new IntersectionObserver(function (entries) {
      if (done) return;
      if (entries.some(function (en) { return en.intersectionRatio > 0.5; })) {
        done = true;
        io.disconnect();
        cb();
      }
    }, { threshold: [0.51, 0.75, 1] });
    io.observe(el);
  }

  var embedApi = null, embedQueue = [];
  var ytReady = false, ytQueue = [], ytPlayer = null, ytPoll = null;
  var spController = null, scWidget = null;
  var token = null, ended = false, lastSent = 0, spLastPos = 0, scDur = 0;
  var lastState = null;   // last play/pause reported for this song (null = none yet)

  function send(name, value, event) {
    if (window.Shiny && Shiny.setInputValue) {
      Shiny.setInputValue(name, value, event ? { priority: "event" } : undefined);
    }
  }

  // Play / pause of the current song -> Shiny (only changes; see header)
  function sendState(myToken, playing) {
    if (ended || myToken !== token) return;
    if (playing === lastState) return;
    if (!playing && lastState !== true) return;
    lastState = playing;
    send("player_state", { token: myToken, playing: playing, t: Date.now() }, true);
  }
  // ---- Song length: whole song (default) or short snippets ----------------
  // Set from Shiny ("Song length" / "Snippets start at"), read live, so
  // switching mid-song takes effect immediately.
  var cfg = { snippet: false, lenMs: 30000, start: 30 };   // start: seconds, or -1 = middle
  Shiny.addCustomMessageHandler("play_cfg", function (m) {
    cfg.snippet = !!m.snippet;
    cfg.lenMs   = (m.len || 30) * 1000;
    cfg.start   = (m.start === undefined || m.start === null) ? 30 : Number(m.start);
  });

  // Where a snippet starts (ms) for a track of length dur (ms)
  function snipStart(dur) {
    if (!cfg.snippet || !(dur > 0)) return 0;
    var s = cfg.start < 0 ? dur / 2 - cfg.lenMs / 2 : cfg.start * 1000;
    return Math.max(0, Math.min(s, dur - cfg.lenMs));
  }
  // Where playback of this track ends (ms): whole song, or start + snippet length
  function limitFor(dur) {
    if (!(dur > 0)) return 0;
    return cfg.snippet ? Math.min(dur, snipStart(dur) + cfg.lenMs) : dur;
  }

  function report(myToken, pos, dur) {
    if (ended || myToken !== token) return;
    var limit = limitFor(dur);
    if (!limit) return;
    var start = snipStart(dur);
    var span = Math.max(1, limit - start);
    var frac = Math.max(0, Math.min(1, (pos - start) / span));
    var now = Date.now();
    if (now - lastSent >= SEND_EVERY_MS) {
      lastSent = now;
      send("player_progress", { token: token, frac: frac,
                                pos: Math.max(0, pos - start), dur: span });
    }
    if (pos >= limit - 700) finish(myToken, limit);
  }

  // Jump to the snippet start once per song (players start at 0:00)
  var seeked = false;
  function maybeSeek(dur, pos, seekFn) {
    if (seeked || !cfg.snippet || !(dur > 0)) return;
    seeked = true;
    var s = snipStart(dur);
    if (s > 0 && pos < s - 1500) { try { seekFn(s); } catch (e) {} }
  }

  function finish(myToken, limit) {
    if (ended || myToken !== token) return;
    ended = true;
    try { if (spController) spController.pause(); } catch (e) {}
    try { if (scWidget) scWidget.pause(); } catch (e) {}
    try { if (ytPlayer && ytPlayer.pauseVideo) ytPlayer.pauseVideo(); } catch (e) {}
    clearInterval(ytPoll);
    try { if (sdk.player && sdk.playingToken === myToken) sdk.player.pause(); } catch (e) {}
    setSdkButton(false);
    send("player_progress", { token: token, frac: 1, pos: 0, dur: 0 });
    send("player_ended", { token: token, t: Date.now() }, true);
  }

  // ===========================================================================
  // 1. Spotify Web Playback SDK (full tracks)
  // ===========================================================================
  var sdk = {
    ready: false, player: null, deviceId: null,
    accessToken: null, expiresAt: 0, waiters: [],
    playingToken: null, playingUri: null, hasPlayed: false, poll: null, lastPos: 0
  };

  function withToken(cb) {
    if (sdk.accessToken && Date.now() < sdk.expiresAt - 60000) return cb(sdk.accessToken);
    sdk.waiters.push(cb);
    send("sp_token_request", Date.now(), true);
  }

  function initSdk() {
    if (!sdk.ready || !sdk.accessToken || sdk.player) return;
    var p = new Spotify.Player({
      name: "Beats per Million",
      getOAuthToken: function (cb) { withToken(cb); },
      volume: 0.8
    });
    sdk.player = p;
    p.addListener("ready", function (e) { sdk.deviceId = e.device_id; send("sp_device", e.device_id); });
    p.addListener("not_ready", function () { sdk.deviceId = null; send("sp_device", null); });
    ["initialization_error", "authentication_error", "account_error", "playback_error"]
      .forEach(function (ev) {
        p.addListener(ev, function (e) { send("sp_error", ev + ": " + (e && e.message), true); });
      });
    p.connect();
  }

  window.onSpotifyWebPlaybackSDKReady = function () { sdk.ready = true; initSdk(); };

  function setSdkButton(playing) {
    var b = document.getElementById("bpm-sdk-toggle");
    if (b) b.textContent = playing ? "⏸ Pause" : "▶ Play";
  }

  function sdkPlay(uri, myToken) {
    if (!sdk.deviceId) return;
    try { if (sdk.player.activateElement) sdk.player.activateElement(); } catch (e) {}
    withToken(function (tok) {
      fetch("https://api.spotify.com/v1/me/player/play?device_id=" + encodeURIComponent(sdk.deviceId), {
        method: "PUT",
        headers: { "Authorization": "Bearer " + tok, "Content-Type": "application/json" },
        body: JSON.stringify({ uris: [uri] })
      }).then(function (r) {
        if (!r.ok) r.text().then(function (t) { send("sp_error", "play failed (" + r.status + "): " + t, true); });
      });
    });
    sdk.playingToken = myToken; sdk.playingUri = uri; sdk.hasPlayed = false; sdk.lastPos = 0;
    startSdkPoll(myToken);
    setSdkButton(true);
  }

  function startSdkPoll(myToken) {
    clearInterval(sdk.poll);
    sdk.poll = setInterval(function () {
      if (myToken !== token || !sdk.player) { clearInterval(sdk.poll); return; }
      sdk.player.getCurrentState().then(function (st) {
        if (myToken !== token) return;
        // Player dropped its state after our track ended
        if (!st) { if (sdk.hasPlayed && sdk.lastPos > 0) finish(myToken, 0); return; }
        var cur = st.track_window && st.track_window.current_track;
        var curUri = cur ? ((cur.linked_from && cur.linked_from.uri) || cur.uri) : null;
        // Spotify "autoplay" moved on to a different (recommended) track
        if (sdk.hasPlayed && curUri && curUri !== sdk.playingUri && (!cur || cur.uri !== sdk.playingUri)) {
          finish(myToken, 0); return;
        }
        setSdkButton(!st.paused);
        if (!st.paused && st.position > 0) {
          if (!sdk.hasPlayed) {
            maybeSeek(st.duration, st.position, function (ms) { sdk.player.seek(ms); });
          }
          sdk.hasPlayed = true;
          report(myToken, st.position, st.duration);
        }
        // Natural end: Spotify pauses and jumps back to 0 (or restarts)
        var wasNearEnd = sdk.lastPos > st.duration - 5000;
        if (sdk.hasPlayed && wasNearEnd &&
            ((st.paused && st.position === 0) || st.position < sdk.lastPos - 5000)) {
          finish(myToken, limitFor(st.duration));
        }
        if (sdk.hasPlayed) sendState(myToken, !st.paused);
        sdk.lastPos = st.position;
      });
    }, 500);
  }

  // A token arrives only once the visitor connected Spotify - only then is
  // the SDK's code fetched from Spotify (it calls onSpotifyWebPlaybackSDKReady)
  Shiny.addCustomMessageHandler("sp_token", function (m) {
    sdk.accessToken = m.token;
    sdk.expiresAt = Date.now() + (m.expires_in || 3600) * 1000;
    sdk.waiters.splice(0).forEach(function (cb) { cb(sdk.accessToken); });
    loadScript(SRC.spotifySdk);
    initSdk();
  });
  // If the app is ever shown inside a frame (some hosts and embeds do that),
  // Spotify's login page refuses to load there: navigate the top window
  // instead (falls back to this frame if the browser doesn't allow it).
  function topWin() {
    try { if (window.top && window.top.location.href) return window.top; } catch (e) {}
    return null;
  }
  Shiny.addCustomMessageHandler("sp_goto", function (m) {
    var w = topWin();
    try { (w || window).location.href = m.url; } catch (e) { window.location.href = m.url; }
  });
  // Remove ?code=&state= after a login (in this frame and, if allowed, the
  // address bar), optionally keeping a flag such as ?testers
  Shiny.addCustomMessageHandler("sp_clean_url", function (m) {
    var q = (m && m.keep) ? "?" + m.keep : "";
    [window, topWin()].forEach(function (w) {
      if (!w) return;
      try { w.history.replaceState(null, "", w.location.pathname + q); } catch (e) {}
    });
  });

  // ===========================================================================
  // YouTube IFrame API (full tracks, no login)
  // ===========================================================================
  window.onYouTubeIframeAPIReady = function () {
    ytReady = true;
    ytQueue.splice(0).forEach(function (fn) { fn(); });
  };
  function withYT(fn) {
    if (ytReady) return fn();
    ytQueue.push(fn);
    loadScript(SRC.youtube);
  }

  function startYtPoll(p, myToken) {
    clearInterval(ytPoll);
    ytPoll = setInterval(function () {
      if (myToken !== token) { clearInterval(ytPoll); return; }
      try { report(myToken, p.getCurrentTime() * 1000, p.getDuration() * 1000); } catch (e) {}
    }, 500);
  }

  // ===========================================================================
  // 2. Spotify embed (not connected): 30-s clips, auto-played once you've
  //    pressed play in the app
  // ===========================================================================
  window.onSpotifyIframeApiReady = function (IFrameAPI) {
    embedApi = IFrameAPI;
    embedQueue.splice(0).forEach(function (fn) { fn(embedApi); });
  };
  function withEmbed(fn) {
    if (embedApi) return fn(embedApi);
    embedQueue.push(fn);
    loadScript(SRC.spotifyEmbed);
  }

  function plainSpotifyEmbed(el, uri) {
    var id = (uri || "").split(":").pop();
    var f = document.createElement("iframe");
    f.src = "https://open.spotify.com/embed/track/" + id;
    f.width = "100%"; f.height = "152"; f.frameBorder = "0";
    f.allow = "autoplay; clipboard-write; encrypted-media; fullscreen; picture-in-picture";
    f.style.borderRadius = "12px";
    el.replaceWith(f);
  }

  // ===========================================================================
  // Mount the right player whenever Shiny re-renders the Listen panel
  // ===========================================================================
  function mount() {
    var box = document.getElementById("bpm-player");
    var newToken = box ? box.getAttribute("data-token") : null;
    if (newToken === token && box && box.getAttribute("data-mounted")) return;

    try { if (spController && spController.destroy) spController.destroy(); } catch (e) {}
    spController = null; scWidget = null;
    clearInterval(sdk.poll);
    clearInterval(ytPoll);
    try { if (ytPlayer && ytPlayer.destroy) ytPlayer.destroy(); } catch (e) {}
    ytPlayer = null;
    // a new song was selected while the SDK was playing the old one
    if (sdk.player && sdk.playingToken &&
        (sdk.playingToken !== newToken || !document.getElementById("bpm-sdk"))) {
      try { sdk.player.pause(); } catch (e) {}
      sdk.playingToken = null;
    }
    token = newToken; ended = false; lastSent = 0; spLastPos = 0; scDur = 0; seeked = false;
    lastState = null;
    if (!box) return;
    box.setAttribute("data-mounted", "1");

    var myToken = token;
    var autoplay = box.getAttribute("data-autoplay") === "true";
    var sdkEl = document.getElementById("bpm-sdk");

    // ---- Full Spotify player (SDK) ----
    if (sdkEl) {
      var uri = sdkEl.getAttribute("data-uri");
      var btn = document.getElementById("bpm-sdk-toggle");
      if (btn) btn.addEventListener("click", function () {
        if (sdk.playingToken === myToken && !ended) {
          sdk.player.togglePlay();
        } else {
          ended = false;
          sdkPlay(uri, myToken);
        }
      });
      if (autoplay) sdkPlay(uri, myToken);
      return;   // SDK handles this song; embeds are not rendered in this mode
    }

    // ---- Embedded players: behind the "▶ Play via ..." gate until the OK ----
    var gate = box.querySelector(".player-gate");
    var slot = box.querySelector(".player-slot");
    var service = box.getAttribute("data-service");
    if (gate && !consent[service]) {
      var go = gate.querySelector(".gate-play");
      if (go) go.addEventListener("click", function () {
        if (myToken !== token) return;
        consent[service] = true;
        openGate(gate, slot);
        mountEmbeds(myToken, true, true);   // pressing Play = play this song now
      });
      return;
    }
    openGate(gate, slot);
    mountEmbeds(myToken, autoplay, false);
  }

  function openGate(gate, slot) {
    if (gate && gate.parentNode) gate.parentNode.removeChild(gate);
    if (slot) slot.classList.add("is-on");
  }

  // Create the embedded player(s) rendered in the Listen panel.
  // fromGate: started by the visitor's own ▶ Play (so a clip that doesn't
  // start by itself waits for them instead of being skipped).
  function mountEmbeds(myToken, autoplay, fromGate) {
    var scEl = document.getElementById("bpm-soundcloud");
    var spEl = document.getElementById("bpm-spotify");
    var ytEl = document.getElementById("bpm-youtube");

    // ---- YouTube (full tracks) ----
    if (ytEl) {
      var vid = ytEl.getAttribute("data-id");
      withYT(function () {
        if (myToken !== token || !document.body.contains(ytEl)) return;
        ytPlayer = new YT.Player(ytEl, {
          videoId: vid, width: "100%", height: "200",
          // origin + widget_referrer: YouTube refuses embeds it can't attribute
          // to a page (error 153 "video player configuration error").
          playerVars: { playsinline: 1, rel: 0,
                        origin: window.location.origin,
                        widget_referrer: window.location.href },
          events: {
            onReady: function (e) {
              if (!autoplay || myToken !== token) return;
              // YouTube's rules: start by itself only while the player is visible
              var frame = null;
              try { frame = e.target.getIframe(); } catch (err) {}
              whenVisible(frame, function () {
                if (myToken === token) e.target.playVideo();
              });
            },
            onStateChange: function (e) {
              if (myToken !== token) return;
              if (e.data === YT.PlayerState.PLAYING) {
                maybeSeek(e.target.getDuration() * 1000, e.target.getCurrentTime() * 1000,
                          function (ms) { e.target.seekTo(ms / 1000, true); });
                startYtPoll(e.target, myToken);
                sendState(myToken, true);
              } else if (e.data === YT.PlayerState.ENDED) {
                finish(myToken, limitFor(e.target.getDuration() * 1000));
              } else {
                clearInterval(ytPoll);
                // (a pause in the last second or two is the song ending, not you)
                if (e.data === YT.PlayerState.PAUSED) {
                  var d = e.target.getDuration(), t = e.target.getCurrentTime();
                  if (!(d > 0 && t >= d - 1.5)) sendState(myToken, false);
                }
              }
            },
            onError: function (e) {
              if (myToken !== token) return;
              // Shiny marks this video as broken and - if music was meant to
              // play - moves on to the next song (never to another service).
              send("yt_error", { token: myToken, code: e.data, id: vid,
                                 autoplay: !!autoplay }, true);
            }
          }
        });
      });
    }

    // ---- SoundCloud (full tracks) ----
    if (scEl) {
      var f = document.createElement("iframe");
      f.src = scEl.getAttribute("data-src");
      f.width = "100%"; f.height = "166";
      f.setAttribute("frameborder", "no"); f.setAttribute("scrolling", "no");
      f.allow = "autoplay";
      scEl.appendChild(f);
      loadScript(SRC.soundcloud, function () {
        if (myToken !== token || !document.body.contains(f) || !(window.SC && SC.Widget)) return;
        var w = SC.Widget(f);
        scWidget = w;
        w.bind(SC.Widget.Events.READY, function () {
          w.getDuration(function (d) { scDur = d; });
          if (autoplay && myToken === token) w.play();
        });
        w.bind(SC.Widget.Events.PLAY, function () {
          sendState(myToken, true);
          w.getDuration(function (d) {
            scDur = d;
            w.getPosition(function (p) { maybeSeek(d, p, function (ms) { w.seekTo(ms); }); });
          });
        });
        w.bind(SC.Widget.Events.PLAY_PROGRESS, function (e) {
          report(myToken, e.currentPosition, scDur);
        });
        w.bind(SC.Widget.Events.PAUSE, function () {
          // SoundCloud may pause right before FINISH: not a pause by you
          w.getPosition(function (pos) {
            if (!(scDur > 0 && pos >= scDur - 1500)) sendState(myToken, false);
          });
        });
        w.bind(SC.Widget.Events.FINISH, function () { finish(myToken, scDur); });
      });
    }

    // ---- Spotify embed (30-s clips when not connected) ----
    if (spEl) {
      var euri = spEl.getAttribute("data-uri");
      var fallback = setTimeout(function () {
        if (!embedApi && document.body.contains(spEl)) plainSpotifyEmbed(spEl, euri);
      }, 4000);
      withEmbed(function (api) {
        clearTimeout(fallback);
        if (myToken !== token || !document.body.contains(spEl)) return;
        api.createController(spEl, { uri: euri, width: "100%", height: 152 }, function (c) {
          if (myToken !== token) { try { c.destroy(); } catch (e) {} return; }
          spController = c;
          // Auto-play when the playlist is running (after your first ▶):
          // Spotify's clip plays, then the next song starts by itself. A track
          // with no playable clip never starts -> skip it after 8 s (but not
          // the song you just pressed ▶ Play for: some browsers want a second
          // press inside Spotify's player, so wait for you there).
          var started = false;
          if (autoplay) {
            setTimeout(function () {
              if (myToken !== token) return;
              try { c.play(); } catch (err) {}
              if (fromGate) return;
              setTimeout(function () {
                if (!started && myToken === token && !ended) {
                  send("sp_nostart", { token: myToken, t: Date.now() }, true);
                  finish(myToken, 0);
                }
              }, 8000);
            }, 300);
          }
          c.addListener("playback_update", function (e) {
            var d = e && e.data;
            if (!d || !d.duration || myToken !== token) return;
            if (!d.isPaused && d.position > 0) {
              if (!started) {
                started = true;
                // logged-in embeds can play the whole track -> honour snippets
                maybeSeek(d.duration, d.position, function (ms) { c.seek(ms / 1000); });
              }
            }
            if (!d.isPaused) report(myToken, d.position, d.duration);
            var nearEnd = d.position >= d.duration - 800 ||
                          (d.isPaused && d.position === 0 && spLastPos > d.duration - 2000);
            if (nearEnd) finish(myToken, limitFor(d.duration));
            else if (started) sendState(myToken, !d.isPaused);
            spLastPos = d.position;
          });
        });
      });
    }
  }

  $(document).on("shiny:value", function (e) {
    if (e.name === "music_panel") setTimeout(mount, 0);
  });

  // ===========================================================================
  // Playlist table + Previous / Next
  // ===========================================================================
  // The table has no DT selection: rows are matched by their song number
  // (first column), so sorting and filtering never mix them up.

  var selectedRow = {};   // table id -> selected song number

  function songNumber(tr) {
    var td = tr && tr.querySelector("td");
    var n = td ? parseInt(td.textContent, 10) : NaN;
    return isNaN(n) ? null : n;
  }

  // Scroll the table's own scroll box (never the page) so the selected row is
  // visible - only if it isn't already.
  function scrollToSelected(wrap) {
    var body = wrap.querySelector(".dataTables_scrollBody");
    var row = wrap.querySelector(".dataTables_scrollBody tbody tr.selected");
    if (!body || !row) return;
    var b = body.getBoundingClientRect(), r = row.getBoundingClientRect();
    if (r.top >= b.top && r.bottom <= b.bottom) return;
    body.scrollTop += (r.top - b.top) - (b.height - r.height) / 2;
  }

  function highlightRow(id, scroll) {
    var wrap = document.getElementById(id);
    if (!wrap || !selectedRow[id]) return;
    var rows = wrap.querySelectorAll(".dataTables_scrollBody tbody tr, table.dataTable > tbody > tr");
    Array.prototype.forEach.call(rows, function (tr) {
      tr.classList.toggle("selected", songNumber(tr) === selectedRow[id]);
    });
    if (scroll) scrollToSelected(wrap);
  }

  Shiny.addCustomMessageHandler("bpm_select_row", function (m) {
    selectedRow[m.id] = m.row;
    setTimeout(function () { highlightRow(m.id, true); }, 0);
  });

  // (Re)drawn table - other era, scale, songs, a sort or a filter
  $(document).on("draw.dt", function (e, settings) {
    var host = $(settings.nTable).closest(".datatables").attr("id");
    if (host) setTimeout(function () { highlightRow(host, true); }, 30);
  });

  // Click a row -> that song (always sent, even for the same row twice)
  $(document).on("click", "#playlist_table tbody tr", function () {
    var n = songNumber(this);
    if (n === null) return;
    selectedRow.playlist_table = n;
    highlightRow("playlist_table", false);
    send("playlist_row_click", { row: n, t: Date.now() }, true);
  });

  // Grey out Previous at the first song and Next at the last
  Shiny.addCustomMessageHandler("bpm_nav", function (m) {
    var prev = document.getElementById("prev_song");
    var next = document.getElementById("next_song");
    if (prev) prev.disabled = !m.prev;
    if (next) next.disabled = !m.next;
  });
})();
