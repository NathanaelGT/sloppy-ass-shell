# Merge events are screen-scoped, tagged at the call site

Pill merges (Banner over clock, music title over clock) are broadcast from
singletons (`Notifs.bannerPhase`, `Mpd.song`), so without care every screen's
bar reacts and HDMI-A-1 shows a half-morph: the cheap visuals fire but the
geometry that actually combines the pills stays eDP-1-pinned. Decided: every
merge belongs to exactly one screen. Notification merges stay eDP-1 (the
Banner's ADR-0005 pinning); other screens get only a bell wiggle with a live
badge. Music merges are tagged at the call site — bar-pill right-click and
music-panel actions record their screen on the Mpd command — and merge on the
tagged screen; automatic track advance and every external trigger (other MPD
clients, future MPRIS) merge on eDP-1 only, so the work monitor never gets an
untagged morph.

## Considered Options

- Tagging at the call site (chosen): exact, no inference; the shell knows
  which panel or pill each command came from.
- Elapsed-time heuristics to distinguish user skip from natural end of track
  (rejected): guesses, and external clients still look identical to
  auto-advance.
- Per-screen service instances (rejected): the services are singletons by
  design; duplicating MPD/Notifs state per screen to carry one screen hint is
  far heavier than a string tag.

## Consequences

- Singleton property changes must never drive visuals on a screen the event
  did not target; per-screen bar widgets compare the tag against their own
  screen instead of reacting unconditionally.
- Untagged playback commands (any client outside the shell) behave as
  automatic events, so future MPRIS integration inherits eDP-1-only merges
  unless it explicitly tags a screen.
