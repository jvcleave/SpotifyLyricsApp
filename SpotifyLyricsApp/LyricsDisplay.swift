import Foundation
import LyricsKit

struct TimedLyricDisplay: Identifiable, Equatable, Sendable {
    let id: Int
    let timestamp: String
    let text: String

    init(line: TimedLyricLine) {
        id = line.id
        let seconds = Int(max(
            0,
            line.time
        ))
        timestamp = String(
            format: "%d:%02d",
            seconds / 60,
            seconds % 60
        )
        text = line.text
    }
}

enum LyricsBodyDisplay: Equatable, Sendable {
    case plain(String)
    case timed([TimedLyricDisplay])
}

struct LyricsContentDisplay: Equatable, Sendable {
    let resultID: Int
    let matchText: String
    let formatText: String
    let body: LyricsBodyDisplay
}

struct LyricsCandidateDisplay: Identifiable, Equatable, Sendable {
    let id: Int
    let title: String
    let detail: String
    let selectionLabel: String

    init(candidate: RankedLyricsCandidate) {
        let result = candidate.result
        id = result.id
        title = result.trackName
        var detail = result.artistName
        if let album = result.albumName, !album.isEmpty {
            detail += " · \(album)"
        }
        if let duration = result.duration, duration.isFinite, duration > 0, duration < 86_400 {
            let seconds = Int(duration)
            let durationText = String(
                format: "%d:%02d",
                seconds / 60,
                seconds % 60
            )
            detail += " · \(durationText)"
        }
        self.detail = detail
        selectionLabel = "Use lyrics for \(result.trackName), \(detail)"
    }
}

enum LyricsViewState: Equatable, Sendable {
    case waiting
    case loading(String)
    case candidates([LyricsCandidateDisplay])
    case content(LyricsContentDisplay)
    case instrumental(String)
    case unavailable
    case failed(String)
}
