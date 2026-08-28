import Foundation
import LyricsKit
import SpotifyKit
import Testing

@MainActor
@Suite(.timeLimit(.minutes(1))) struct LyricsIntegrationTests {
    @Test func translatesSpotifyMetadataWithoutInventingAFile() {
        let track = lyricTrack(
            id: "song",
            title: "  Cafe\u{301}  ",
            artists: ["  ", " Primary Artist ", "Guest"],
            duration: 201_125
        )
        let input = SpotifyLyricsService.lookupInput(track: track)
        #expect(input.title == "Café")
        #expect(input.artist == "Primary Artist")
        #expect(input.album == "Album")
        #expect(input.duration == 201.125)
        let missing = SpotifyLyricsService.lookupInput(track: lyricTrack(
            id: "missing",
            artists: [],
            duration: 0
        ))
        #expect(missing.artist.isEmpty)
        #expect(missing.duration == nil)
    }

    @Test func timedLyricsUseSharedParserAndStableLineIDs() async {
        let search = QueuedLyricsSearch(outcomes: [.match(lyricResult(
            id: 1,
            synced: "[00:01.00]First fixture line\n[00:03.50]Second fixture line"
        ))])
        let viewModel = LyricsViewModel(service: SpotifyLyricsService(search: search))
        viewModel.showTrack(lyricTrack(id: "song"))
        #expect(viewModel.state == .loading("Song"))
        await viewModel.workTask?.value
        if case .content(let content) = viewModel.state,
           case .timed(let lines) = content.body {
            #expect(content.resultID == 1)
            #expect(lines.count == 2)
            #expect(lines[0].text == "First fixture line")
            #expect(lines[1].timestamp == "0:03")
            #expect(lines[0].id != lines[1].id)
            #expect(content.formatText.contains("static display"))
        } else {
            Issue.record("Expected parsed timed lyrics")
        }
    }

    @Test func malformedTimedLyricsFallBackToPlainThroughLyricsKit() async {
        let search = QueuedLyricsSearch(outcomes: [.match(lyricResult(
            id: 2,
            plain: "Plain fixture text",
            synced: "Not an LRC timestamp"
        ))])
        let viewModel = LyricsViewModel(service: SpotifyLyricsService(search: search))
        viewModel.showTrack(lyricTrack(id: "song"))
        await viewModel.workTask?.value
        if case .content(let content) = viewModel.state {
            #expect(content.body == .plain("Plain fixture text"))
        } else {
            Issue.record("Expected shared plain-text fallback")
        }
    }

    @Test func instrumentalAndUnavailableAreNotErrors() async {
        let search = QueuedLyricsSearch(outcomes: [
            .match(lyricResult(
                id: 3,
                plain: "Ignored fixture text",
                instrumental: true
            )),
            .match(lyricResult(id: 4)),
            .notFound
        ])
        let viewModel = LyricsViewModel(service: SpotifyLyricsService(search: search))
        viewModel.showTrack(lyricTrack(id: "instrumental"))
        await viewModel.workTask?.value
        #expect(viewModel.state == .instrumental("Song — Artist"))
        viewModel.showTrack(lyricTrack(id: "empty-result"))
        await viewModel.workTask?.value
        #expect(viewModel.state == .unavailable)
        viewModel.showTrack(lyricTrack(id: "not-found"))
        await viewModel.workTask?.value
        #expect(viewModel.state == .unavailable)
        #expect(viewModel.canRetry)
    }

    @Test func positionUpdatesDoNotRepeatLyricsLookup() async {
        let search = QueuedLyricsSearch(outcomes: [.notFound])
        let viewModel = LyricsViewModel(service: SpotifyLyricsService(search: search))
        viewModel.showTrack(lyricTrack(id: "song"))
        await viewModel.workTask?.value
        viewModel.showTrack(lyricTrack(
            id: "song",
            progress: 45_000,
            isPlaying: false
        ))
        await viewModel.workTask?.value
        #expect(await search.callCount == 1)
    }

    @Test func metadataChangeForSameSpotifyIDTriggersFreshLookup() async {
        let search = QueuedLyricsSearch(outcomes: [.notFound, .notFound])
        let viewModel = LyricsViewModel(service: SpotifyLyricsService(search: search))
        viewModel.showTrack(lyricTrack(id: "song"))
        await viewModel.workTask?.value
        viewModel.showTrack(lyricTrack(
            id: "song",
            title: "Corrected Song"
        ))
        await viewModel.workTask?.value
        #expect(await search.callCount == 2)
    }

    @Test func cachedTrackIsReusedAndReloadBypassesCache() async {
        let search = QueuedLyricsSearch(outcomes: [
            .match(lyricResult(
                id: 1,
                plain: "Cached fixture"
            )),
            .notFound,
            .match(lyricResult(
                id: 2,
                plain: "Reloaded fixture"
            ))
        ])
        let viewModel = LyricsViewModel(service: SpotifyLyricsService(search: search))
        viewModel.showTrack(lyricTrack(id: "first"))
        await viewModel.workTask?.value
        let first = viewModel.state
        viewModel.showTrack(lyricTrack(id: "second"))
        await viewModel.workTask?.value
        viewModel.showTrack(lyricTrack(id: "first"))
        #expect(viewModel.state == first)
        #expect(await search.callCount == 2)
        viewModel.retryLyrics()
        await viewModel.workTask?.value
        #expect(await search.callCount == 3)
        #expect(viewModel.state != first)
    }

    @Test func ambiguousResultsRequireSelectionAndRememberThatChoice() async {
        let result = lyricResult(
            id: 7,
            plain: "Selected fixture"
        )
        let candidate = RankedLyricsCandidate(
            result: result,
            score: 70,
            durationDifference: 2,
            exactTitle: true,
            exactArtist: false
        )
        let search = QueuedLyricsSearch(outcomes: [.candidates([candidate, candidate]), .notFound])
        let viewModel = LyricsViewModel(service: SpotifyLyricsService(search: search))
        viewModel.showTrack(lyricTrack(id: "first"))
        await viewModel.workTask?.value
        if case .candidates(let choices) = viewModel.state {
            #expect(choices.count == 1)
            #expect(choices[0].id == 7)
        } else {
            Issue.record("An ambiguous result must not be selected automatically")
        }
        viewModel.selectCandidate(id: 999)
        if case .candidates = viewModel.state {} else { Issue.record("Unknown selection changed state") }
        viewModel.selectCandidate(id: 7)
        await viewModel.workTask?.value
        let selectedState = viewModel.state
        if case .content(let content) = selectedState {
            #expect(content.resultID == 7)
        } else {
            Issue.record("Expected selected lyrics")
        }
        viewModel.showTrack(lyricTrack(id: "second"))
        await viewModel.workTask?.value
        viewModel.selectCandidate(id: 7)
        #expect(viewModel.state == .unavailable)
        viewModel.showTrack(lyricTrack(id: "first"))
        #expect(viewModel.state == selectedState)
        #expect(await search.callCount == 2)
    }

    @Test func lateOldTrackCannotOverwriteNewLyrics() async {
        let search = ControlledLyricsSearch()
        let viewModel = LyricsViewModel(service: SpotifyLyricsService(search: search))
        viewModel.showTrack(lyricTrack(
            id: "old",
            title: "Old"
        ))
        let oldTask = viewModel.workTask
        await search.waitForRequest("Old")
        viewModel.showTrack(lyricTrack(
            id: "new",
            title: "New"
        ))
        await search.waitForRequest("New")
        await search.complete(
            title: "New",
            result: .match(lyricResult(
                id: 22,
                plain: "Current fixture"
            ))
        )
        await viewModel.workTask?.value
        let currentState = viewModel.state
        await search.complete(
            title: "Old",
            result: .match(lyricResult(
                id: 11,
                plain: "Obsolete fixture"
            ))
        )
        await oldTask?.value
        #expect(viewModel.state == currentState)
        if case .content(let content) = viewModel.state {
            #expect(content.resultID == 22)
        } else { Issue.record("Current lyrics were lost") }
    }

    @Test func clearCancelsPendingLyricsAndIgnoresLateCompletion() async {
        let search = ControlledLyricsSearch()
        let viewModel = LyricsViewModel(service: SpotifyLyricsService(search: search))
        viewModel.showTrack(lyricTrack(id: "song"))
        let pendingTask = viewModel.workTask
        await search.waitForRequest("Song")
        viewModel.clear(clearCache: true)
        #expect(viewModel.state == .waiting)
        #expect(!viewModel.canRetry)
        await search.complete(
            title: "Song",
            result: .match(lyricResult(
                id: 1,
                plain: "Late fixture"
            ))
        )
        await pendingTask?.value
        #expect(viewModel.state == .waiting)
    }

    @Test func failureWaitsForExplicitRetryAndCanRecover() async {
        let search = QueuedLyricsSearch(
            outcomes: [.notFound],
            failures: 1
        )
        let viewModel = LyricsViewModel(service: SpotifyLyricsService(search: search))
        viewModel.showTrack(lyricTrack(id: "song"))
        await viewModel.workTask?.value
        if case .failed(let message) = viewModel.state {
            #expect(message.contains("Offline"))
        } else { Issue.record("Expected recoverable lyrics error") }
        viewModel.showTrack(lyricTrack(id: "song"))
        #expect(await search.callCount == 1)
        viewModel.retryLyrics()
        await viewModel.workTask?.value
        #expect(viewModel.state == .unavailable)
        #expect(await search.callCount == 2)
    }

    @Test func disconnectStyleClearDropsTheSessionCache() async {
        let search = QueuedLyricsSearch(outcomes: [.notFound, .notFound])
        let viewModel = LyricsViewModel(service: SpotifyLyricsService(search: search))
        viewModel.showTrack(lyricTrack(id: "song"))
        await viewModel.workTask?.value
        viewModel.clear(clearCache: true)
        viewModel.showTrack(lyricTrack(id: "song"))
        await viewModel.workTask?.value
        #expect(await search.callCount == 2)
    }

    @Test func cacheIsBounded() async {
        let search = QueuedLyricsSearch(outcomes: [])
        let viewModel = LyricsViewModel(service: SpotifyLyricsService(search: search))
        for trackNumber in 0..<41 {
            viewModel.showTrack(lyricTrack(id: "track-\(trackNumber)"))
            await viewModel.workTask?.value
        }
        viewModel.showTrack(lyricTrack(id: "track-0"))
        await viewModel.workTask?.value
        #expect(await search.callCount == 42)
    }
}

