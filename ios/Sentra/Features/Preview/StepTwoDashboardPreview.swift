import SwiftUI

@MainActor
struct StepTwoDashboardPreview: View {
    let environment: AppEnvironment
    @State private var model: StepTwoDashboardViewModel
    @State private var appearance = PreviewAppearance.system
    @State private var sampleSelection: RSVPStatus? = .yes
    @State private var sampleState = PreviewState.empty
    @State private var rosterTab = PreviewRosterTab.players
    @State private var sampleMVP: UUID?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(environment: AppEnvironment) {
        self.environment = environment
        _model = State(initialValue: StepTwoDashboardViewModel(environment: environment))
        _sampleMVP = State(initialValue: environment.previewData?.profiles.dropFirst().first?.id)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SentraTheme.Spacing.xxLarge) {
                welcomeHero
                header.padding(.horizontal, SentraTheme.Spacing.large)
                switch model.state {
                case .loading:
                    LoadingOverlay(isLoading: true) { Color.clear.frame(height: 220) }
                case .failed(let error):
                    ErrorStateView(error: error) { Task { await model.load() } }
                        .padding(.horizontal, SentraTheme.Spacing.large)
                case .loaded(let snapshot):
                    content(snapshot)
                }
            }
            .padding(.bottom, SentraTheme.Spacing.xLarge)
            .frame(maxWidth: SentraTheme.Layout.contentWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(SentraTheme.Colors.background)
        .foregroundStyle(SentraTheme.Colors.ink)
        .navigationTitle("app.name")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { navigationMenu }
        .preferredColorScheme(appearance.colorScheme)
        .task { await model.load() }
    }

    private var welcomeHero: some View {
        VStack(spacing: 0) {
            VStack(spacing: SentraTheme.Spacing.medium) {
                Image(systemName: "soccerball")
                    .font(SentraTheme.Typography.rating)
                    .accessibilityHidden(true)
                Text("app.name").font(SentraTheme.Typography.brand)
                Text("preview.hero.tagline")
                    .font(SentraTheme.Typography.bodyStrong)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(SentraTheme.Spacing.xxLarge)
            .background(SentraTheme.Colors.mvpSurface.opacity(0.86))
            Spacer(minLength: SentraTheme.Spacing.xxLarge)
        }
        .frame(maxWidth: .infinity, minHeight: SentraTheme.Layout.heroHeight)
        .foregroundStyle(SentraTheme.Colors.onMVP)
        .background {
            GeometryReader { geometry in
                Image("WelcomePitch")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
            }
            .accessibilityHidden(true)
        }
        .clipped()
        .accessibilityElement(children: .combine)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: SentraTheme.Spacing.large) {
            let layout = dynamicTypeSize.isAccessibilitySize ?
                AnyLayout(VStackLayout(alignment: .leading, spacing: SentraTheme.Spacing.small)) :
                AnyLayout(HStackLayout(spacing: SentraTheme.Spacing.small))
            layout {
                SentraSectionHeader(title: "preview.title")
                SentraChip(title: "preview.offline", systemImage: "wifi.slash", tint: SentraTheme.Colors.mutedInk)
            }
            if dynamicTypeSize.isAccessibilitySize {
                appearancePicker.pickerStyle(.menu)
            } else {
                appearancePicker.pickerStyle(.segmented)
            }
        }
    }

    private var appearancePicker: some View {
        Picker("preview.appearance", selection: $appearance) {
            ForEach(PreviewAppearance.allCases) { value in
                Text(value.label).tag(value)
            }
        }
        .frame(minHeight: SentraTheme.Layout.minimumTarget)
    }

