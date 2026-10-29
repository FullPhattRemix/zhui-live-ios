import SwiftUI
import AVFoundation

// 追帧Live iOS · 云母主题 · 免登录
struct ContentView: View {
    @StateObject private var player = PlayerController()

    var body: some View {
        ZStack {
            // 云母底：柔和冷白渐变
            LinearGradient(colors: [Color(hex: 0xF4F6FB), Color(hex: 0xE7EBF5)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                header
                inputRow
                PlayerContainerView(player: player)
                    .aspectRatio(3 / 4.2, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
                    .onTapGesture { player.fullscreen = true }
                controlsRow
                modeAndCache
                notifyToggle
                statusLine
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            if player.fullscreen { FullscreenOverlay(player: player) }
        }
    }

    private var header: some View {
        HStack {
            Text("追帧Live").font(.system(size: 26, weight: .semibold))
            Spacer()
            Text(player.badgeText)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Capsule().fill(Color.secondary.opacity(0.12)))
        }
    }

    private var inputRow: some View {
        HStack(spacing: 10) {
            TextField("粘贴直播地址或分享文字", text: $player.input)
                .textFieldStyle(.plain)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color(hex: 0xF2F2F7, alpha: 0.9)))
            Button {
                player.quickPaste()
            } label: {
                Text("快速粘贴")
                    .font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .background(Capsule().fill(LinearGradient(colors: [Color(hex: 0xFFB340), Color(hex: 0xF57C00)],
                                                              startPoint: .topLeading, endPoint: .bottomTrailing)))
            }
        }
    }

    private var controlsRow: some View {
        HStack(spacing: 10) {
            Button { player.startPlay() } label: {
                Label("播放", systemImage: "play.fill")
                    .font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 16)
                        .fill(LinearGradient(colors: [Color(hex: 0x3B9BFF), Color(hex: 0x0A84FF)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing)))
            }
            Button { player.stop() } label: {
                Label("停止", systemImage: "stop.fill")
                    .font(.system(size: 14)).foregroundColor(.primary)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: 0xEBEBF0, alpha: 0.95)))
            }
            Toggle(isOn: $player.audioOnly) { Text("只听声音").font(.system(size: 13)) }
        }
        .tint(Color(hex: 0x0A84FF))
    }

    private var modeAndCache: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("追帧模式").font(.system(size: 12, weight: .semibold)).foregroundColor(.secondary)
                Picker("", selection: $player.modeIndex) {
                    ForEach(0..<PlayerController.modes.count, id: \.self) { Text(PlayerController.modes[$0]).tag($0) }
                }
                .pickerStyle(.menu)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(cardBg)

            VStack(alignment: .leading, spacing: 2) {
                Text("缓存").font(.system(size: 12, weight: .semibold)).foregroundColor(.secondary)
                Text(player.cacheText).font(.system(size: 17, weight: .semibold, design: .rounded))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(cardBg)
        }
    }

    private var notifyToggle: some View {
        Toggle(isOn: $player.notificationVolume) {
            Text("使用通知音量播放音频").font(.system(size: 13))
        }
        .tint(Color(hex: 0x0A84FF))
        .padding(10)
        .background(cardBg)
    }

    private var statusLine: some View {
        Text(player.status).font(.system(size: 12)).foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var cardBg: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(.ultraThinMaterial)                       // iOS 云母材质
            .overlay(RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color.white.opacity(0.35), lineWidth: 1))
    }
}

// 全屏覆盖层：画面铺满 + 底部速度胶囊（点按循环调档） + 右上缓存
struct FullscreenOverlay: View {
    @ObservedObject var player: PlayerController

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            PlayerContainerView(player: player)
                .ignoresSafeArea()
                .onTapGesture { player.fullscreen = false }

            VStack {
                Text(player.cacheText)
                    .font(.system(size: 12)).foregroundColor(.white)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Capsule().fill(Color.black.opacity(0.45)))
                    .padding(.trailing, 14).padding(.top, 8)
                Spacer()
                Text(player.badgeText)
                    .font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                    .padding(.horizontal, 18).padding(.vertical, 9)
                    .background(Capsule().fill(Color(hex: 0x1C1C1E, alpha: 0.6)))
                    .padding(.bottom, 34)
                    .onTapGesture { player.cycleMode() }
            }
        }
    }
}

extension Color {
    init(hex: Int, alpha: Double = 1) {
        self.init(.sRGB,
                  Double((hex >> 16) & 0xFF) / 255,
                  Double((hex >> 8) & 0xFF) / 255,
                  Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }
}
