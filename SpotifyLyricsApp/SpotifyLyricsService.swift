import Foundation
import LyricsKit
import SpotifyKit

/// Injectable only at the lyrics lookup boundary; matching stays in LyricsKit.
protocol LyricsSearching: Sendable {
    func findLyrics(input: LyricsMatchInput) async throws -> LyricsLookupOutcome
}

struct LyricsKitSearch: LyricsSearching {
    let service: LyricsLookupService

    func findLyrics(input: LyricsMatchInput) async throws -> LyricsLookupOutcome {
        try await service.findLyrics(input: input)
    }
}

struct LyricsTrackKey: Hashable, Sendable {
    let id: String
    let title: String
    let artists: [String]
    let album: String
    let durationMilliseconds: Int

    init(track: SpotifyTrackPlayback) {
        id = track.id
        title = track.title
        artists = track.artists
        album = track.albumTitle
        durationMilliseconds = track.durationMilliseconds
    }
}

struct LyricsSelection: Sendable {
    let result: LyricsResult
    let content: ResolvedLyricsContent
}

enum LyricsSearchOutcome: Sendable {
    case match(LyricsSelection)
    case candidates([RankedLyricsCandidate])
    case notFound
}

/// App-specific translation only. Neither package needs to know the other exists.
actor SpotifyLyricsService {
    private let search: any LyricsSearching
    private let resolver: LyricsContentResolver

    init(
        search: any LyricsSearching,
        resolver: LyricsContentResolver = LyricsContentResolver()
    ) {
        self.search = search
        self.resolver = resolver
    }

    static func lookupInput(track: SpotifyTrackPlayback) -> LyricsMatchInput {
        var primaryArtist = ""
        for artist in track.artists {
            let trimmedArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedArtist.isEmpty {
                primaryArtist = trimmedArtist
                break
            }
        }
        let duration = track.durationMilliseconds > 0 ? Double(track.durationMilliseconds) / 1_000 : nil
        return LyricsMatchInput(
            title: track.title.trimmingCharacters(in: .whitespacesAndNewlines),
            artist: primaryArtist,
            album: track.albumTitle.trimmingCharacters(in: .whitespacesAndNewlines),
            duration: duration
        )
    }

    func findLyrics(track: SpotifyTrackPlayback) async throws -> LyricsSearchOutcome {
        let input = Self.lookupInput(track: track)
        if input.title.isEmpty { return .notFound }
        let outcome = try await search.findLyrics(input: input)
        try Task.checkCancellation()
        switch outcome {
        case .match(let result):
            return .match(select(result: result))
        case .candidates(let candidates):
            return candidates.isEmpty ? .notFound : .candidates(candidates)
        case .notFound:
            return .notFound
        }
    }

    func select(result: LyricsResult) -> LyricsSelection {
        LyricsSelection(
            result: result,
            content: resolver.resolve(result: result)
        )
    }
}
