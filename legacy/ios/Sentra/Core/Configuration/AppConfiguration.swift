import Foundation

struct AppConfiguration: Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    let supabaseURL: URL
    let supabaseAnonKey: String
    let universalLinkDomain: String?
    let revenueCatPublicSDKKey: String?

    var description: String { "AppConfiguration(<redacted>)" }
    var debugDescription: String { description }

    init(values: [String: String]) throws {
        guard let urlValue = Self.value("SUPABASE_URL", in: values),
              let components = URLComponents(string: urlValue),
              let host = components.host, !host.isEmpty,
              components.user == nil, components.password == nil,
              components.query == nil, components.fragment == nil,
              components.path.isEmpty || components.path == "/",
              let url = components.url else {
            throw AppError.configuration
        }
        let isLoopback = ["localhost", "127.0.0.1", "[::1]", "::1"].contains(host)
        guard components.scheme == "https" || (components.scheme == "http" && isLoopback),
              let key = Self.value("SUPABASE_ANON_KEY", in: values),
              !key.contains(where: { $0.isWhitespace }), Self.isPublicKey(key) else {
            throw AppError.configuration
        }
        supabaseURL = url
        supabaseAnonKey = key
        if let domain = Self.value("UNIVERSAL_LINK_DOMAIN", in: values) {
            guard let domainURL = URLComponents(string: "https://\(domain)"),
                  domainURL.host == domain, domainURL.port == nil,
                  domainURL.path.isEmpty, domainURL.query == nil,
                  domainURL.fragment == nil, domainURL.user == nil else {
                throw AppError.configuration
            }
            universalLinkDomain = domain
        } else {
            universalLinkDomain = nil
        }
        if let key = Self.value("REVENUECAT_PUBLIC_SDK_KEY", in: values) {
            guard key.hasPrefix("appl_") || key.hasPrefix("test_") else {
                throw AppError.configuration
            }
            revenueCatPublicSDKKey = key
        } else {
            revenueCatPublicSDKKey = nil
        }
    }

    static func load(bundle: Bundle = .main) throws -> AppConfiguration {
        let keys = ["SUPABASE_URL", "SUPABASE_ANON_KEY", "UNIVERSAL_LINK_DOMAIN", "REVENUECAT_PUBLIC_SDK_KEY"]
        let values = keys.reduce(into: [String: String]()) { result, key in
            result[key] = bundle.object(forInfoDictionaryKey: key) as? String
        }
        return try AppConfiguration(values: values)
    }

    private static func value(_ key: String, in values: [String: String]) -> String? {
        guard let value = values[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty, !value.contains("$("), !value.uppercased().contains("YOUR_") else {
            return nil
        }
        return value
    }

    private static func isPublicKey(_ key: String) -> Bool {
        if key.hasPrefix("sb_publishable_") {
            return key.count > "sb_publishable_".count
        }
        let segments = key.split(separator: ".", omittingEmptySubsequences: false)
        guard segments.count == 3, segments.allSatisfy({ !$0.isEmpty }) else { return false }
        var payload = String(segments[1]).replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        payload += String(repeating: "=", count: (4 - payload.count % 4) % 4)
        guard let data = Data(base64Encoded: payload),
              let claims = try? JSONDecoder().decode(KeyClaims.self, from: data) else { return false }
        return claims.role == "anon"
    }

    private struct KeyClaims: Decodable {
        let role: String
    }
}