# SpotifyLyricsApp Agent Guidance

## Scope

This macOS SwiftUI app composes the existing SpotifyKit and LyricsKit packages. It must not copy their OAuth, token, networking, matching, parsing, pacing, or position-estimation implementations. Neither package depends on this app or the other package. Local sibling package references are intentional for initial development.

Use Swift 6, complete strict concurrency, and macOS 15.6. Follow the same SwiftUI/view-model/service boundaries as LyricsApp and SpotifyHelperApp.

## Architecture

- Views own layout, styling, presentation, and short-lived local interaction. They send semantic actions to view models.
- Views never call domain services, parse lyrics, construct lookup inputs, or sort/filter/format domain collections in body.
- Use focused concrete child views with plain display values and action closures. A child may receive a focused view model when that provides an independent Observation boundary.
- SwiftUI-observed models are @MainActor and @Observable. Created models use @State; received models are plain stored properties. Use @Bindable only at editing controls.
- Mark services, tasks, caches, generations, and other non-presentation bookkeeping @ObservationIgnored.
- Keep track/position presentation separate from lyrics presentation. Display ticks must not restart lookup or rebuild lyric collections.
- SpotifyLyricsService is the app-specific bridge between package values. SpotifyKit owns Spotify behavior; LyricsKit owns lyrics matching and resolution.
- Every mutable service owns its isolation. Cross boundaries with Sendable values, not views or view models. Do not use @MainActor to hide service concurrency problems.
- Construct long-lived dependencies at the app root and inject them. The owner of work owns explicit, idempotent cleanup.
- Cancel old lyric lookups and validate both track identity and request generation before publication.
- Keep loading, candidates, content, instrumental, unavailable, and failure states explicit. Lyrics failures must not disconnect Spotify.
- Give repeated rows stable IDs from their source records. Plain lyrics can remain one text value instead of inventing row identities.
- Never copy credentials or tokens between apps. Use a distinct Keychain service for this app.

## Swift style

- Prefer explicit imperative flow and obvious local mutation.
- Use switch for one-value branching; do not introduce guard just for compactness.
- Avoid fluent chains that hide mutation or side effects.
- Do not create one-use helpers merely to shorten a caller; ownership, test, and view boundaries are valid reasons.
- Do not add extensions to repository-owned types.
- Use descriptive loop names, not vm/item/obj.
- Avoid semantic prepositions in external parameter labels.
- Keep one-argument calls on one line when they fit. Wrap declarations and calls with multiple arguments across lines.
- Preserve existing style and avoid unrelated formatting changes.

## Verification

Run both dependency test suites and the hostless app tests:

```sh
swift test --package-path ../SpotifyHelperApp/Packages/SpotifyKit
swift test --package-path ../LyricsApp/Packages/LyricsKit
xcodebuild -project SpotifyLyricsApp.xcodeproj -scheme SpotifyLyricsApp -destination 'platform=macOS' test build
```

Tests must use injected fake responses, local fixtures, and in-memory token stores. Never launch the production composition root, contact Spotify/LRCLIB, open the browser, or touch the real Keychain in tests or previews. Add focused tests for metadata translation, result resolution, ambiguous matches, track changes, stale responses, caching, cancellation, retry, and disconnect.

Before handoff, check boundaries, cleanup, source identity, independent error states, and the full test/build results. Report live-account checks separately from automated verification.

Write summaries for humans: clear outcomes, concise limitations, and the next useful step.
