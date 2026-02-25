//
//  SplashVideoView.swift
//  Pact
//
//  Created by Yaw Snr Owusu on 2/25/26.
//

import SwiftUI
import AVFoundation

struct SplashVideoView: View {
    var onFinished: () -> Void

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            PlayerView(onFinished: onFinished)
                .ignoresSafeArea()
        }
    }
}

private struct PlayerView: UIViewRepresentable {
    var onFinished: () -> Void

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.onFinished = onFinished
        view.startPlayback()
        return view
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {}

    static func dismantleUIView(_ uiView: PlayerUIView, coordinator: ()) {
        uiView.cleanup()
    }
}

private class PlayerUIView: UIView {
    var onFinished: (() -> Void)?

    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var observer: NSObjectProtocol?

    override class var layerClass: AnyClass { AVPlayerLayer.self }

    private var avPlayerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    func startPlayback() {
        backgroundColor = .black
        avPlayerLayer.videoGravity = .resizeAspectFill

        guard let url = Bundle.main.url(forResource: "startup_animation", withExtension: "mp4") else {
            onFinished?()
            return
        }

        let player = AVPlayer(url: url)
        avPlayerLayer.player = player
        self.player = player

        observer = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            self?.onFinished?()
        }

        player.play()
    }

    func cleanup() {
        player?.pause()
        if let observer { NotificationCenter.default.removeObserver(observer) }
        player = nil
        observer = nil
    }
}
