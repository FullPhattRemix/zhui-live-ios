import SwiftUI
import MobileVLCKit

/// VLC 画面承载（VLCMediaPlayerLibrary 需要 UIView drawable）
struct PlayerContainerView: UIViewRepresentable {
    @ObservedObject var player: PlayerController

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        DispatchQueue.main.async {
            let mp = player.mediaPlayer ?? VLCMediaPlayer()
            player.mediaPlayer = mp
            mp.drawable = view
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
