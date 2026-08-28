import AppKit
import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    let viewModel: SpotifyLyricsViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "quote.bubble.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
                VStack(
                    alignment: .leading,
                    spacing: 3
                ) {
                    Text("Spotify Lyrics")
                        .font(.headline)
                    Text("Your current song, with lyrics from LRCLIB")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let notice = viewModel.modeNotice {
                        Text(notice)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                }
                Spacer()
            }
            .padding(20)
            .background(.bar)
            Divider()
            if viewModel.showsDisconnect {
                HSplitView {
                    PlaybackPanel(
                        state: viewModel.state,
                        monitoring: viewModel.monitoring,
                        refreshAction: viewModel.refreshPlayback,
                        toggleAction: viewModel.toggleMonitoring
                    )
                    .frame(
                        minWidth: 280,
                        idealWidth: 330,
                        maxWidth: 400
                    )
                    LyricsPanel(viewModel: viewModel.lyrics)
                        .frame(
                            minWidth: 380,
                            maxWidth: .infinity,
                            maxHeight: .infinity
                        )
                }
            } else {
                ConnectionPanel(
                    state: viewModel.state,
                    connectAction: viewModel.connectSpotify,
                    cancelAction: viewModel.disconnectSpotify
                )
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity
                )
            }
        }
        .frame(
            minWidth: 740,
            minHeight: 540
        )
        .background(Color(nsColor: .windowBackgroundColor))
        .task { viewModel.start() }
        .onDisappear { viewModel.stop() }
        .onChange(
            of: scenePhase,
            initial: true
        ) { _, phase in
            viewModel.applicationActivityChanged(isActive: phase == .active)
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.willSleepNotification)) { _ in
            viewModel.systemSleepChanged(isAwake: false)
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)) { _ in
            viewModel.systemSleepChanged(isAwake: true)
        }
        .toolbar {
            if viewModel.showsDisconnect {
                Button(
                    "Disconnect",
                    action: viewModel.disconnectSpotify
                )
            }
        }
    }
}

private struct ConnectionPanel: View {
    let state: SpotifyLyricsViewState
    let connectAction: () -> Void
    let cancelAction: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            switch state {
            case .notConfigured(let message):
                StatusMessage(
                    symbol: "gear.badge.xmark",
                    title: "Spotify Setup Required",
                    message: message
                )
            case .disconnected:
                StatusMessage(
                    symbol: "music.note.house",
                    title: "Connect Your Music",
                    message: "Sign in through Spotify, then play a song there. Lyrics will appear here automatically."
                )
                Button(
                    "Connect Spotify",
                    action: connectAction
                )
                .buttonStyle(.borderedProminent)
            case .connecting:
                ProgressView("Complete sign-in in your browser")
                Button(
                    "Cancel",
                    action: cancelAction
                )
            case .restoring:
                ProgressView("Restoring Spotify connection…")
            case .disconnecting:
                ProgressView("Disconnecting…")
            case .failed(let message, _):
                StatusMessage(
                    symbol: "exclamationmark.triangle",
                    title: "Spotify Needs Attention",
                    message: message
                )
                Button(
                    "Connect Spotify",
                    action: connectAction
                )
            default:
                ProgressView("Checking Spotify…")
            }
        }
        .controlSize(.large)
        .padding(32)
    }
}

private struct PlaybackPanel: View {
    let state: SpotifyLyricsViewState
    let monitoring: SpotifyMonitoringDisplay
    let refreshAction: () -> Void
    let toggleAction: () -> Void

    var body: some View {
        ScrollView {
            VStack(
                alignment: .leading,
                spacing: 24
            ) {
                Label(
                    "NOW PLAYING",
                    systemImage: "waveform"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                switch state {
                case .track(let track):
                    TrackView(track: track)
                case .nothingPlaying:
                    StatusMessage(
                        symbol: "pause.circle",
                        title: "Nothing Playing",
                        message: "Play a song in Spotify. Resume monitoring or refresh to load it here."
                    )
                case .unsupported(let title, let message):
                    StatusMessage(
                        symbol: "music.note.list",
                        title: title,
                        message: message
                    )
                case .failed(let message, _):
                    StatusMessage(
                        symbol: "exclamationmark.triangle",
                        title: "Playback Unavailable",
                        message: message
                    )
                default:
                    ProgressView("Waiting for Spotify…")
                }
                Divider()
                VStack(
                    alignment: .leading,
                    spacing: 10
                ) {
                    Text(monitoring.statusText)
                        .font(.subheadline)
                    Text(monitoring.lastUpdatedText)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    if let warning = monitoring.warningText {
                        Label(
                            warning,
                            systemImage: "exclamationmark.triangle"
                        )
                        .font(.caption)
                        .foregroundStyle(.orange)
                    }
                    Button(
                        monitoring.toggleTitle,
                        action: toggleAction
                    )
                    Button(
                        "Refresh Spotify",
                        systemImage: "arrow.clockwise",
                        action: refreshAction
                    )
                    .disabled(!monitoring.canRefresh)
                    if monitoring.isRefreshing { ProgressView().controlSize(.small) }
                }
            }
            .padding(24)
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
        }
    }
}

private struct TrackView: View {
    let track: SpotifyTrackDisplay

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 14
        ) {
            Text(track.title)
                .font(.largeTitle.weight(.bold))
                .textSelection(.enabled)
            Text(track.artistText)
                .font(.title3)
                .foregroundStyle(.secondary)
            if let album = track.albumText {
                Text(album)
                    .foregroundStyle(.secondary)
            }
            Text(track.playbackStatusText)
                .font(.caption)
            ProgressView(value: track.progressFraction)
                .tint(.green)
                .accessibilityLabel("Estimated song progress")
                .accessibilityValue(track.progressText)
            Text(track.progressText)
                .font(.caption.monospacedDigit())
            Text(track.positionNote)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let url = track.spotifyURL {
                Link(
                    "Open in Spotify",
                    destination: url
                )
            }
        }
    }
}

