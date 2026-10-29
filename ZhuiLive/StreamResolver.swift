import Foundation
import UIKit
import CryptoKit

/// iOS 线路解析：直链直用（小红书 _orig 原画重写）；
/// 分享短链在 iOS 上不做 WebView 优选（Apple 对后台注入限制），直接走云端 stream/resolve。
enum StreamResolver {
    static func resolve(_ input: String,
                        done: @escaping (String, [String: String]) -> Void,
                        onFailure: @escaping (String) -> Void) {
        guard let url = input.firstMatch(of: /https?:\/\/\S+/)?.0 else {
            return onFailure("未找到链接")
        }
        let lower = url.lowercased()
        let isXhs = lower.contains("xhslink") || lower.contains("xiaohongshu") || lower.contains("xhscdn")

        if lower.contains(".flv") || lower.contains(".m3u8") {
            var finalUrl = isXhs ? rewriteXhsOrig(url) : url
            if lower.contains(".m3u8") { return onFailure("HLS 线路不支持") }
            var headers = ["User-Agent": isXhs ? Self.uaMobile : Self.uaDesktop]
            if isXhs { headers["Referer"] = "https://www.xiaohongshu.com/" }
            _ = finalUrl; finalUrl = isXhs ? rewriteXhsOrig(url) : url
            done(finalUrl, headers)
            return
        }

        // 分享短链 → 云端解析（后端与安卓共用）
        let deviceId = Self.deviceId()
        PlayerController.cloudResolve(deviceId: deviceId, url: url, done: done, fail: onFailure)
    }

    static let uaDesktop = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36"
    static let uaMobile = "Mozilla/5.0 (Linux; Android 13; PHB110) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Mobile Safari/537.36"

    static func rewriteXhsOrig(_ url: String) -> String {
        if let m = url.firstMatch(of: /\/live\/(\d+)(?:_[^\/?#]+)?\.flv/) {
            return "https://live-source-play.xhscdn.com/live/\(m.1)_orig.flv"
        }
        return url
    }

    static func deviceId() -> String {
        // 与安卓算法同构：ANDROID- + SHA-256(设备标识) 前 8 字节大写
        let raw = UIDevice.current.identifierForVendor?.uuidString ?? "unknown-ios"
        let digest = SHA256.hash(data: Data(raw.utf8))
        let hex = digest.prefix(8).map { String(format: "%02X", $0) }.joined()
        return "IOS-\(hex)"
    }
}
