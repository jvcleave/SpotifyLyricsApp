# SpotifyLyricsApp Implementation Plan

## First milestone: current song to displayed lyrics

- [x] Create a separate macOS 15.6 / Swift 6 app beside the existing projects.
- [x] Follow the existing SwiftUI/view-model/service guidance.
- [x] Reference SpotifyKit and LyricsKit without copying their sources or coupling them.
- [x] Reuse package browser sign-in, monitoring, and position estimates.
- [x] Use separate Keychain storage; keep Client ID configuration local and ignored.
- [x] Translate Spotify metadata into LyricsKit lookup values without inventing file URLs.
- [x] Reuse shared ranking and LyricsContentResolver behavior.
- [x] Display timed lyrics as a static list and plain lyrics as selectable text.
- [x] Offer candidate selection when an automatic match is not justified.
- [x] Show loading, instrumental, unavailable, and recoverable failure states.
- [x] Cancel outdated lookups and reject late results by track key and generation.
- [x] Cache up to 40 results/choices in memory; explicit reload bypasses cache.
- [x] Keep position ticks independent of lyric lookup and display collection construction.
- [x] Clear current lyrics for empty/unsupported playback and disconnect.
- [x] Keep lyrics errors separate from Spotify connection errors.
- [x] Add offline UI fixtures and hostless app integration tests.
- [x] Run both package suites and a signed macOS app build/test.
- [ ] Complete the live-account checks below.

## Verification record — August 28, 2026

- SpotifyKit: 58 tests passed.
- LyricsKit: 13 tests passed, including parameterized cases.
- SpotifyLyricsApp: 25 tests passed.
- macOS Debug app build and sandbox network entitlements verified.
- Limited offline UI inspection covered the timed layout and candidate-to-plain selection. No real account, browser authorization, Keychain, or external lyrics requests were used. The owner prefers to perform the remaining manual checks; agent-driven UI checks have stopped.
- Existing LyricsApp and SpotifyHelperApp working trees remain unchanged.

Coverage includes metadata translation, shared content resolution, candidate selection, unavailable/instrumental results, caching and eviction, repeated position samples, metadata changes, stale completion, cancellation, reload, independent error states, disconnect, and monitoring lifecycle.

## Live-account checklist

- [ ] Open the normal app, sign into Spotify, and play a familiar song.
- [ ] Confirm current-song metadata and real lyrics retrieval.
- [ ] Confirm timed and plain results, where available.
- [ ] Try a recording that requires candidate selection; verify the chosen version.
- [ ] Change tracks quickly; no previous lyrics should appear under the new song.
- [ ] Check unavailable and instrumental recordings.
- [ ] Reload lyrics and recover from a temporary connection error.
- [ ] Pause, seek, and change tracks in Spotify; check the next position sample.
- [ ] Stop/start monitoring, switch away/back, and sleep/wake.
- [ ] Disconnect; both track and lyrics should clear without changing the helper app's saved connection.
- [ ] Quit/relaunch; verify this app's own saved authorization restores.

Live behavior has not been claimed complete based on mocked tests. The owner previously verified SpotifyHelperApp sign-in and current-track retrieval; SpotifyLyricsApp is a new consumer with separate token storage.

## Next milestone: timed following

- [ ] Select the active timed line using SpotifyKit's monotonic position estimate.
- [ ] Keep active-line state narrow; do not rebuild lyric rows on every tick.
- [ ] Highlight and optionally follow the active line, respecting manual scrolling.
- [ ] Re-anchor after pause, resume, seek, and track changes.
- [ ] Freeze and label stale position rather than continuing artificial progress.
- [ ] Measure real drift before promising synchronization accuracy.

The owner has recorded the synchronized-lyrics policy checkpoint as cleared. This plan does not claim broader Spotify approval or alter account/distribution requirements.

## Distribution and repository follow-up

- [x] Configure the owner-provided remote: [jvcleave/SpotifyLyricsApp](https://github.com/jvcleave/SpotifyLyricsApp).
- [ ] Replace development-only sibling paths with a portable shared package distribution strategy.
- [ ] Keep package versions reproducible without duplicating implementations.
- [ ] Review privacy, service terms, account quotas, and release requirements before distribution.

The first milestone deliberately excludes timed highlighting, automatic lyric scrolling, playback controls, artwork, and changes to either existing reference app.
