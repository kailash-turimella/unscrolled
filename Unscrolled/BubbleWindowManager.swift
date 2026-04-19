import UIKit
import SwiftUI
import AVKit

// MARK: - BubbleWindowManager

final class BubbleWindowManager: NSObject {
    static let shared = BubbleWindowManager()

    private var inAppWindow: UIWindow?
    private var pipController: AVPictureInPictureController?
    private var isSetUp = false
    private var isVisible = false

    private override init() {}

    func setup(with scene: UIWindowScene) {
        guard !isSetUp else { return }
        isSetUp = true
        setupInAppWindow(scene: scene)
        setupPiP(scene: scene)
    }

    // Small UIWindow bubble — visible while Unscrolled is frontmost
    private func setupInAppWindow(scene: UIWindowScene) {
        let window = UIWindow(windowScene: scene)
        let screen = scene.screen
        window.frame = CGRect(
            x: screen.bounds.width - 72,
            y: screen.bounds.height / 2,
            width: 56, height: 56
        )
        window.windowLevel = .alert + 1
        window.backgroundColor = .clear
        window.isOpaque = false
        window.rootViewController = BubbleViewController()
        window.isHidden = true
        self.inAppWindow = window
    }

    // PiP bubble — floats over other apps. Background is fully transparent so
    // only the circle is visible. iOS enforces a ~100pt minimum window size,
    // which is as small as the system allows.
    private func setupPiP(scene: UIWindowScene) {
        guard AVPictureInPictureController.isPictureInPictureSupported(),
              let sourceView = scene.windows.first(where: \.isKeyWindow)?.rootViewController?.view
        else { return }

        let pipVC = AVPictureInPictureVideoCallViewController()
        pipVC.preferredContentSize = CGSize(width: 100, height: 100)
        pipVC.view.backgroundColor = .clear

        let hostingVC = UIHostingController(rootView: BubbleCircleView())
        hostingVC.view.backgroundColor = .clear
        pipVC.addChild(hostingVC)
        pipVC.view.addSubview(hostingVC.view)
        hostingVC.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingVC.view.centerXAnchor.constraint(equalTo: pipVC.view.centerXAnchor),
            hostingVC.view.centerYAnchor.constraint(equalTo: pipVC.view.centerYAnchor),
            hostingVC.view.widthAnchor.constraint(equalToConstant: 56),
            hostingVC.view.heightAnchor.constraint(equalToConstant: 56),
        ])
        hostingVC.didMove(toParent: pipVC)

        let source = AVPictureInPictureController.ContentSource(
            activeVideoCallSourceView: sourceView,
            contentViewController: pipVC
        )
        let pip = AVPictureInPictureController(contentSource: source)
        pip.delegate = self
        pip.canStartPictureInPictureAutomaticallyFromInline = true
        self.pipController = pip
    }

    func show() {
        guard !isVisible else { return }
        isVisible = true
        SilentAudioPlayer.shared.start()
        inAppWindow?.isHidden = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.pipController?.startPictureInPicture()
        }
    }

    func hide() {
        guard isVisible else { return }
        isVisible = false
        inAppWindow?.isHidden = true
        pipController?.stopPictureInPicture()
        SilentAudioPlayer.shared.stop()
    }
}

extension BubbleWindowManager: AVPictureInPictureControllerDelegate {
    func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        failedToStartPictureInPictureWithError error: Error
    ) {}

    func pictureInPictureControllerWillStopPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {
        guard SessionManager.shared.isSessionActive else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            pictureInPictureController.startPictureInPicture()
        }
    }
}

// MARK: - BubbleViewController

final class BubbleViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        let hostingVC = UIHostingController(rootView: BubbleCircleView())
        hostingVC.view.backgroundColor = .clear
        addChild(hostingVC)
        view.addSubview(hostingVC.view)
        hostingVC.view.frame = view.bounds
        hostingVC.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hostingVC.didMove(toParent: self)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        view.addGestureRecognizer(pan)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        tap.require(toFail: pan)
        view.addGestureRecognizer(tap)
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let window = view.window else { return }
        let translation = gesture.translation(in: view)
        var origin = window.frame.origin
        origin.x += translation.x
        origin.y += translation.y

        let screen = UIScreen.main.bounds
        origin.x = max(8, min(origin.x, screen.width - window.frame.width - 8))
        origin.y = max(50, min(origin.y, screen.height - window.frame.height - 40))

        window.frame.origin = origin
        gesture.setTranslation(.zero, in: view)
    }

    @objc private func handleTap() {
        guard let url = URL(string: "unscrolled://") else { return }
        UIApplication.shared.open(url)
    }
}
