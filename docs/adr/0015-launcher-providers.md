# Launcher providers: one registry line each, stateless

## Status

accepted

## Context

Launcher `@provider` entries need URL building, request/parse plumbing, a
shared parameter engine, and per-provider search state (searched term and
values, results, loading, error). The launcher panel is instantiated per
screen, so any session state held in a provider singleton would leak between
screens.

## Decision

`@provider` entries live in `providers/`, one `pragma Singleton` per
provider; `services/Providers.qml` is the registry (`providers` list +
`providerForKey`) and holds the shared param engine. Adding a provider is one
new file plus one registry line — `panels/Launcher.qml` stays
provider-agnostic.

A provider exposes `key`, `name`, `desc`, `logo`, `params`, `errorText` and
the functions `buildUrl(ctx)`, `requestArgs(url)`, `parse(text)`,
`mock(payload)`, `rows(ctx)`, `cardTitle(ctx)`, `cardHint(ctx)`; `rows(ctx)`
returns row descriptors (`key`, `title`, `titleRich`, `titleColor`,
`subtitle`, `subtitleRich`, `subtitleColor`, `glyph`, `image`, `badge`,
`badgeColor`, `action`, `copyText`).

Providers are stateless: the launcher owns the per-provider session (searched
term/values, results, loading, error) keyed by provider key. A provider with
`local: true` resolves offline: the launcher calls its `parse(term)` on every
keystroke and skips the "press Enter to look up" state, so it exposes no
`buildUrl`/`requestArgs`.

## Considered options

- Stateful provider singletons (session in the provider): rejected — the
  launcher is instantiated per screen and a singleton would leak state
  between screens.

## Consequences

A new provider never touches `panels/Launcher.qml`. Search state resets when
the launcher closes (it lives in the panel instance).
