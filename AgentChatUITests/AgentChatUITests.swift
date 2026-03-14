import XCTest

final class AgentChatUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting-reset"]
        app.launch()
    }

    // MARK: - Chat List

    @MainActor
    func testSeedChatsAppearOnLaunch() throws {
        // Allow time for async seed to complete and chat list to reload
        let found = app.staticTexts["Mumbai Flight Booking"].waitForExistence(timeout: 15)
        if !found {
            // Print what's visible to diagnose
            let allLabels = app.staticTexts.allElementsBoundByIndex.map { $0.label }
            XCTFail("Expected 'Mumbai Flight Booking'. Visible texts: \(allLabels)")
        }
        XCTAssertTrue(app.staticTexts["Hotel Reservation Help"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Restaurant Recommendations"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testCreateNewChatAndNavigate() throws {
        let newChatButton = app.buttons["newChatButton"]
        XCTAssertTrue(newChatButton.waitForExistence(timeout: 5))
        newChatButton.tap()

        // Should show empty state in chat detail
        XCTAssertTrue(app.staticTexts["No Messages"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSendMessageAppearsInChat() throws {
        // Create a new chat
        let newChatButton = app.buttons["newChatButton"]
        XCTAssertTrue(newChatButton.waitForExistence(timeout: 5))
        newChatButton.tap()

        // Wait for detail screen
        XCTAssertTrue(app.staticTexts["No Messages"].waitForExistence(timeout: 5))

        // Type and send a message
        let messageInput = app.textViews["messageInput"]
        XCTAssertTrue(messageInput.waitForExistence(timeout: 3))
        messageInput.tap()
        messageInput.typeText("Hello agent")

        let sendButton = app.buttons["sendButton"]
        sendButton.tap()

        // Verify user message appears
        XCTAssertTrue(app.staticTexts["Hello agent"].waitForExistence(timeout: 3))

        // Empty state should be gone
        XCTAssertFalse(app.staticTexts["No Messages"].exists)
    }

    @MainActor
    func testAgentRepliesAfterUserMessage() throws {
        // Create new chat
        app.buttons["newChatButton"].tap()
        XCTAssertTrue(app.staticTexts["No Messages"].waitForExistence(timeout: 5))

        // Send message
        let messageInput = app.textViews["messageInput"]
        messageInput.tap()
        messageInput.typeText("Test")
        app.buttons["sendButton"].tap()

        // Wait for agent reply (1-2s delay + buffer)
        sleep(4)

        // Check there are multiple static texts beyond the user message
        // The agent reply should add at least one more text element
        let allTexts = app.staticTexts.allElementsBoundByIndex
        let messageTexts = allTexts.filter { $0.label != "Test" && !$0.label.isEmpty && $0.label != "No Messages" }
        XCTAssertTrue(messageTexts.count > 0, "Expected agent reply to appear")
    }

    @MainActor
    func testTapSeedChatShowsMessages() throws {
        let mumbaiChat = app.staticTexts["Mumbai Flight Booking"]
        XCTAssertTrue(mumbaiChat.waitForExistence(timeout: 5))
        mumbaiChat.tap()

        // Should show first seed message
        XCTAssertTrue(app.staticTexts["Hi! I need help booking a flight to Mumbai."].waitForExistence(timeout: 5))
    }

    @MainActor
    func testAutoTitleOnFirstMessage() throws {
        // Create new chat
        app.buttons["newChatButton"].tap()
        XCTAssertTrue(app.staticTexts["No Messages"].waitForExistence(timeout: 5))

        // Title should be "New Chat"
        XCTAssertTrue(app.buttons["New Chat"].waitForExistence(timeout: 3))

        // Send first message
        let messageInput = app.textViews["messageInput"]
        messageInput.tap()
        messageInput.typeText("Book a flight to Delhi")
        app.buttons["sendButton"].tap()

        // Wait for message to process
        sleep(1)

        // Title should auto-update
        XCTAssertTrue(app.buttons["Book a flight to Delhi"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testDeleteChat() throws {
        let mumbaiChat = app.staticTexts["Mumbai Flight Booking"]
        XCTAssertTrue(mumbaiChat.waitForExistence(timeout: 5))

        // Swipe to delete
        mumbaiChat.swipeLeft()

        let deleteButton = app.buttons["Delete"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 2))
        deleteButton.tap()

        // Chat should be gone
        sleep(1)
        XCTAssertFalse(app.staticTexts["Mumbai Flight Booking"].exists)
    }

    @MainActor
    func testNavigateBackShowsUpdatedLastMessage() throws {
        // Create new chat
        app.buttons["newChatButton"].tap()
        XCTAssertTrue(app.staticTexts["No Messages"].waitForExistence(timeout: 5))

        // Send a message
        let messageInput = app.textViews["messageInput"]
        messageInput.tap()
        messageInput.typeText("Unique test msg 123")
        app.buttons["sendButton"].tap()
        XCTAssertTrue(app.staticTexts["Unique test msg 123"].waitForExistence(timeout: 3))

        // Go back
        app.navigationBars.buttons.firstMatch.tap()

        // Chat list should show the last message
        XCTAssertTrue(app.staticTexts["Unique test msg 123"].waitForExistence(timeout: 5))
    }
}