    @ViewBuilder
    private func content(_ snapshot: DashboardSnapshot) -> some View {
        VStack(alignment: .leading, spacing: SentraTheme.Spacing.large) {
            HStack(spacing: SentraTheme.Spacing.small) {
                SentraSectionHeader(title: "preview.nextMatch")
                Button { sampleSelection = nil } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .frame(width: SentraTheme.Layout.minimumTarget, height: SentraTheme.Layout.minimumTarget)
                }
                .accessibilityLabel(Text("action.clearSelection"))
                .help(Text("action.clearSelection"))
                .disabled(sampleSelection == nil)
            }
            MatchSummaryCard(
                match: snapshot.match, groupName: snapshot.group.name, counts: snapshot.counts,
                players: snapshot.profiles.filter { profile in
                    snapshot.responses.contains { $0.response.userID == profile.id && $0.response.status == .yes }
                }
            )
            VStack(spacing: SentraTheme.Spacing.small) {
                ForEach([RSVPStatus.yes, .maybe, .no]) { status in
                    RSVPButton(status: status, isSelected: sampleSelection == status) {
                        sampleSelection = status
                    }
                }
            }
            SentraSecondaryButton(title: "action.openMatch", systemImage: "soccerball") {
                environment.router.push(.matchDetail(snapshot.match.id))
            }
        }
        .padding(.horizontal, SentraTheme.Spacing.large)
        roster(snapshot)
        SentraProgressHeader(title: "route.finishMatch", currentStep: 1, totalSteps: 3,
                             stepTitles: ["progress.players", "progress.result", "progress.cost"])
            .padding(.horizontal, SentraTheme.Spacing.large)
        mvpSample(snapshot)
        VStack(alignment: .leading, spacing: SentraTheme.Spacing.large) {
            SentraSectionHeader(title: "preview.cards")
            LazyVGrid(columns: cardColumns, alignment: .leading, spacing: SentraTheme.Spacing.large) {
                ForEach(snapshot.cards) { example in
                    PlayerCardShell(example: example)
                }
            }
        }
        .padding(.horizontal, SentraTheme.Spacing.large)
        VStack(alignment: .leading, spacing: SentraTheme.Spacing.large) {
            SentraSectionHeader(title: "preview.states")
            if dynamicTypeSize.isAccessibilitySize {
                statePicker.pickerStyle(.menu)
            } else {
                statePicker.pickerStyle(.segmented)
            }
            stateExample.frame(minHeight: 220)
            SentraSecondaryButton(title: "action.refresh") { Task { await model.load() } }
        }
        .padding(.horizontal, SentraTheme.Spacing.large)
    }

    private func roster(_ snapshot: DashboardSnapshot) -> some View {
        VStack(alignment: .leading, spacing: SentraTheme.Spacing.small) {
            SentraSectionHeader(title: "preview.players")
                .padding(.horizontal, SentraTheme.Spacing.large)
            SentraSegmentedTabs(options: PreviewRosterTab.allCases, selection: $rosterTab) { tab in
                tab.label(count: snapshot.responses.filter { tab.contains($0.response.status) }.count)
            }
            .padding(.horizontal, SentraTheme.Spacing.large)
            ForEach(snapshot.responses.filter { rosterTab.contains($0.response.status) }) { entry in
                let profile = snapshot.profiles.first { $0.id == entry.response.userID }
                let guest = snapshot.guests.first { $0.id == entry.response.guestID }
                PlayerRow(
                    name: profile?.displayName ?? guest?.name ?? "",
                    position: profile?.position ?? .any, status: entry.response.status,
                    isGuest: guest != nil, waitlistPosition: entry.positionInWaitlist
                )
                .padding(.horizontal, SentraTheme.Spacing.large)
                Divider().padding(.horizontal, SentraTheme.Spacing.large)
            }
        }
        .padding(.vertical, SentraTheme.Spacing.large)
        .background(SentraTheme.Colors.surface)
    }

    private func mvpSample(_ snapshot: DashboardSnapshot) -> some View {
        VStack(alignment: .leading, spacing: SentraTheme.Spacing.small) {
            Text("preview.mvp")
                .font(SentraTheme.Typography.title)
                .padding(.bottom, SentraTheme.Spacing.medium)
                .accessibilityAddTraits(.isHeader)
            ForEach(Array(snapshot.profiles.dropFirst().prefix(5))) { profile in
                mvpRow(id: profile.id, name: profile.displayName, detail: profile.position.label)
            }
            ForEach(snapshot.guests) { guest in
                mvpRow(id: guest.id, name: guest.name, detail: "player.guest")
            }
        }
        .padding(SentraTheme.Spacing.xLarge)
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(SentraTheme.Colors.onMVP)
        .background(SentraTheme.Colors.mvpSurface)
        .environment(\.colorScheme, .dark)
    }

    private func mvpRow(id: UUID, name: String, detail: LocalizedStringResource) -> some View {
        Button { sampleMVP = sampleMVP == id ? nil : id } label: {
            HStack(spacing: SentraTheme.Spacing.medium) {
                SentraAvatar(name: name).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: SentraTheme.Spacing.tiny) {
                    Text(verbatim: name)
                        .font(SentraTheme.Typography.bodyStrong)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(detail)
                        .font(SentraTheme.Typography.caption)
                        .foregroundStyle(SentraTheme.Colors.mutedMVP)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: sampleMVP == id ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(sampleMVP == id ? SentraTheme.Colors.mvpAccent : SentraTheme.Colors.mutedMVP)
                    .frame(width: 28, height: 28)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, SentraTheme.Spacing.small)
            .frame(minHeight: SentraTheme.Layout.rowHeight)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) {
                Rectangle().fill(SentraTheme.Colors.onMVP.opacity(0.12)).frame(height: 0.5)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(sampleMVP == id ? .isSelected : [])
    }

    private var cardColumns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize ? [GridItem(.flexible())] :
            [GridItem(.adaptive(minimum: SentraTheme.Layout.cardMinimumWidth),
                      spacing: SentraTheme.Spacing.large, alignment: .top)]
    }

    private var statePicker: some View {
        Picker("preview.states", selection: $sampleState) {
            ForEach(PreviewState.allCases) { value in
                Text(value.label).tag(value)
            }
        }
        .frame(minHeight: SentraTheme.Layout.minimumTarget)
    }

    @ViewBuilder
    private var stateExample: some View {
        switch sampleState {
        case .empty:
            SentraEmptyState(title: "empty.group")
        case .loading:
            LoadingOverlay(isLoading: true) { Color.clear.frame(height: 180) }
        case .error:
            ErrorStateView(error: .network) { sampleState = .empty }
        }
    }

    @ToolbarContentBuilder
    private var navigationMenu: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button { environment.router.push(.groups) } label: {
                    Label("route.groups", systemImage: "person.3")
                }
                Button { environment.router.push(.createGroup) } label: {
                    Label("route.createGroup", systemImage: "plus")
                }
                Button { environment.router.push(.profile) } label: {
                    Label("route.profile", systemImage: "person.crop.circle")
                }
                Button { environment.router.push(.settings) } label: {
                    Label("route.settings", systemImage: "gearshape")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .frame(width: SentraTheme.Layout.minimumTarget, height: SentraTheme.Layout.minimumTarget)
            }
            .accessibilityLabel(Text("action.menu"))
            .help(Text("action.menu"))
        }
    }
}

