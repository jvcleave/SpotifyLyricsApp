#if DEBUG
import Foundation
import LyricsKit
import SpotifyKit

/// Explicit opt-in UI fixtures. Never used as a fallback for a real failure.
@MainActor
enum OfflineDemo {
    static func makeViewModel() -> SpotifyLyricsViewModel {
        let session = SpotifySession(
            configuration: SpotifyConfiguration(clientID: "offline-demo"),
            transport: DemoTransport(),
            tokenStore: DemoTokenStore()
        )
        let service = SpotifyLyricsService(search: DemoLyricsSearch())
        return SpotifyLyricsViewModel(
            session: session,
            authorizationCoordinator: DemoAuthorization(),
            monitor: SpotifyPlaybackMonitor(source: session),
            lyrics: LyricsViewModel(service: service),
            modeNotice: "OFFLINE DEMO · no network or Keychain"
        )
    }
}

private struct DemoAuthorization: SpotifyAuthorizing {
    func connect() async throws {}
    func cancel() async {}
}

private struct DemoTransport: SpotifyHTTPTransport {
    func send(_ request: URLRequest) async throws -> SpotifyHTTPResponse {
        let body = """
        {"is_playing":true,"currently_playing_type":"track","progress_ms":63000,
         "item":{"id":"offline-song","name":"A Song for the Demo",
                 "artists":[{"name":"Sample Artist"}],"album":{"name":"Local Fixtures"},
                 "duration_ms":210000}}
        """
        return SpotifyHTTPResponse(
            data: Data(body.utf8),
            statusCode: 200
        )
    }
}

private actor DemoTokenStore: SpotifyTokenStoring {
    private var token: SpotifyToken? = SpotifyToken(
        accessToken: "offline-fixture",
        refreshToken: "offline-fixture",
        tokenType: "Bearer",
        scopes: ["user-read-currently-playing"],
        expiresAt: .distantFuture
    )
    func load() -> SpotifyToken? { token }
    func save(_ token: SpotifyToken) { self.token = token }
    func delete() { token = nil }
}

private actor DemoLyricsSearch: LyricsSearching {
    private var requestCount = 0

    func findLyrics(input: LyricsMatchInput) throws -> LyricsLookupOutcome {
        let phase = requestCount % 5
        requestCount += 1
        let result = LyricsResult(
            id: 100,
            trackName: input.title,
            artistName: input.artist,
            albumName: input.album,
            duration: input.duration,
            instrumental: phase == 2,
            plainLyrics: "These are local demonstration lines.\nNo song lyrics were downloaded.",
            syncedLyrics: """
            [00:00.00]A quiet window opens to the morning
            [00:15.00]The current song arrives with a name
            [00:30.00]A little space for words and music
            [00:45.00]And room for longer lines to wrap naturally across the page
            [01:00.00]The clock moves on beside the story
            [01:15.00]These words are only demonstration data
            """
        )
        switch phase {
        case 1:
            let alternate = LyricsResult(
                id: 101,
                trackName: input.title + " (Alternate)",
                artistName: input.artist,
                albumName: "Another Recording",
                duration: 215,
                instrumental: false,
                plainLyrics: "A second local fixture.\nThis choice demonstrates plain lyrics.",
                syncedLyrics: nil
            )
            return .candidates([
                RankedLyricsCandidate(
                    result: result,
                    score: 80,
                    durationDifference: 0,
                    exactTitle: true,
                    exactArtist: true
                ),
                RankedLyricsCandidate(
                    result: alternate,
                    score: 70,
                    durationDifference: 5,
                    exactTitle: false,
                    exactArtist: true
                )
            ])
        case 3: return .notFound
        case 4: throw LRCLibServiceError.network("Offline fixture. Reload to recover.")
        default: return .match(result)
        }
    }
}
#endif
