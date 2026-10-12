import XCTest
@testable import Sentra

final class ConfigurationTests: XCTestCase {
    func testMissingAndUnexpandedSettingsFailSafely() {
        XCTAssertThrowsError(try AppConfiguration(values: [:]))
        XCTAssertThrowsError(try configuration(url: "$(SUPABASE_URL)"))
        XCTAssertThrowsError(try configuration(key: "YOUR_SUPABASE_ANON_KEY"))
    }

    func testOnlyHTTPSOrLoopbackHTTPIsAccepted() throws {
        XCTAssertNoThrow(try configuration())
        XCTAssertNoThrow(try configuration(url: "http://127.0.0.1:54321"))
        XCTAssertThrowsError(try configuration(url: "http://example.supabase.co"))
        XCTAssertThrowsError(try configuration(url: "https://user:password@example.supabase.co"))
        XCTAssertThrowsError(try configuration(url: "https://example.supabase.co?key=value"))
        XCTAssertThrowsError(try configuration(url: "https://example.supabase.co/rest/v1"))
    }

    func testPrivilegedKeysAreRejectedAndDescriptionsAreRedacted() throws {
        XCTAssertThrowsError(try configuration(key: "sb_secret_test_only"))
        XCTAssertThrowsError(try configuration(key: legacyKey(role: "service_role")))
        XCTAssertNoThrow(try configuration(key: legacyKey(role: "anon")))
        let settings = try configuration()
        XCTAssertFalse(settings.description.contains(settings.supabaseAnonKey))
        XCTAssertFalse(settings.debugDescription.contains(settings.supabaseURL.absoluteString))
    }

    private func configuration(
        url: String = "https://example.supabase.co",
        key: String = "sb_publishable_test_only"
    ) throws -> AppConfiguration {
        try AppConfiguration(values: ["SUPABASE_URL": url, "SUPABASE_ANON_KEY": key])
    }

    private func legacyKey(role: String) throws -> String {
        let data = try JSONEncoder().encode(["role": role])
        let payload = data.base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        return "test-header.\(payload).test-signature"
    }
}