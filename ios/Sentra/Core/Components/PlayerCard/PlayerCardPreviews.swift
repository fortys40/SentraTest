import SwiftUI
import UIKit

private enum CardSamplePhoto: String, CaseIterable, Identifiable {
    case closeUp = "CardPhotoCloseUp"
    case outdoor = "CardPhotoOutdoor"
    case busy = "CardPhotoBusy"
    case lowLight = "CardPhotoLowLight"

    var id: String { rawValue }
    var label: LocalizedStringResource {
        switch self {
        case .closeUp: return "card.sample.closeUp"
        case .outdoor: return "card.sample.outdoor"
        case .busy: return "card.sample.busy"
        case .lowLight: return "card.sample.lowLight"
        }
    }
}

@MainActor
private enum CardPreviewData {
    static let dataset = MockDataFactory.make()

    static func example(_ appearance: PlayerCardAppearance = .gold) -> PlayerCardExample {
        let source = dataset.cardExamples[2]
        let overall: Int
        switch appearance {
        case .bronze: overall = 63
        case .silver: overall = 71
        case .gold: overall = 82
        case .elite: overall = 90
        case .playerOfTheWeek: overall = 92
        case .provisional: overall = 64
        }
        let sourceStats = source.stats
        let stats = appearance == .provisional ? PlayerStats(
            userID: sourceStats.userID, groupID: sourceStats.groupID, appearances: 2,
            wins: 1, losses: 0, draws: 0, goals: 1, mvpCount: 0, winPercentage: 100, currentStreak: 2
        ) : sourceStats
        return PlayerCardExample(profile: source.profile, groupName: source.groupName, stats: stats,
                                 overall: overall, title: source.title,
                                 design: CardDesign(id: "sample.\(appearance.rawValue)", tier: CardTier(overall: overall)),
                                 badges: appearance == .provisional ? [] : dataset.badgeDefinitions)
    }

    static func photo(_ sample: CardSamplePhoto) async throws -> CardPhoto {
        guard let data = NSDataAsset(name: sample.rawValue)?.data else { throw PhotoCropService.Failure.invalidImage }
        return try await PhotoCropService().prepare(data: data)
    }

    static func label(_ appearance: PlayerCardAppearance) -> LocalizedStringResource {
        switch appearance {
        case .bronze: return CardTier.bronze.label
        case .silver: return CardTier.silver.label
        case .gold: return CardTier.gold.label
        case .elite: return CardTier.elite.label
        case .playerOfTheWeek: return "card.playerOfTheWeek"
        case .provisional: return "card.sample.provisional"
        }
    }
}

@MainActor
private struct CardTierPreviews: View {
    @State private var photo: CardPhoto?
    @State private var failed = false

    var body: some View {
        VStack {
            if failed { Text("card.sample.error").foregroundStyle(.red) }
            HStack(alignment: .top, spacing: 20) {
                ForEach(PlayerCardAppearance.allCases) { appearance in
                    VStack(spacing: 12) {
                        Text(CardPreviewData.label(appearance)).font(.headline)
                        PlayerCardView(example: CardPreviewData.example(appearance), photo: photo,
                                       isPlayerOfTheWeek: appearance == .playerOfTheWeek,
                                       reliability: Decimal(92) / 100, countryCode: "GR", motion: .preview)
                    }
                    .frame(width: PlayerCardSize.medium.width)
                }
            }
        }
        .padding(24)
        .background(SentraTheme.Colors.background)
        .task {
            do { photo = try await CardPreviewData.photo(.closeUp) } catch { failed = true }
        }
    }
}

@MainActor
private struct CardPhotoPreviews: View {
    @State private var photos: [CardSamplePhoto: CardPhoto] = [:]
    @State private var failed = false

    var body: some View {
        VStack {
            if failed { Text("card.sample.error").foregroundStyle(.red) }
            HStack(alignment: .top, spacing: 20) {
                ForEach(CardSamplePhoto.allCases) { sample in
                    VStack(spacing: 12) {
                        Text(sample.label).font(.headline)
                        PlayerCardView(example: CardPreviewData.example(), photo: photos[sample],
                                       reliability: Decimal(92) / 100, motion: .disabled)
                    }
                    .frame(width: PlayerCardSize.medium.width)
                }
                VStack(spacing: 12) {
                    Text("card.sample.noPhoto").font(.headline)
                    PlayerCardView(example: CardPreviewData.example(), motion: .disabled)
                }
                .frame(width: PlayerCardSize.medium.width)
            }
        }
        .padding(24)
        .background(SentraTheme.Colors.background)
        .task {
            do {
                for sample in CardSamplePhoto.allCases { photos[sample] = try await CardPreviewData.photo(sample) }
            } catch { failed = true }
        }
    }
}

@MainActor
private struct CardSizePreviews: View {
    @State private var photo: CardPhoto?
    @State private var failed = false

    var body: some View {
        VStack {
            if failed { Text("card.sample.error").foregroundStyle(.red) }
            HStack(alignment: .center, spacing: 20) {
                ForEach(PlayerCardSize.allCases) { size in
                    PlayerCardView(example: CardPreviewData.example(), photo: photo, size: size,
                                   reliability: Decimal(92) / 100, motion: .disabled)
                        .frame(width: size.width)
                }
            }
        }
        .padding(24)
        .background(SentraTheme.Colors.background)
        .task {
            do { photo = try await CardPreviewData.photo(.closeUp) } catch { failed = true }
        }
    }
}

