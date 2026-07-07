import XCTest

final class ImporterPolicyTests: XCTestCase {
    func testImporterDoesNotExposePrivateCabinetCodeByDefault() throws {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let repositoryRoot = testFileURL.deletingLastPathComponent().deletingLastPathComponent()
        let scriptURL = repositoryRoot.appendingPathComponent("Tools/import_aeds.py")
        let script = try String(contentsOf: scriptURL, encoding: .utf8)

        XCTAssertTrue(script.contains("if code and public:"))
        XCTAssertTrue(script.contains("Call emergency services for code"))
    }

    func testImporterRequiresLicenceAndVersionedPackMetadata() throws {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let repositoryRoot = testFileURL.deletingLastPathComponent().deletingLastPathComponent()
        let scriptURL = repositoryRoot.appendingPathComponent("Tools/import_aeds.py")
        let script = try String(contentsOf: scriptURL, encoding: .utf8)

        XCTAssertTrue(script.contains("parser.add_argument(\"--dataset-id\", required=True"))
        XCTAssertTrue(script.contains("parser.add_argument(\"--region-id\", required=True"))
        XCTAssertTrue(script.contains("parser.add_argument(\"--version\", required=True"))
        XCTAssertTrue(script.contains("parser.add_argument(\"--licence\", required=True"))
        XCTAssertTrue(script.contains("licence_text TEXT"))
        XCTAssertTrue(script.contains("\"dataset_id\""))
        XCTAssertTrue(script.contains("\"schema_version\""))
    }
}
