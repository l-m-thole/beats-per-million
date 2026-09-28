// =============================================================================
// Beats per Million - in-app player bridge
// -----------------------------------------------------------------------------
// The server renders ONE player per song, first available of:
//   1. Spotify full player (Spotify connected + Premium): the Web Playback SDK
//      turns this browser tab into a Spotify device - FULL tracks in-app.
//   2. YouTube (IFrame API) - full tracks, no login.
//   3. SoundCloud widget    - full tracks, no login.
//   4. Spotify embed widget - 30-s previews; never started programmatically,
//      so the app never sends you off to Spotify by itself.
//
// Reports to Shiny:
//   input$player_progress = {token, frac, pos, dur}  (~2x per second)
//   input$player_ended    = {token, t}                (song finished)
//   input$sp_device / input$sp_error / input$sp_token_request (SDK plumbing)
// =============================================================================
(function () {
  var SEND_EVERY_MS = 500;   // progress throttle

  var embedApi = null, embedQueue = [];
  var ytReady = false, ytQueue = [], ytPlayer = null, ytPoll = null;
  var spController = null, scWidget = null;
  var token = null, ended = false, lastSent = 0, spLastPos = 0, scDur = 0;

  function send(name, value, event) {
    if (window.Shiny && Shiny.setInputValue) {
      Shiny.setInputValue(name, value, event ? { priority: "event" } : undefined);
    }
  }
  function limitFor(dur) { return dur > 0 ? dur : 0; }   // full song, no cap

  function report(myToken, pos, dur) {
    if (ended || myToken !== token) return;
    var limit = limitFor(dur);
    if (!limit) return;
    var frac = Math.max(0, Math.min(1, pos / limit));
    var now = Date.now();
    if (now - lastSent >= SEND_EVERY_MS) {
      lastSent = now;
      send("player_progress", { token: token, frac: frac, pos: pos, dur: limit });
    }
    if (pos >= limit - 700) finish(myToken, limit);
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
    send("player_progress", { token: token, frac: 1, pos: limit || 0, dur: limit || 0 });
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
          sdk.hasPlayed = true;
          report(myToken, st.position, st.duration);
        }
        // Natural end: Spotify pauses and jumps back to 0 (or restarts)
        var wasNearEnd = sdk.lastPos > st.duration - 5000;
        if (sdk.hasPlayed && wasNearEnd &&
            ((st.paused && st.position === 0) || st.position < sdk.lastPos - 5000)) {
          finish(myToken, limitFor(st.duration));
        }
        sdk.lastPos = st.position;
      });
    }, 500);
  }

  Shiny.addCustomMessageHandler("sp_token", function (m) {
    sdk.accessToken = m.token;
    sdk.expiresAt = Date.now() + (m.expires_in || 3600) * 1000;
    sdk.waiters.splice(0).forEach(function (cb) { cb(sdk.accessToken); });
    initSdk();
  });
  Shiny.addCustomMessageHandler("sp_goto", function (m) { window.location.href = m.url; });
  Shiny.addCustomMessageHandler("sp_clean_url", function (m) {
    history.replaceState(null, "", window.location.pathname);
  });

  // ===========================================================================
  // YouTube IFrame API (full tracks, no login)
  // ===========================================================================
  window.onYouTubeIframeAPIReady = function () {
    ytReady = true;
    ytQueue.splice(0).forEach(function (fn) { fn(); });
  };
  function withYT(fn) { if (ytReady) fn(); else ytQueue.push(fn); }

  function startYtPoll(p, myToken) {
    clearInterval(ytPoll);
    ytPoll = setInterval(function () {
      if (myToken !== token) { clearInterval(ytPoll); return; }
      try { report(myToken, p.getCurrentTime() * 1000, p.getDuration() * 1000); } catch (e) {}
    }, 500);
  }

  // ===========================================================================
  // 2. Spotify embed (fallback) - never auto-played
  // ===========================================================================
  window.onSpotifyIframeApiReady = function (IFrameAPI) {
    embedApi = IFrameAPI;
    embedQueue.splice(0).forEach(function (fn) { fn(embedApi); });
  };
  function withEmbed(fn) { if (embedApi) fn(embedApi); else embedQueue.push(fn); }

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
    token = newToken; ended = false; lastSent = 0; spLastPos = 0; scDur = 0;
    if (!box) return;
    box.setAttribute("data-mounted", "1");

    var myToken = token;
    var autoplay = box.getAttribute("data-autoplay") === "true";
    var sdkEl = document.getElementById("bpm-sdk");
    var scFrame = document.getElementById("bpm-soundcloud");
    var spEl = document.getElementById("bpm-spotify");
    var ytEl = document.getElementById("bpm-youtube");

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

    // ---- YouTube (full tracks) ----
    if (ytEl) {
      var vid = ytEl.getAttribute("data-id");
      withYT(function () {
        if (myToken !== token || !document.body.contains(ytEl)) return;
        ytPlayer = new YT.Player(ytEl, {
          videoId: vid, width: "100%", height: "200",
          playerVars: { playsinline: 1, rel: 0 },
          events: {
            onReady: function (e) {
              if (autoplay && myToken === token) e.target.playVideo();
            },
            onStateChange: function (e) {
              if (myToken !== token) return;
              if (e.data === YT.PlayerState.PLAYING) {
                startYtPoll(e.target, myToken);
              } else if (e.data === YT.PlayerState.ENDED) {
                finish(myToken, limitFor(e.target.getDuration() * 1000));
              } else {
                clearInterval(ytPoll);
              }
            },
            onError: function (e) {
              if (myToken !== token) return;
              send("yt_error", { token: myToken, code: e.data }, true);
              finish(myToken, 0);
            }
          }
        });
      });
    }

    // ---- SoundCloud (full tracks) ----
    if (scFrame && window.SC && SC.Widget) {
      var w = SC.Widget(scFrame);
      scWidget = w;
      w.bind(SC.Widget.Events.READY, function () {
        w.getDuration(function (d) { scDur = d; });
        if (autoplay && myToken === token) w.play();
      });
      w.bind(SC.Widget.Events.PLAY, function () {
        try { if (spController && myToken === token) spController.pause(); } catch (e) {}
      });
      w.bind(SC.Widget.Events.PLAY_PROGRESS, function (e) {
        report(myToken, e.currentPosition, scDur);
      });
      w.bind(SC.Widget.Events.FINISH, function () { finish(myToken, scDur); });
    }

    // ---- Spotify embed (fallback; only plays when YOU press play) ----
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
          c.addListener("playback_update", function (e) {
            var d = e && e.data;
            if (!d || !d.duration || myToken !== token) return;
            if (!d.isPaused) {
              try { if (scWidget) scWidget.pause(); } catch (err) {}
              report(myToken, d.position, d.duration);
            }
            var nearEnd = d.position >= d.duration - 800 ||
                          (d.isPaused && d.position === 0 && spLastPos > d.duration - 2000);
            if (nearEnd) finish(myToken, limitFor(d.duration));
            spLastPos = d.position;
          });
        });
      });
    }
  }

  $(document).on("shiny:value", function (e) {
    if (e.name === "music_panel") setTimeout(mount, 0);
  });
})();
