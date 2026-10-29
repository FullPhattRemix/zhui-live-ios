import Foundation

/// 智能追帧状态机（Swift 移植，与安卓 ChaseController 同参数）：
/// warmup → ramp_up → probe → ramp_burst → burst → ramp_down → cruise/steady
final class ChaseController {
    var rateUpdate: ((Float) -> Void)?
    var onPhase: ((String, Float) -> Void)?
    private let cacheProvider: () -> Double

    private(set) var phase = "warmup"
    private(set) var rate: Float = 1.01
    private var timer: Timer?
    private var phaseSince: TimeInterval = 0
    private var entryRate: Float = 1.1
    private var healthySince: TimeInterval = 0

    init(cacheProvider: @escaping () -> Double) { self.cacheProvider = cacheProvider }

    func start() {
        phase = "warmup"; rate = 1.01
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in self?.tick() }
    }

    func stop() { timer?.invalidate(); timer = nil }

    private func enter(_ p: String, _ speed: Float) {
        phase = p; phaseSince = Date().timeIntervalSince1970; entryRate = speed
    }

    private func tick() {
        let now = Date().timeIntervalSince1970
        let cache = cacheProvider()
        let healthy = cache >= 0.3
        let underrun = cache <= 0.1

        switch phase {
        case "paused", "buffering":
            rate = 1.01
        case "warmup":
            rate = 1.01
            if healthy { healthySince = healthySince == 0 ? now : healthySince }
            else { healthySince = 0 }
            if healthySince > 0 && now - healthySince >= 3 { enter("ramp_up", rate); healthySince = 0 }
        case "ramp_up":
            let t = Float(min(1, max(0, (now - phaseSince) / 3)))
            rate = 1.01 + 0.09 * t
            if !healthy { enter("ramp_down", rate) }
            else if t >= 1 { enter("probe", 1.1) }
        case "probe":
            if !healthy { enter("ramp_down", 1.1) }
            else if cache >= 0.465 { enter("ramp_burst", 1.1) }
            else if now - phaseSince >= 4 { enter("cruise", 1.01) }
        case "ramp_burst":
            let t = Float(min(1, max(0, (now - phaseSince) / 2)))
            rate = 1.1 + 0.9 * t
            if underrun { enter("ramp_down", 1.1) }
            else if t >= 1 { enter("burst", 2.0) }
        case "burst", "fast":
            rate = phase == "burst" ? 2.0 : 1.5
            if !underrun && now - phaseSince >= (phase == "fast" ? 8 : 3) { enter("ramp_down", 1.1) }
        case "ramp_down":
            let t = Float(min(1, max(0, (now - phaseSince) / 3)))
            rate = entryRate + (1.01 - entryRate) * t
            if t >= 1 { enter("cruise", 1.01) }
        default: // cruise / steady
            if healthy && cache > 0.3 {
                // 稳态按缓存直接计算（与原版一致）
                let target = Float(min(2.0, max(1.01, 1.0 + (cache - 0.03) / 1.5)))
                rate = (target * 100).rounded() / 100
                phase = "steady"
            } else {
                rate = 1.01
            }
        }
        rate = (max(1.01, rate) * 100).rounded() / 100
        rateUpdate?(rate)
        onPhase?(phase, rate)
    }
}