struct StadiumCardBackdrop: View {
    var body: some View {
        LinearGradient(colors: [Color(red: 0.025, green: 0.06, blue: 0.065),
                                Color(red: 0.04, green: 0.15, blue: 0.105)],
                       startPoint: .top, endPoint: .bottom)
            .overlay {
                Canvas { context, size in
                    for index in 0..<12 {
                        let baseline = size.height * (0.69 + Double(index) * 0.025)
                        var terrace = Path()
                        terrace.move(to: CGPoint(x: 0, y: baseline))
                        terrace.addLine(to: CGPoint(x: size.width, y: baseline))
                        context.stroke(terrace, with: .color(.white.opacity(0.035)), lineWidth: 1)
                    }
                    for side in [0.08, 0.92] {
                        let horizontal = size.width * side
                        let top = size.height * 0.12
                        var beam = Path()
                        beam.move(to: CGPoint(x: horizontal - 14, y: top))
                        beam.addLine(to: CGPoint(x: horizontal + 14, y: top))
                        beam.addLine(to: CGPoint(x: size.width * 0.75, y: size.height * 0.9))
                        beam.addLine(to: CGPoint(x: size.width * 0.25, y: size.height * 0.9))
                        beam.closeSubpath()
                        context.fill(beam, with: .linearGradient(Gradient(colors: [.white.opacity(0.15), .clear]),
                                                               startPoint: CGPoint(x: horizontal, y: top),
                                                               endPoint: CGPoint(x: horizontal, y: size.height * 0.7)))
                        let lamp = CGRect(x: horizontal - 15, y: top - 3, width: 30, height: 6)
                        context.fill(Path(roundedRect: lamp, cornerRadius: 1), with: .color(.white.opacity(0.8)))
                    }
                    var pitch = Path()
                    pitch.move(to: CGPoint(x: size.width * 0.32, y: size.height * 0.8))
                    pitch.addLine(to: CGPoint(x: size.width * 0.68, y: size.height * 0.8))
                    pitch.addLine(to: CGPoint(x: size.width * 1.2, y: size.height * 1.08))
                    pitch.addLine(to: CGPoint(x: size.width * -0.2, y: size.height * 1.08))
                    pitch.closeSubpath()
                    context.stroke(pitch, with: .color(.white.opacity(0.18)), lineWidth: 1.5)
                }
            }
            .clipped()
            .accessibilityHidden(true)
    }
}

@MainActor
private struct CardStadiumPreview: View {
    @State private var photo: CardPhoto?
    @State private var failed = false

    var body: some View {
        ZStack {
            StadiumCardBackdrop()
            VStack {
                if failed { Text("card.sample.error").foregroundStyle(.white) }
                PlayerCardView(example: CardPreviewData.example(.playerOfTheWeek), photo: photo,
                               size: .large, isPlayerOfTheWeek: true, reliability: Decimal(92) / 100,
                               countryCode: "GR", motion: .preview)
                    .padding(.horizontal, 28)
            }
        }
        .frame(width: 400, height: 712)
        .task {
            do { photo = try await CardPreviewData.photo(.closeUp) } catch { failed = true }
        }
    }
}

@MainActor
private struct CardEditorPreview: View {
    @State private var photo: CardPhoto?
    @State private var showsEditor = false
    @State private var failed = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if failed { Text("card.sample.error").foregroundStyle(.red) }
                PlayerCardView(example: CardPreviewData.example(), photo: photo, motion: .disabled)
                Button { showsEditor = true } label: {
                    Label("card.photo.adjust", systemImage: "slider.horizontal.3").frame(minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(24)
        }
        .sheet(isPresented: $showsEditor) { PhotoAdjustView(example: CardPreviewData.example(), photo: $photo) }
        .task {
            do { photo = try await CardPreviewData.photo(.outdoor) } catch { failed = true }
        }
    }
}

#Preview("Six tiers - light", traits: .sizeThatFitsLayout) {
    CardTierPreviews().environment(\.locale, Locale(identifier: "el")).preferredColorScheme(.light)
}

#Preview("Six tiers - dark", traits: .sizeThatFitsLayout) {
    CardTierPreviews().environment(\.locale, Locale(identifier: "el")).preferredColorScheme(.dark)
}

#Preview("Four photos and initials - light", traits: .sizeThatFitsLayout) {
    CardPhotoPreviews().environment(\.locale, Locale(identifier: "el")).preferredColorScheme(.light)
}

#Preview("Four photos and initials - dark", traits: .sizeThatFitsLayout) {
    CardPhotoPreviews().environment(\.locale, Locale(identifier: "el")).preferredColorScheme(.dark)
}

#Preview("Small, medium, large - light", traits: .sizeThatFitsLayout) {
    CardSizePreviews().environment(\.locale, Locale(identifier: "el")).preferredColorScheme(.light)
}

#Preview("Small, medium, large - dark", traits: .sizeThatFitsLayout) {
    CardSizePreviews().environment(\.locale, Locale(identifier: "en")).preferredColorScheme(.dark)
}

#Preview("Stadium share scene", traits: .sizeThatFitsLayout) {
    CardStadiumPreview().environment(\.locale, Locale(identifier: "el"))
}

#Preview("Local crop editor") {
    CardEditorPreview().environment(\.locale, Locale(identifier: "el"))
}

#Preview("Accessibility and Reduce Motion") {
    ScrollView {
        PlayerCardView(example: CardPreviewData.example(.provisional), motion: .preview).padding(16)
    }
    .environment(\.locale, Locale(identifier: "el"))
    .environment(\.dynamicTypeSize, .accessibility3)
    .environment(\.accessibilityReduceMotion, true)
}