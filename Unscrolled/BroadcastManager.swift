import ReplayKit
import UIKit

final class BroadcastManager: NSObject {
    static let shared = BroadcastManager()

    private var broadcastController: RPBroadcastController?
    private var startCompletion: ((Bool) -> Void)?

    private override init() {}

    func startBroadcast(completion: @escaping (Bool) -> Void) {
        startCompletion = completion
        RPBroadcastActivityViewController.load(
            withPreferredExtension: "com.kailash.unscrolled.broadcast"
        ) { [weak self] vc, error in
            guard let self else { return }
            guard let vc else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            vc.delegate = self
            vc.modalPresentationStyle = .formSheet
            DispatchQueue.main.async {
                self.topViewController()?.present(vc, animated: true)
            }
        }
    }

    func stopBroadcast(completion: @escaping () -> Void) {
        guard let controller = broadcastController else {
            completion()
            return
        }
        controller.finishBroadcast { _ in
            DispatchQueue.main.async { completion() }
        }
        broadcastController = nil
    }

    private func topViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController
    }
}

extension BroadcastManager: RPBroadcastActivityViewControllerDelegate {
    func broadcastActivityViewController(
        _ broadcastActivityViewController: RPBroadcastActivityViewController,
        didFinishWith broadcastController: RPBroadcastController?,
        error: Error?
    ) {
        broadcastActivityViewController.dismiss(animated: true)
        guard error == nil, let broadcastController else {
            startCompletion?(false)
            return
        }
        self.broadcastController = broadcastController
        broadcastController.startBroadcast { [weak self] error in
            DispatchQueue.main.async {
                self?.startCompletion?(error == nil)
            }
        }
    }

    func broadcastActivityViewControllerDidCancel(
        _ broadcastActivityViewController: RPBroadcastActivityViewController
    ) {
        broadcastActivityViewController.dismiss(animated: true)
        startCompletion?(false)
    }
}
