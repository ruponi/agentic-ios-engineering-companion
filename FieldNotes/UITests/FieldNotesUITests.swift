import XCTest

@MainActor
final class FieldNotesUITests: XCTestCase {
    func testReaderCanCreateAndOpenANote() {
        let app = XCUIApplication()
        app.launch()
        let title = "Kyoto packing \(UUID().uuidString.prefix(8))"

        XCTAssertTrue(notesList(in: app).waitForExistence(timeout: 5))
        app.buttons["new-note"].tap()

        let editor = app.textViews["note-text"]
        XCTAssertTrue(editor.waitForExistence(timeout: 3))
        editor.tap()
        editor.typeText("\(title)\nRain shell and notebook")
        app.buttons["save-note"].tap()

        let savedNote = app.buttons[title]
        XCTAssertTrue(savedNote.waitForExistence(timeout: 3))
        savedNote.tap()
        XCTAssertTrue(app.navigationBars["Note"].waitForExistence(timeout: 3))
    }

    func testPrimaryScreensPassAccessibilityAudit() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(notesList(in: app).waitForExistence(timeout: 5))
        try app.performAccessibilityAudit(for: [.sufficientElementDescription, .elementDetection])
    }

    func testIntelligenceFallbackStatesPassAccessibilityAudit() throws {
        for state in ["device-ineligible", "model-not-ready", "framework-unavailable"] {
            let app = XCUIApplication()
            app.launchEnvironment["FIELDNOTES_INTELLIGENCE_STATE"] = state
            app.launch()

            XCTAssertTrue(
                app.descendants(matching: .any)["intelligence-fallback"]
                    .waitForExistence(timeout: 5)
            )
            try app.performAccessibilityAudit(
                for: [.sufficientElementDescription, .elementDetection]
            )

            if state == "model-not-ready" {
                XCTAssertTrue(app.buttons["Retry"].exists)
            } else {
                XCTAssertFalse(app.buttons["Retry"].exists)
            }
            app.terminate()
        }
    }

    func testWriteApprovalShowsExactTypedAction() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-show-write-approval")
        app.launch()

        XCTAssertTrue(
            app.descendants(matching: .any)["write-approval"].waitForExistence(timeout: 5)
        )
        XCTAssertTrue(app.staticTexts["Tool, savePackingBrief"].exists)
        XCTAssertTrue(app.staticTexts["Effect, reversibleWrite"].exists)
        let title = app.textFields["approval-title"]
        scrollUntilExists(title, in: app)
        XCTAssertEqual(title.value as? String, "Kyoto packing brief")
        XCTAssertTrue(app.staticTexts["Item 1, Rain shell"].exists)
        for _ in 0..<4 where !app.buttons["approve-write"].exists {
            app.collectionViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(app.buttons["approve-write"].exists)
        scrollUntilExists(app.buttons["decline-write"], in: app)
        XCTAssertTrue(app.buttons["decline-write"].exists)
        try app.performAccessibilityAudit(
            for: [.sufficientElementDescription, .elementDetection]
        )
    }

    func testAmendingWriteReplacesIdentityBeforeApproval() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-show-write-approval")
        app.launch()

        XCTAssertTrue(
            app.descendants(matching: .any)["write-approval"]
                .waitForExistence(timeout: 5)
        )
        let originalID = proposalID(in: app).label
        let title = app.textFields["approval-title"]
        scrollUntilExists(title, in: app)
        XCTAssertTrue(title.exists)
        title.tap()
        title.typeText(" for the weekend")
        app.keyboards.buttons["Return"].tap()
        for _ in 0..<4 where !app.buttons["amend-write"].isHittable {
            app.collectionViews.firstMatch.swipeUp()
        }
        app.buttons["amend-write"].tap()
        for _ in 0..<4 where !proposalID(in: app).exists {
            app.collectionViews.firstMatch.swipeDown()
        }

        XCTAssertNotEqual(proposalID(in: app).label, originalID)
        try app.performAccessibilityAudit(
            for: [.sufficientElementDescription, .elementDetection]
        )
    }

    func testAgentUncertaintyShowsAdmittedSourceAndPassesAudit() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-show-agent-experience")
        app.launch()

        XCTAssertTrue(
            app.descendants(matching: .any)["agent-experience"]
                .waitForExistence(timeout: 5)
        )
        let source = app.descendants(matching: .any)[
            "agent-source-11111111-1111-1111-1111-111111111111"
        ]
        XCTAssertTrue(source.exists)
        try app.performAccessibilityAudit(
            for: [.sufficientElementDescription, .elementDetection]
        )
    }

    func testVoiceOnlyApprovalOffersScreenTransfer() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-show-voice-interaction")
        app.launch()

        XCTAssertTrue(
            app.descendants(matching: .any)["voice-interaction"]
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(app.buttons["voice-transfer"].exists)
        XCTAssertFalse(app.buttons["approve-write"].exists)
        try app.performAccessibilityAudit(
            for: [.sufficientElementDescription, .elementDetection]
        )
    }

    private func notesList(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["notes-list"]
    }

    private func proposalID(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["proposal-id"]
    }

    private func scrollUntilExists(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<4 where !element.exists {
            app.collectionViews.firstMatch.swipeUp()
        }
    }
}