private enum PreviewRosterTab: String, CaseIterable, Identifiable {
    case players, waitlist, other
    var id: String { rawValue }

    func contains(_ status: RSVPStatus) -> Bool {
        switch self {
        case .players: return status == .yes
        case .waitlist: return status == .waitlist
        case .other: return status == .maybe || status == .no
        }
    }

    func label(count: Int) -> Text {
        switch self {
        case .players: return Text("preview.roster.players \(count)")
        case .waitlist: return Text("preview.roster.waitlist \(count)")
        case .other: return Text("preview.roster.other \(count)")
        }
    }
}

private enum PreviewAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
    var label: LocalizedStringResource {
        switch self {
        case .system: return "appearance.system"
        case .light: return "appearance.light"
        case .dark: return "appearance.dark"
        }
    }
}

private enum PreviewState: String, CaseIterable, Identifiable {
    case empty, loading, error
    var id: String { rawValue }
    var label: LocalizedStringResource {
        switch self {
        case .empty: return "state.empty"
        case .loading: return "state.loading"
        case .error: return "state.error"
        }
    }
}

#Preview("Light") {
    SentraRootView(environment: .preview(data: MockDataFactory.make(referenceDate: Date())))
        .environment(\.locale, Locale(identifier: "el"))
        .preferredColorScheme(.light)
}

#Preview("Dark / Accessibility") {
    SentraRootView(environment: .preview(data: MockDataFactory.make(referenceDate: Date())))
        .environment(\.locale, Locale(identifier: "el"))
        .environment(\.dynamicTypeSize, .accessibility3)
        .preferredColorScheme(.dark)
}