private func lyricTrack(
    id: String,
    title: String = "Song",
    artists: [String] = ["Artist"],
    duration: Int = 120_000,
    progress: Int = 1_000,
    isPlaying: Bool = true
) -> SpotifyTrackPlayback {
    SpotifyTrackPlayback(
        id: id,
        title: title,
        artists: artists,
        albumTitle: "Album",
        durationMilliseconds: duration,
        progressMilliseconds: progress,
        isPlaying: isPlaying,
        playbackStateChangedAt: nil,
        sampledAt: Date(),
        spotifyURL: nil
    )
}

private func lyricResult(
    id: Int,
    plain: String? = nil,
    synced: String? = nil,
    instrumental: Bool = false
) -> LyricsResult {
    LyricsResult(
        id: id,
        trackName: "Song",
        artistName: "Artist",
        albumName: "Album",
        duration: 120,
        instrumental: instrumental,
        plainLyrics: plain,
        syncedLyrics: synced
    )
}

private actor QueuedLyricsSearch: LyricsSearching {
    private var outcomes: [LyricsLookupOutcome]
    private var failures: Int
    private(set) var callCount = 0

    init(
        outcomes: [LyricsLookupOutcome],
        failures: Int = 0
    ) {
        self.outcomes = outcomes
        self.failures = failures
    }

    func findLyrics(input: LyricsMatchInput) throws -> LyricsLookupOutcome {
        callCount += 1
        if failures > 0 {
            failures -= 1
            throw LRCLibServiceError.network("Offline fixture")
        }
        if outcomes.isEmpty { return .notFound }
        return outcomes.removeFirst()
    }
}

/// Deliberately ignores cancellation to prove that stale publication is guarded.
private actor ControlledLyricsSearch: LyricsSearching {
    private var pending: [String: CheckedContinuation<LyricsLookupOutcome, Never>] = [:]
    private var waiters: [String: CheckedContinuation<Void, Never>] = [:]

    func findLyrics(input: LyricsMatchInput) async -> LyricsLookupOutcome {
        await withCheckedContinuation { continuation in
            pending[input.title] = continuation
            waiters.removeValue(forKey: input.title)?.resume()
        }
    }

    func waitForRequest(_ title: String) async {
        if pending[title] == nil {
            await withCheckedContinuation { waiters[title] = $0 }
        }
    }

    func complete(
        title: String,
        result: LyricsLookupOutcome
    ) {
        pending.removeValue(forKey: title)?.resume(returning: result)
    }
}
