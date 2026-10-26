//
//  PositiveFingerApp.swift
//  PositiveFinger
//
//  Created by 市来武 on 2026/10/20.
//  Created by SWORDFIVE on 2026/10/20.

import SwiftUI
import AVFoundation

@main
struct PositiveFingerApp: App {

    var body: some Scene {

        WindowGroup {
            PositiveFingerLaunchView()
        }
    }
}

/// Play once per app launch, independently of login and network availability.
private struct PositiveFingerLaunchView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var startup = StartupPlayback()

    var body: some View {
        ZStack {
            PositiveFingerHomeView()
                .allowsHitTesting(startup.finished)
                .accessibilityHidden(!startup.finished)

            if !startup.finished {
                GeometryReader { geometry in
                    ZStack {
                        Color.white
                        Image(uiImage: UIImage(named: reduceMotion ? "StartupStill" : "StartupPoster") ?? UIImage())
                            .resizable()
                            .scaledToFill()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                        if !reduceMotion {
                            StartupPlayerView(player: startup.player)
                        }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                }
                .ignoresSafeArea()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("PositiveFinger 起動中")
            }
        }
        .statusBarHidden(!startup.finished)
        .task { await startup.start(reduceMotion: reduceMotion) }
        .onChange(of: scenePhase) { phase in
            guard !startup.finished else { return }
            if phase == .active { startup.player.play() }
            else { startup.player.pause() }
        }
    }
}

@MainActor
private final class StartupPlayback: ObservableObject {
    @Published private(set) var finished = false
    let player = AVPlayer()
    private var started = false
    private var observers: [NSObjectProtocol] = []
    private var statusObservation: NSKeyValueObservation?

    func start(reduceMotion: Bool) async {
        guard !started else { return }
        started = true
        if reduceMotion {
            try? await Task.sleep(nanoseconds: 350_000_000)
            finish()
            return
        }
        guard let url = Bundle.main.url(forResource: "Startup", withExtension: "mp4") else {
            finish()
            return
        }
        let item = AVPlayerItem(url: url)
        for name in [Notification.Name.AVPlayerItemDidPlayToEndTime,
                     Notification.Name.AVPlayerItemFailedToPlayToEndTime] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: item, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in self?.finish() }
            })
        }
        statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            if item.status == .failed {
                Task { @MainActor [weak self] in self?.finish() }
            }
        }
        // The video's embedded sound follows the device's normal silent-mode behavior.
        player.replaceCurrentItem(with: item)
        player.play()
        // A damaged or stalled local video must never block access to the app.
        try? await Task.sleep(nanoseconds: 4_000_000_000)
        finish()
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        player.pause()
        player.replaceCurrentItem(with: nil)
        statusObservation = nil
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }
}

private struct StartupPlayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> StartupPlayerSurface {
        let view = StartupPlayerSurface()
        view.playerLayer.videoGravity = .resizeAspectFill
        view.playerLayer.player = player
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: StartupPlayerSurface, context: Context) {}

    static func dismantleUIView(_ uiView: StartupPlayerSurface, coordinator: ()) {
        uiView.playerLayer.player = nil
    }
}

private final class StartupPlayerSurface: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}
