import SwiftUI

/// Shared timebase so the controller can ask "how long until this breath ends?"
final class BreathClock {
    let period: TimeInterval = 11.0           // 5.5 s in, 5.5 s out
    private(set) var start = Date()

    func restart() { start = Date() }

    /// Normalised phase 0..<1 for a given moment. First half = inhale.
    func phase(at date: Date) -> Double {
        let t = date.timeIntervalSince(start)
        return (t.truncatingRemainder(dividingBy: period)) / period
    }

    func timeUntilCycleEnd(from date: Date = Date()) -> TimeInterval {
        let elapsed = date.timeIntervalSince(start).truncatingRemainder(dividingBy: period)
        return period - elapsed
    }
}

struct BreathingView: View {
    let clock: BreathClock

    private let petals = 6
    private let minScale = 0.32

    var body: some View {
        TimelineView(.animation) { ctx in
            let phase = clock.phase(at: ctx.date)
            let inhaling = phase < 0.5
            // 0 → 1 over the inhale, 1 → 0 over the exhale, eased.
            let raw = inhaling ? phase * 2 : (1 - phase) * 2
            let eased = 0.5 - 0.5 * cos(raw * .pi)
            let scale = minScale + (1 - minScale) * eased

            ZStack {
                Color.black.opacity(0.88)

                ZStack {
                    ForEach(0..<petals, id: \.self) { i in
                        Circle()
                            .fill(
                                LinearGradient(colors: [Color(hue: 0.52, saturation: 0.7, brightness: 0.95),
                                                        Color(hue: 0.62, saturation: 0.8, brightness: 0.75)],
                                               startPoint: .top, endPoint: .bottom)
                            )
                            .frame(width: 220, height: 220)
                            .offset(y: -95)
                            .rotationEffect(.degrees(Double(i) * 360 / Double(petals)))
                            .opacity(0.55)
                            .blendMode(.plusLighter)
                    }
                }
                .scaleEffect(scale)
                .rotationEffect(.degrees(phase * 60))      // slow drift, one sixth turn per breath
                .blur(radius: 2 + (1 - eased) * 6)

                VStack(spacing: 10) {
                    Text(inhaling ? "Breathe in" : "Breathe out")
                        .font(.system(size: 28, weight: .light, design: .rounded))
                        .contentTransition(.opacity)
                        .animation(.easeInOut(duration: 0.4), value: inhaling)
                    Text("Claude is working · Esc to dismiss")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.white)
                .offset(y: 300)
            }
        }
        .ignoresSafeArea()
    }
}