private struct LyricsPanel: View {
    let viewModel: LyricsViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Lyrics")
                    .font(.title2.weight(.semibold))
                Spacer()
                if viewModel.canRetry {
                    Button(
                        "Reload Lyrics",
                        systemImage: "arrow.clockwise",
                        action: viewModel.retryLyrics
                    )
                }
            }
            .padding(24)
            Divider()
            ScrollView {
                VStack(
                    alignment: .leading,
                    spacing: 20
                ) {
                    switch viewModel.state {
                    case .waiting:
                        StatusMessage(
                            symbol: "text.quote",
                            title: "Waiting for a Song",
                            message: "Lyrics lookup begins when Spotify reports a music track."
                        )
                    case .loading(let title):
                        ProgressView("Finding lyrics for \(title)…")
                    case .candidates(let candidates):
                        Text("Choose the matching recording")
                            .font(.headline)
                        Text("LyricsKit found several possible matches. Check the artist, album, and duration.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        LazyVStack(spacing: 12) {
                            ForEach(candidates) { candidate in
                                CandidateView(
                                    candidate: candidate,
                                    chooseAction: { viewModel.selectCandidate(id: candidate.id) }
                                )
                            }
                        }
                    case .content(let content):
                        LyricsContentView(content: content)
                    case .instrumental(let match):
                        StatusMessage(
                            symbol: "pianokeys",
                            title: "Instrumental",
                            message: "LRCLIB marks this recording as instrumental.\n\(match)"
                        )
                    case .unavailable:
                        StatusMessage(
                            symbol: "text.badge.xmark",
                            title: "No Lyrics Available",
                            message: "No usable lyrics were found for this recording. You can retry, or play another song."
                        )
                    case .failed(let message):
                        StatusMessage(
                            symbol: "wifi.exclamationmark",
                            title: "Lyrics Could Not Be Loaded",
                            message: message
                        )
                    }
                }
                .padding(28)
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
            }
            Divider()
            Link(
                "Lyrics source: LRCLIB",
                destination: URL(string: "https://lrclib.net")!
            )
            .font(.caption)
            .padding(12)
        }
    }
}

private struct LyricsContentView: View {
    let content: LyricsContentDisplay

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 22
        ) {
            VStack(
                alignment: .leading,
                spacing: 5
            ) {
                Text(content.matchText)
                    .font(.headline)
                Text(content.formatText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            switch content.body {
            case .plain(let text):
                Text(text)
                    .font(.title3)
                    .lineSpacing(8)
                    .textSelection(.enabled)
            case .timed(let lines):
                LazyVStack(
                    alignment: .leading,
                    spacing: 18
                ) {
                    ForEach(lines) { line in
                        HStack(
                            alignment: .firstTextBaseline,
                            spacing: 16
                        ) {
                            Text(line.timestamp)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.tertiary)
                                .frame(
                                    width: 42,
                                    alignment: .trailing
                                )
                            Text(line.text)
                                .font(.title3)
                                .textSelection(.enabled)
                        }
                    }
                }
                .id(content.resultID)
            }
        }
    }
}

private struct CandidateView: View {
    let candidate: LyricsCandidateDisplay
    let chooseAction: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            VStack(
                alignment: .leading,
                spacing: 5
            ) {
                Text(candidate.title)
                    .font(.headline)
                Text(candidate.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(
                "Use These Lyrics",
                action: chooseAction
            )
            .accessibilityLabel(candidate.selectionLabel)
        }
        .padding(14)
        .background(.quaternary.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct StatusMessage: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            Image(systemName: symbol)
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title2.weight(.semibold))
            Text(message)
                .foregroundStyle(.secondary)
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )
        }
        .frame(maxWidth: 460)
    }
}

#Preview("Setup Required") {
    ContentView(viewModel: SpotifyLyricsViewModel(configurationMessage: "Configure the app's Spotify Client ID to sign in."))
}
