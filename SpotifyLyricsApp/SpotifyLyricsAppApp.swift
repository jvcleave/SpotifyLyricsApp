import LyricsKit
import SpotifyKit
import SwiftUI

@main
struct SpotifyLyricsAppApp: App {
    @State private var viewModel: SpotifyLyricsViewModel

    init() {
        #if DEBUG
        if Bundle.main.object(forInfoDictionaryKey: "SPOTIFY_LYRICS_DEMO") as? String == "YES" {
            _viewModel = State(initialValue: OfflineDemo.makeViewModel())
            return
        }
        #endif
        let viewModel: SpotifyLyricsViewModel
        do {
            let configuration = try SpotifyAppConfiguration.load()
            let tokenStore = KeychainSpotifyTokenStore(
                service: "com.jvclabs.SpotifyLyricsApp.spotify",
                account: configuration.clientID
            )
            let session = SpotifySession(
                configuration: configuration,
                tokenStore: tokenStore
            )
            let authorization = SpotifyAuthorizationCoordinator(session: session)
            let monitor = SpotifyPlaybackMonitor(source: session)
            let lookup = LyricsLookupService(clientIdentifier: "SpotifyLyricsApp/0.1 (LyricsKit)")
            let lyricsService = SpotifyLyricsService(search: LyricsKitSearch(service: lookup))
            viewModel = SpotifyLyricsViewModel(
                session: session,
                authorizationCoordinator: authorization,
                monitor: monitor,
                lyrics: LyricsViewModel(service: lyricsService)
            )
        } catch {
            viewModel = SpotifyLyricsViewModel(configurationMessage: error.localizedDescription)
        }
        _viewModel = State(initialValue: viewModel)
    }

    var body: some Scene {
        Window(
            "Spotify Lyrics",
            id: "spotify-lyrics"
        ) {
            ContentView(viewModel: viewModel)
        }
        .defaultSize(
            width: 1040,
            height: 740
        )
    }
}
