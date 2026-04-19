import AVFoundation

final class SilentAudioPlayer {
    static let shared = SilentAudioPlayer()
    private var player: AVAudioPlayer?
    private init() {}

    func configure() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
        } catch {
            print("SilentAudioPlayer: failed to set category — \(error)")
        }
    }

    func start() {
        guard player == nil else { return }
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            let url = try writeSilenceFile()
            let audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer.numberOfLoops = -1
            audioPlayer.volume = 0
            audioPlayer.play()
            player = audioPlayer
        } catch {
            print("SilentAudioPlayer: start failed — \(error)")
        }
    }

    func stop() {
        player?.stop()
        player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func writeSilenceFile() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("unscrolled_silence.caf")
        guard !FileManager.default.fileExists(atPath: url.path) else { return url }

        let sampleRate: Double = 44100
        let frameCount = AVAudioFrameCount(sampleRate)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)
        else { throw NSError(domain: "SilentAudioPlayer", code: 1) }

        buffer.frameLength = frameCount
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
        return url
    }
}
