import PhotosUI
import SwiftUI

@MainActor
struct PhotoAdjustView: View {
    let example: PlayerCardExample
    @Binding private var photo: CardPhoto?
    @State private var draft: CardPhoto?
    @State private var originalData: Data?
    @State private var selectedItem: PhotosPickerItem?
    @State private var resetRevision = 0
    @State private var operationID: UUID?
    @State private var showsError = false
    @Environment(\.dismiss) private var dismiss
    private let cropService = PhotoCropService()

    private var isLoading: Bool { operationID != nil }

    init(example: PlayerCardExample, photo: Binding<CardPhoto?>) {
        self.example = example
        _photo = photo
        _draft = State(initialValue: photo.wrappedValue)
        _originalData = State(initialValue: photo.wrappedValue?.imageData)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    PhotosPicker(selection: $selectedItem, matching: .images, preferredItemEncoding: .current) {
                        Label("card.photo.choose", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isLoading)
                    PlayerCardView(example: example, photo: draft, size: .large, motion: .disabled,
                                   onCropChange: isLoading ? nil : updateCrop)
                    if isLoading {
                        ProgressView("card.photo.processing")
                    }
                    if draft != nil {
                        cropControls.disabled(isLoading)
                    }
                    SentraSecondaryButton(title: "card.photo.reset", systemImage: "arrow.counterclockwise") {
                        resetRevision += 1
                    }
                    .disabled(draft == nil || isLoading)
                    SentraPrimaryButton(title: "card.photo.save", systemImage: "checkmark") {
                        photo = draft
                        dismiss()
                    }
                    .disabled(draft == nil || isLoading)
                }
                .padding(16)
                .frame(maxWidth: 440)
                .frame(maxWidth: .infinity)
            }
            .background(SentraTheme.Colors.background)
            .navigationTitle("card.photo.adjust")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("card.photo.cancel") { dismiss() }
                }
            }
            .task(id: selectedItem) { await loadSelection() }
            .task(id: resetRevision) {
                if resetRevision > 0, let originalData { await prepare(originalData) }
            }
            .alert("card.photo.error", isPresented: $showsError) {
                Button("card.photo.ok", role: .cancel) {}
            }
        }
    }

    private var cropControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("card.photo.zoom").font(.caption)
            Slider(value: Binding(get: { draft?.crop.zoom ?? 1 }, set: { value in
                guard let draft else { return }
                updateCrop(PhotoCropGeometry.zoomed(draft.crop, magnification: value / draft.crop.zoom,
                                                     image: draft.dimensions))
            }), in: 1...PhotoCropGeometry.maximumZoom)
                .frame(minHeight: 44)
                .accessibilityLabel(Text("card.photo.zoom"))
            Text("card.photo.horizontal").font(.caption)
            Slider(value: Binding(get: { draft?.crop.focusX ?? 0.5 }, set: { value in
                guard let draft else { return }
                updateCrop(PhotoCrop(focusX: value, focusY: draft.crop.focusY, zoom: draft.crop.zoom))
            }), in: 0...1)
                .frame(minHeight: 44)
                .accessibilityLabel(Text("card.photo.horizontal"))
            Text("card.photo.vertical").font(.caption)
            Slider(value: Binding(get: { draft?.crop.focusY ?? 0.5 }, set: { value in
                guard let draft else { return }
                updateCrop(PhotoCrop(focusX: draft.crop.focusX, focusY: value, zoom: draft.crop.zoom))
            }), in: 0...1)
                .frame(minHeight: 44)
                .accessibilityLabel(Text("card.photo.vertical"))
        }
    }

    private func updateCrop(_ crop: PhotoCrop) {
        guard var updated = draft else { return }
        updated.crop = PhotoCropGeometry.constrained(crop, image: updated.dimensions)
        draft = updated
    }

    private func loadSelection() async {
        guard let selectedItem else { return }
        let operation = UUID()
        operationID = operation
        defer { if operationID == operation { operationID = nil } }
        do {
            guard let data = try await selectedItem.loadTransferable(type: Data.self) else {
                throw PhotoCropService.Failure.invalidImage
            }
            try Task.checkCancellation()
            let prepared = try await cropService.prepare(data: data)
            try Task.checkCancellation()
            guard operationID == operation else { return }
            originalData = data
            draft = prepared
        } catch is CancellationError {
            return
        } catch {
            if operationID == operation && !Task.isCancelled { showsError = true }
        }
    }

    private func prepare(_ data: Data) async {
        let operation = UUID()
        operationID = operation
        defer { if operationID == operation { operationID = nil } }
        do {
            let prepared = try await cropService.prepare(data: data)
            try Task.checkCancellation()
            guard operationID == operation else { return }
            draft = prepared
        } catch is CancellationError {
            return
        } catch {
            if operationID == operation && !Task.isCancelled { showsError = true }
        }
    }
}

@MainActor
struct PhotoCropInteraction: ViewModifier {
    let photo: CardPhoto?
    let onChange: ((PhotoCrop) -> Void)?
    @State private var initialCrop: PhotoCrop?

    func body(content: Content) -> some View {
        content.overlay {
            if let photo, let onChange {
                GeometryReader { geometry in
                    let viewport = PhotoDimensions(width: Double(geometry.size.width), height: Double(geometry.size.height))
                    Color.clear
                        .contentShape(SentraPortraitFrame())
                        .gesture(DragGesture(minimumDistance: 1).simultaneously(with: MagnificationGesture())
                            .onChanged { value in
                                let base = initialCrop ?? photo.crop
                                if initialCrop == nil { initialCrop = base }
                                let zoomed = PhotoCropGeometry.zoomed(base, magnification: Double(value.second ?? 1),
                                                                     image: photo.dimensions, viewport: viewport)
                                let translation = value.first?.translation ?? .zero
                                onChange(PhotoCropGeometry.panned(zoomed, horizontal: Double(translation.width),
                                                                  vertical: Double(translation.height),
                                                                  image: photo.dimensions, viewport: viewport))
                            }
                            .onEnded { _ in initialCrop = nil })
                        .accessibilityHidden(true)
                }
            }
        }
        .onChange(of: photo?.id) { _, _ in initialCrop = nil }
    }
}