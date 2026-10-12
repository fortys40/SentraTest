import Foundation
import Supabase

@MainActor
final class SupabaseProvider {
    let client: SupabaseClient

    init(configuration: AppConfiguration, session: URLSession = .shared) {
        client = SupabaseClient(
            supabaseURL: configuration.supabaseURL,
            supabaseKey: configuration.supabaseAnonKey,
            options: SupabaseClientOptions(
                db: .init(schema: "public", encoder: SentraJSON.encoder(), decoder: SentraJSON.decoder()),
                global: .init(session: session, logger: nil)
            )
        )
    }
}