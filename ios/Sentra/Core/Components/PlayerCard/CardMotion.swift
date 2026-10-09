import CoreMotion
import SwiftUI

enum CardMotionMode { case device, preview, disabled }

@MainActor
private final class CardMotionSource {
    static let shared = CardMotionSource()
    private let manager = CMMotionManager()
    private var owners: Set<UUID> = []

    private init() {}

    func acquire(_ owner: UUID) {
        guard manager.isDeviceMotionAvailable,
              let purpose = Bundle.main.object(forInfoDictionaryKey: "NSMotionUsageDescription") as? String,
              !purpose.isEmpty else { return }
        owners.insert(owner)
        if !manager.isDeviceMotionActive {
            manager.deviceMotionUpdateInterval = 1.0 / 30
            manager.startDeviceMotionUpdates()
        }
    }

    func release(_ owner: UUID) {
        owners.remove(owner)
        if owners.isEmpty { manager.stopDeviceMotionUpdates() }
    }

    var pose: (horizontal: Double, vertical: Double, shine: Double) {
        guard let sample = manager.deviceMotion else { return (0, 0, 0.5) }
        let horizontal = min(max(sample.gravity.x * 8, -5), 5)
        let vertical = min(max(-sample.gravity.z * 8, -5), 5)
        return (horizontal, vertical, min(max(0.5 + horizontal / 12 + vertical / 20, 0), 1))
    }
}

@MainActor
struct CardMotionEffect: ViewModifier {
    let mode: CardMotionMode
    let style: CardTierStyle
    @State private var owner = UUID()
    @GestureState private var drag: CGSize = .zero
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private var animates: Bool { !reduceMotion && mode != .disabled && scenePhase == .active }
    private var usesSensor: Bool { animates && mode == .device }

    func body(content: Content) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !animates)) { timeline in
            let pose = usesSensor ? CardMotionSource.shared.pose : (horizontal: 0.0, vertical: 0.0, shine: 0.5)
            let progress = !animates ? 0.45 : (mode == .preview ?
                timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 9) / 9 : pose.shine)
            content
                .background {
                    CardMaterial(style: style)
                        .overlay {
                            CardShine(style: style, progress: progress)
                                .opacity(reduceMotion ? 0.06 : (style.appearance == .playerOfTheWeek ? 0.18 : 0.12))
                        }
                        .clipShape(SentraCardShape())
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                .shadow(color: .black.opacity(0.16), radius: 12, y: 6)
                .rotation3DEffect(.degrees(animates ? pose.horizontal + min(max(Double(drag.width) / 18, -5), 5) : 0),
                                  axis: (x: 0, y: 1, z: 0), perspective: 0.25)
                .rotation3DEffect(.degrees(animates ? pose.vertical - min(max(Double(drag.height) / 18, -5), 5) : 0),
                                  axis: (x: 1, y: 0, z: 0), perspective: 0.25)
                .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.82), value: drag == .zero)
        }
        .simultaneousGesture(DragGesture(minimumDistance: 8).updating($drag) { value, state, _ in
            if animates { state = value.translation }
        }, including: animates ? .all : .none)
        .onAppear {
            if usesSensor { CardMotionSource.shared.acquire(owner) }
        }
        .onChange(of: usesSensor) { _, enabled in
            if enabled { CardMotionSource.shared.acquire(owner) } else { CardMotionSource.shared.release(owner) }
        }
        .onDisappear { CardMotionSource.shared.release(owner) }
    }
}

private struct CardShine: View {
    let style: CardTierStyle
    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            LinearGradient(stops: [.init(color: .clear, location: 0),
                                   .init(color: style.highlight, location: 0.48),
                                   .init(color: .clear, location: 1)],
                           startPoint: .leading, endPoint: .trailing)
                .frame(width: geometry.size.width * 0.45, height: geometry.size.height * 2)
                .rotationEffect(.degrees(22))
                .offset(x: geometry.size.width * CGFloat(progress * 2 - 0.6), y: -geometry.size.height * 0.5)
                .blendMode(.screen)
        }
    }
}