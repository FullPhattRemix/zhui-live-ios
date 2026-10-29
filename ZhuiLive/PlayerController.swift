import Foundation
import AVFoundation
import UIKit
import CryptoKit
import MobileVLCKit

/// iOS 播放控制：MobileVLCKit 播放 HTTP-FLV + 智能追帧 + 云端兜底
final class PlayerController: NSObject, ObservableObject, VLCMediaPlayerDelegate {
    static let modes = ["智能追帧", "1.00x", "1.05x", "1.10x", "1.25x", "1.50x", "2.00x"]
    static let modeSpeeds: [Float] = [-1.1, 1.0, 1.05, 1.1, 1.25, 1.5, 2.0]
    static let reportToken = "rfp_7d92b14e6f8340aca718b445c972e051"
    static let apiBase = "https://soctank.cn/player-report/api"

    @Published var input = ""
    @Published var status = "就绪"
    @Published var badgeText = "待机"
    @Published var cacheText = "0.00s"
    @Published var audioOnly = false { didSet { applyAudioOnly() } }
    @Published var notificationVolume = true { didSet { applyAudioSession() } }
    @Published var fullscreen = false
    @Published var modeIndex = 0 { didSet { applyMode() } }

    var mediaPlayer: VLCMediaPlayer?
    private var chase: ChaseController?
    private var tickTimer: Timer?

    // MARK: 播放
    func startPlay() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { status = "请输入直播地址"; return }
        status = "解析中…"
        StreamResolver.resolve(text) { [weak self] url, headers in
            DispatchQueue.main.async {
                self?.status = "已选线路，开始播放"
                self?.play(url: url, headers: headers)
            }
        } onFailure: { [weak self] msg in
            DispatchQueue.main.async { self?.status = "解析失败: \(msg)，可尝试云端兜底" }
        }
    }

    private func play(url: String, headers: [String: String]) {
        let mp = mediaPlayer ?? VLCMediaPlayer()
        mediaPlayer = mp
        mp.delegate = self
        mp.drawable = nil // 音频/后台亦可；前台画面由 PlayerContainerView 接管
        let media = VLCMedia(url: URL(string: url)!)
        var opts: [String: Any] = ["network-caching": 300]   // 低延迟，对齐安卓 cache-secs≈0.8
        for (k, v) in headers {
            if k.caseInsensitiveCompare("user-agent") == .orderedSame { opts["http-user-agent"] = v }
            else if k.caseInsensitiveCompare("referer") == .orderedSame { opts["http-referrer"] = v }
        }
        media.addOptions(opts)
        mp.media = media
        mp.play()
        applyAudioOnly()
        applyMode()
        startTick()
    }

    func stop() {
        mediaPlayer?.stop()
        chase?.stop()
        chase = nil
        playing = false
        badgeText = "待机"
        cacheText = "0.00s"
        status = "已停止"
    }

    private var playing = false

    private func applyAudioOnly() {
        guard let mp = mediaPlayer else { return }
        // VLC: videoTrack 索引 -1 = 关闭视频轨（只听声音）
        mp.currentVideoTrackIndex = audioOnly ? Int32(-1) : Int32(0)
    }

    private func applyAudioSession() {
        // iOS 无独立"通知音量"流：映射为 勿扰跟随(.ambient) / 常规播放(.playback)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(notificationVolume ? .ambient : .playback)
        try? session.setActive(true)
    }

    private func applyMode() {
        guard let mp = mediaPlayer, playing else { return }
        let speed = Self.modeSpeeds[modeIndex]
        if speed < 0 {
            let c = ChaseController { [weak self] in (self?.currentCache() ?? -1) }
            c.rateUpdate = { [weak mp] v in mp?.rate = v }
            c.onPhase = { [weak self] (phase: String, rate: Float) in
                self?.badgeText = "\(phase) \(String(format: "%.2f", rate))x"
            }
            chase = c
            c.start()
        } else {
            chase?.stop(); chase = nil
            mp.rate = speed
            badgeText = String(format: "固定 %.2fx", speed)
        }
    }

    func cycleMode() {
        modeIndex = (modeIndex + 1) % Self.modes.count
    }

    // MARK: 状态轮询
    private func startTick() {
        playing = true
        tickTimer?.invalidate()
        tickTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self, self.playing, let mp = self.mediaPlayer else { return }
            let cache = self.currentCache()
            self.cacheText = String(format: "%.2fs", max(0, cache))
            if self.modeIndex > 0 {
                self.badgeText = String(format: "固定 %.2fx", Self.modeSpeeds[self.modeIndex])
            } else if let c = self.chase {
                self.badgeText = "\(c.phase) \(String(format: "%.2f", c.rate))x"
            } else {
                self.badgeText = String(format: "%.2fx", mp.rate)
            }
        }
    }

    /// VLC 无 demuxer-cache 概念：用 (直播最新位置-当前播放位置) 近似。
    /// 直播流位置以 time 递增速率 vs 墙钟比较得到堆积量。
    private var lastTime: TimeInterval = 0
    private var lastWall: TimeInterval = 0
    private var estCache: Double = 0
    private func currentCache() -> Double {
        guard let mp = mediaPlayer else { return -1 }
        let t = Double(mp.time.value) / 1000.0   // VLCTime.value = 毫秒
        let now = Date().timeIntervalSince1970
        if lastWall > 0 {
            let advanced = t - lastTime
            let wall = now - lastWall
            estCache = max(0, min(3, estCache + (advanced - wall)))
        }
        lastTime = t; lastWall = now
        return estCache
    }

    // MARK: 快速粘贴（分享文本 → 纯链接）
    func quickPaste() {
        guard let text = UIPasteboard.general.string, !text.isEmpty else { status = "剪贴板为空"; return }
        if let url = text.firstMatch(of: /https?:\/\/\S+/)?.0 {
            input = String(url); status = "已提取链接"
        } else {
            input = text; status = "已粘贴"
        }
    }

    // MARK: 云端兜底（与安卓同接口）
    static func cloudResolve(deviceId: String, url: String,
                             done: @escaping (String, [String: String]) -> Void,
                             fail: @escaping (String) -> Void) {
        var req = URLRequest(url: URL(string: "\(apiBase)/stream/resolve")!)
        req.httpMethod = "POST"
        req.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        req.setValue(reportToken, forHTTPHeaderField: "X-Report-Token")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["device_id": deviceId, "url": url, "audio_only": false])
        URLSession.shared.dataTask(with: req) { data, _, _ in
            guard let data,
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  obj["ok"] as? Bool == true,
                  let cands = obj["candidates"] as? [[String: Any]],
                  let first = cands.first,
                  let u = first["url"] as? String else { return fail("no candidates") }
            var headers: [String: String] = [:]
            if let hs = first["headers"] as? [String: Any] {
                for (k, v) in hs { headers[k] = "\(v)" }
            }
            done(u, headers)
        }.resume()
    }
}
