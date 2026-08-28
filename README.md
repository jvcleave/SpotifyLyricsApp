# SpotifyLyricsApp

<img width="1470" height="1090" alt="image" src="https://github.com/user-attachments/assets/60e06700-e248-4d17-8b54-907f3f3d1ca4" />

A macOS SwiftUI app that combines **SpotifyKit** and **LyricsKit**: connect Spotify, play a song there, and retrieve its lyrics from LRCLIB.

This first milestone displays timed or plain lyrics, offers a chooser for ambiguous matches, and handles instrumental, unavailable, loading, and error states. It includes estimated playback position, but **timed-line highlighting and automatic scrolling are not implemented yet**.

Requires macOS 15.6 and Xcode with Swift 6 support.

## Open and run

Open `SpotifyLyricsApp.xcodeproj`, select the **SpotifyLyricsApp** scheme and **My Mac**, and run. Choose your signing team if necessary. Click **Connect Spotify**, approve in your browser, and return to the app. Start a song in Spotify; lyrics lookup starts automatically when the current track is received.

The current development checkout reuses the existing SpotifyHelperApp Client ID through a Git-ignored local xcconfig include. No Client Secret or token is copied. SpotifyLyricsApp has its own Keychain service, so it signs in independently and its Disconnect action does not remove SpotifyHelperApp's tokens.

## Shared dependencies

Keep these repositories alongside each other:

```text
PRIVATE/
├── LyricsApp/Packages/LyricsKit/
├── SpotifyHelperApp/Packages/SpotifyKit/
└── SpotifyLyricsApp/
```

Xcode uses relative local package references. There are no copied package sources, and neither package depends on the other. The SpotifyHelperApp and LyricsApp reference apps are unchanged.

Verified dependency checkpoints: SpotifyHelperApp `a4695a7`, LyricsApp `f3925e0`. Local references use the current sibling working trees; these are not pinned remote package versions. A portable/versioned package distribution setup is still a follow-up, not part of this first milestone.

## Configure a fresh checkout

1. Configure a Spotify developer application with **Web API** access and the redirect `http://127.0.0.1:8888/callback`.
2. Copy `Configuration/Spotify.local.xcconfig.example` to `Configuration/Spotify.local.xcconfig` and set its public Client ID. This file is ignored by Git. Alternatively, the local file can include the existing helper configuration:

   ```xcconfig
   #include "../../SpotifyHelperApp/Configuration/Spotify.local.xcconfig"
   ```

3. Build and run. A runtime `SPOTIFY_CLIENT_ID` environment variable can override the bundled Client ID during development.

End users do not obtain API keys or enter developer credentials. The app uses PKCE browser authorization with only `user-read-currently-playing`. Both outgoing network access and incoming loopback access are enabled in the sandbox. See the existing [SpotifyKit setup guide](../SpotifyHelperApp/Packages/SpotifyKit/README.md) for account restrictions and callback requirements.

Only one app can use the callback port during sign-in. Finish or cancel a sign-in attempt in the other app before connecting here. Never add a Client Secret.

## Behavior

- SpotifyKit polls every 10 seconds while monitoring is active. A local display timer estimates position between responses without extra requests. Monitoring suspends when the app becomes inactive or the Mac sleeps.
- New track identity or lookup metadata starts a new lyrics lookup. Position-only changes do not. Canceled or obsolete results cannot replace the current lyrics.
- The app maps title, the first nonempty artist, album, and duration into `LyricsMatchInput`; LyricsKit owns fallback searches, ranking, and automatic-selection decisions.
- Ambiguous results require a user choice. **Reload Lyrics** bypasses the session cache. LyricsKit continues to own rate-limit pacing.
- Up to 40 track/metadata results are cached in memory, including unavailable results and user-selected matches. Disconnect clears that cache. Nothing is written to a lyrics database.
- `LyricsContentResolver` chooses timed, plain, instrumental, or unavailable content. Timed lyrics are currently displayed as a static timestamped list.
- A lyrics error does not disconnect Spotify. Temporary Spotify errors retain the last clearly labeled track and its lyrics; no playback or unsupported content clears the lyrics panel.
- Spotify remains the player. This app does not play, download, record, pause, seek, or skip Spotify audio. No artwork is fetched.

## Verify

```sh
swift test --package-path ../SpotifyHelperApp/Packages/SpotifyKit
swift test --package-path ../LyricsApp/Packages/LyricsKit
xcodebuild -project SpotifyLyricsApp.xcodeproj -scheme SpotifyLyricsApp -destination 'platform=macOS' test build
```

The app has hostless tests: they compile the presentation and integration code without launching the production app. Tests use injected playback/lyrics responses and in-memory tokens; they do not contact Spotify or LRCLIB, open a browser, or access Keychain.

For manual UI checks without accounts, a Debug-only fixture mode is available:

```sh
xcodebuild -project SpotifyLyricsApp.xcodeproj -scheme SpotifyLyricsApp \
  -configuration Debug -derivedDataPath /tmp/SpotifyLyricsOfflineDemo \
  SPOTIFY_LYRICS_DEMO=YES \
  PRODUCT_BUNDLE_IDENTIFIER=com.jvclabs.SpotifyLyricsApp.OfflineDemo build
```

Launch the resulting app in `/tmp/SpotifyLyricsOfflineDemo/Build/Products/Debug`. It is visibly labeled **OFFLINE DEMO** and uses no network or Keychain. **Reload Lyrics** cycles through timed lyrics, candidates, instrumental, unavailable, and error fixtures. This is an explicit development mode, never a fallback for real failures. The default setting is `NO`; Release builds do not contain the fixture implementation.

See [the tracking plan](docs/ImplementationPlan.md) for completed work and live-account checks still to do.
