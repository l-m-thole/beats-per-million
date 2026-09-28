// =============================================================================
// Beats per Million - in-app player bridge
// -----------------------------------------------------------------------------
// Drives the Spotify (IFrame API) and SoundCloud (Widget API) embeds rendered
// in the Listen panel and reports back to Shiny:
//   input$player_progress = {token, frac, pos, dur}  (~2x per second)
//   input$player_ended    = {token, t}                (song finished or capped)
// Each song plays in full, capped at 3 minutes. `token` identifies the slot the
// player was built for, so late events from an old player are ignored in R.
// =============================================================================
(function () {
  var CAP_MS = 180000;       // play at most 3 minutes per song
  var SEND_EVERY_MS = 500;   // progress throttle

  var spApi = null, spQueue = [];
  var spController = null, scWidget = null;
  var token = null, ended = false, lastSent = 0, spLastPos = 0, scDur = 0;

  // Spotify IFrame API calls this once its script has loaded
  window.onSpotifyIframeApiReady = function (IFrameAPI) {
    spApi = IFrameAPI;
    spQueue.splice(0).forEach(function (fn) { fn(spApi); });
  };
  function withSpotify(fn) { if (spApi) fn(spApi); else spQueue.push(fn); }

  // If the Spotify IFrame API can't load (blocked, offline, old viewer), fall
  // back to a plain embed so there is always a player - just without progress
  // events (ball won't move, no auto-advance for that song).
  function plainSpotifyEmbed(el, uri) {
    var id = (uri || "").split(":").pop();
    var f = document.createElement("iframe");
    f.src = "https://open.spotify.com/embed/track/" + id;
    f.width = "100%"; f.height = "152"; f.frameBorder = "0";
    f.allow = "autoplay; clipboard-write; encrypted-media; fullscreen; picture-in-picture";
    f.style.borderRadius = "12px";
    el.replaceWith(f);
  }

  function send(name, value, event) {
    if (window.Shiny && Shiny.setInputValue) {
      Shiny.setInputValue(name, value, event ? { priority: "event" } : undefined);
    }
  }

  function limitFor(dur) { return Math.min(dur > 0 ? dur : CAP_MS, CAP_MS); }

  function report(myToken, pos, dur) {
    if (ended || myToken !== token) return;
    var limit = limitFor(dur);
    var frac = Math.max(0, Math.min(1, pos / limit));
    var now = Date.now();
    if (now - lastSent >= SEND_EVERY_MS) {
      lastSent = now;
      send("player_progress", { token: token, frac: frac, pos: pos, dur: limit });
    }
    if (pos >= limit - 300) finish(myToken, limit);
  }

  function finish(myToken, limit) {
    if (ended || myToken !== token) return;
    ended = true;
    try { if (spController) spController.pause(); } catch (e) {}
    try { if (scWidget) scWidget.pause(); } catch (e) {}
    send("player_progress", { token: token, frac: 1, pos: limit || 0, dur: limit || 0 });
    send("player_ended", { token: token, t: Date.now() }, true);
  }

  function mount() {
    var box = document.getElementById("bpm-player");
    var newToken = box ? box.getAttribute("data-token") : null;
    if (newToken === token && box && box.getAttribute("data-mounted")) return;

    // Old player DOM is gone (Shiny replaced it) - just drop references
    try { if (spController && spController.destroy) spController.destroy(); } catch (e) {}
    spController = null; scWidget = null;
    token = newToken; ended = false; lastSent = 0; spLastPos = 0; scDur = 0;
    if (!box) return;
    box.setAttribute("data-mounted", "1");

    var myToken = token;
    var autoplay = box.getAttribute("data-autoplay") === "true";
    var scFrame = document.getElementById("bpm-soundcloud");
    var spEl = document.getElementById("bpm-spotify");
    // SoundCloud plays full tracks without a login, so it's preferred for autoplay
    var preferred = scFrame ? "sc" : (spEl ? "sp" : null);

    // ---- SoundCloud ----
    if (scFrame && window.SC && SC.Widget) {
      var w = SC.Widget(scFrame);
      scWidget = w;
      w.bind(SC.Widget.Events.READY, function () {
        w.getDuration(function (d) { scDur = d; });
        if (autoplay && preferred === "sc" && myToken === token) w.play();
      });
      w.bind(SC.Widget.Events.PLAY, function () {
        try { if (spController && myToken === token) spController.pause(); } catch (e) {}
      });
      w.bind(SC.Widget.Events.PLAY_PROGRESS, function (e) {
        report(myToken, e.currentPosition, scDur);
      });
      w.bind(SC.Widget.Events.FINISH, function () { finish(myToken, scDur); });
    }

    // ---- Spotify ----
    if (spEl) {
      var uri = spEl.getAttribute("data-uri");
      var fallback = setTimeout(function () {
        if (!spApi && document.body.contains(spEl)) plainSpotifyEmbed(spEl, uri);
      }, 4000);
      withSpotify(function (api) {
        clearTimeout(fallback);
        if (myToken !== token || !document.body.contains(spEl)) return;
        api.createController(spEl, { uri: uri, width: "100%", height: 152 }, function (c) {
          if (myToken !== token) { try { c.destroy(); } catch (e) {} return; }
          spController = c;
          c.addListener("ready", function () {
            if (autoplay && preferred === "sp" && myToken === token) c.play();
          });
          c.addListener("playback_update", function (e) {
            var d = e && e.data;
            if (!d || !d.duration || myToken !== token) return;
            if (!d.isPaused) {
              try { if (scWidget) scWidget.pause(); } catch (err) {}
              report(myToken, d.position, d.duration);
            }
            // Track ran out (Spotify resets to 0 and pauses at the end)
            var nearEnd = d.position >= d.duration - 800 ||
                          (d.isPaused && d.position === 0 && spLastPos > d.duration - 2000);
            if (nearEnd) finish(myToken, limitFor(d.duration));
            spLastPos = d.position;
          });
        });
      });
    }
  }

  // Re-mount whenever Shiny re-renders the Listen panel
  $(document).on("shiny:value", function (e) {
    if (e.name === "music_panel") setTimeout(mount, 0);
  });
})();
