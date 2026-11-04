import AVFoundation

final class AudioPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var playingURL: URL?
    private var player: AVAudioPlayer?

    func toggle(_ url: URL) {
        if playingURL == url { stop(); return }
        stop()
        do {
            let session = AVAudioSession.sharedInstance()
            if session.category != .playAndRecord {
                try session.setCategory(.playback)
            }
            try session.setActive(true)
            let p = try AVAudioPlayer(contentsOf: url)
            p.delegate = self
            p.play()
            player = p
            playingURL = url
        } catch {
            playingURL = nil
        }
    }

    func stop() {
        player?.stop()
        player = nil
        playingURL = nil
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { self.playingURL = nil }
    }
}
