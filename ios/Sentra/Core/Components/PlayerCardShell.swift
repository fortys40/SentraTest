import SwiftUI

@MainActor
struct PlayerCardShell: View {
    let example: PlayerCardExample

    var body: some View {
        PlayerCardView(example: example, motion: .preview)
    }
}