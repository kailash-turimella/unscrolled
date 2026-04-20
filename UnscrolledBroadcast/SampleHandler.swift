import ReplayKit
import UIKit
import CoreImage

class SampleHandler: RPBroadcastSampleHandler {

    private lazy var defaults: UserDefaults = {
        UserDefaults(suiteName: "group.com.kailash.unscrolled") ?? .standard
    }()

    private lazy var appGroupURL: URL? = {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.kailash.unscrolled")
    }()

    private var lastFrameWriteTime: Date = .distantPast
    private let ciContext = CIContext()

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        defaults.set(Date(), forKey: "broadcastStarted")
        defaults.set(Date(), forKey: "broadcastHeartbeat")
    }

    override func broadcastPaused() {}

    override func broadcastResumed() {}

    override func broadcastFinished() {
        defaults.set(Date(), forKey: "broadcastFinished")
        defaults.removeObject(forKey: "broadcastHeartbeat")
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        if defaults.bool(forKey: "stopBroadcast") {
            defaults.removeObject(forKey: "stopBroadcast")
            finishBroadcastWithError(NSError(domain: "Unscrolled", code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Session ended"]))
            return
        }

        switch sampleBufferType {
        case .video:
            defaults.set(Date(), forKey: "broadcastHeartbeat")

            let now = Date()
            if now.timeIntervalSince(lastFrameWriteTime) >= 1.0 {
                lastFrameWriteTime = now
                writeLatestFrame(sampleBuffer)
            }

        case .audioApp:
            break  // Future: SFSpeechRecognizer + SoundAnalysis

        case .audioMic:
            break

        @unknown default:
            break
        }
    }

    private func writeLatestFrame(_ sampleBuffer: CMSampleBuffer) {
        guard let appGroupURL,
              let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        else { return }

        let ciImage = CIImage(cvImageBuffer: imageBuffer)
        let originalWidth = CVPixelBufferGetWidth(imageBuffer)
        let originalHeight = CVPixelBufferGetHeight(imageBuffer)

        let scale: CGFloat = 0.25
        let scaledSize = CGSize(
            width: CGFloat(originalWidth) * scale,
            height: CGFloat(originalHeight) * scale
        )

        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return }

        let renderer = UIGraphicsImageRenderer(size: scaledSize)
        let scaled = renderer.image { _ in
            UIImage(cgImage: cgImage).draw(in: CGRect(origin: .zero, size: scaledSize))
        }

        guard let jpegData = scaled.jpegData(compressionQuality: 0.3) else { return }

        let frameURL = appGroupURL.appendingPathComponent("latest_frame.jpg")
        try? jpegData.write(to: frameURL, options: .atomic)
    }
}
