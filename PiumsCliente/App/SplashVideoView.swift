import SwiftUI
import UIKit
import AVFoundation

struct SplashVideoView: UIViewRepresentable {
    var onFinished: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.backgroundColor = .black

        let url = Bundle.main.url(forResource: "PiumsSplash", withExtension: "mp4")
            ?? Bundle.main.url(forResource: "PiumsSplash", withExtension: "mp4", subdirectory: "Resources")

        guard let url else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { onFinished() }
            return view
        }

        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        try? AVAudioSession.sharedInstance().setActive(true)

        let asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: false])
        let item = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: item)
        player.automaticallyWaitsToMinimizeStalling = false

        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspect
        layer.backgroundColor = UIColor.black.cgColor

        view.horizontalOffset = 20
        view.setPlayerLayer(layer)
        context.coordinator.setup(player: player, onFinished: onFinished)

        player.playImmediately(atRate: 2.0)
        return view
    }

    func updateUIView(_ view: PlayerContainerView, context: Context) {}

    final class Coordinator: NSObject {
        private var player: AVPlayer?
        private var onFinished: (() -> Void)?
        private var endObserver: Any?
        private var timeoutTask: Task<Void, Never>?

        func setup(player: AVPlayer, onFinished: @escaping () -> Void) {
            self.player = player
            self.onFinished = onFinished

            endObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem,
                queue: .main
            ) { [weak self] _ in self?.finish() }

            // Timeout via Swift concurrency — funciona con SWIFT_DEFAULT_ACTOR_ISOLATION=MainActor
            timeoutTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(10))
                self?.finish()
            }
        }

        func finish() {
            guard let cb = onFinished else { return }
            onFinished = nil
            timeoutTask?.cancel()
            timeoutTask = nil
            cb()
        }

        deinit {
            timeoutTask?.cancel()
            if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        }
    }
}

final class PlayerContainerView: UIView {
    var horizontalOffset: CGFloat = 0
    private var playerLayer: AVPlayerLayer?

    func setPlayerLayer(_ layer: AVPlayerLayer) {
        playerLayer = layer
        self.layer.addSublayer(layer)
        layer.frame = bounds
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.disableActions()
        playerLayer?.frame = bounds
        playerLayer?.transform = CATransform3DMakeTranslation(horizontalOffset, 0, 0)
        CATransaction.commit()
    }
}
