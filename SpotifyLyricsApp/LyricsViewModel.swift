import Foundation
import LyricsKit
import Observation
import SpotifyKit

@MainActor
@Observable
final class LyricsViewModel {
    private(set) var state: LyricsViewState = .waiting

    @ObservationIgnored private let service: SpotifyLyricsService?
    @ObservationIgnored private var track: SpotifyTrackPlayback?
    @ObservationIgnored private var key: LyricsTrackKey?
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var candidates: [Int: LyricsResult] = [:]
    @ObservationIgnored private var cache: [LyricsTrackKey: LyricsSearchOutcome] = [:]
    @ObservationIgnored private var cacheOrder: [LyricsTrackKey] = []
    @ObservationIgnored private(set) var workTask: Task<Void, Never>?

    init(service: SpotifyLyricsService?) {
        self.service = service
    }

    deinit { workTask?.cancel() }

    func showTrack(_ track: SpotifyTrackPlayback) {
        let nextKey = LyricsTrackKey(track: track)
        if key == nextKey { return }
        workTask?.cancel()
        generation = UUID()
        self.track = track
        key = nextKey
        candidates = [:]
        if let cached = cache[nextKey] {
            apply(cached)
        } else {
            loadLyrics()
        }
    }

    func retryLyrics() {
        if let key {
            cache.removeValue(forKey: key)
            cacheOrder.removeAll { $0 == key }
            loadLyrics()
        }
    }

    func selectCandidate(id: Int) {
        if let result = candidates[id], let service, let key, let track {
            workTask?.cancel()
            generation = UUID()
            let requestGeneration = generation
            state = .loading(track.title)
            workTask = Task { [weak self] in
                let selection = await service.select(result: result)
                if Task.isCancelled { return }
                if let self, self.key == key, generation == requestGeneration {
                    let outcome = LyricsSearchOutcome.match(selection)
                    remember(
                        outcome: outcome,
                        key: key
                    )
                    apply(outcome)
                }
            }
        }
    }

    func clear(clearCache: Bool = false) {
        workTask?.cancel()
        generation = UUID()
        track = nil
        key = nil
        candidates = [:]
        state = .waiting
        if clearCache {
            cache = [:]
            cacheOrder = []
        }
    }

    var canRetry: Bool {
        switch state {
        case .content, .candidates, .instrumental, .unavailable, .failed: true
        case .waiting, .loading: false
        }
    }

    private func loadLyrics() {
        if let track, let key, let service {
            workTask?.cancel()
            generation = UUID()
            let requestGeneration = generation
            candidates = [:]
            state = .loading(track.title)
            workTask = Task { [weak self] in
                do {
                    let outcome = try await service.findLyrics(track: track)
                    try Task.checkCancellation()
                    if let self, self.key == key, generation == requestGeneration {
                        remember(
                            outcome: outcome,
                            key: key
                        )
                        apply(outcome)
                    }
                } catch {
                    if Task.isCancelled { return }
                    if let self, self.key == key, generation == requestGeneration {
                        state = .failed(error.localizedDescription)
                    }
                }
            }
        }
    }

    private func remember(
        outcome: LyricsSearchOutcome,
        key: LyricsTrackKey
    ) {
        cacheOrder.removeAll { $0 == key }
        cacheOrder.append(key)
        cache[key] = outcome
        if cacheOrder.count > 40 {
            let oldest = cacheOrder.removeFirst()
            cache.removeValue(forKey: oldest)
        }
    }

    private func apply(_ outcome: LyricsSearchOutcome) {
        candidates = [:]
        switch outcome {
        case .match(let selection):
            let matchText = "\(selection.result.trackName) — \(selection.result.artistName)"
            switch selection.content {
            case .synchronized(_, let lines):
                var displayLines: [TimedLyricDisplay] = []
                for line in lines {
                    displayLines.append(TimedLyricDisplay(line: line))
                }
                state = .content(LyricsContentDisplay(
                    resultID: selection.result.id,
                    matchText: matchText,
                    formatText: "Timed lyrics · static display; following comes next",
                    body: .timed(displayLines)
                ))
            case .plain(let text, _):
                state = .content(LyricsContentDisplay(
                    resultID: selection.result.id,
                    matchText: matchText,
                    formatText: "Plain lyrics · no timing available",
                    body: .plain(text)
                ))
            case .instrumental:
                state = .instrumental(matchText)
            case .unavailable:
                state = .unavailable
            }
        case .candidates(let rankedCandidates):
            var displays: [LyricsCandidateDisplay] = []
            for candidate in rankedCandidates {
                if candidates[candidate.result.id] == nil {
                    candidates[candidate.result.id] = candidate.result
                    displays.append(LyricsCandidateDisplay(candidate: candidate))
                }
            }
            state = displays.isEmpty ? .unavailable : .candidates(displays)
        case .notFound:
            state = .unavailable
        }
    }
}
