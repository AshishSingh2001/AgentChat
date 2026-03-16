import XCTest

final class AgentChatUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting-reset"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app.terminate()
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

    // MARK: - Image Viewer

    @MainActor
    func testTapImageMessageOpensViewer() throws {
        // Navigate into Mumbai Flight Booking which has image messages in seed data
        let mumbaiChat = app.staticTexts["Mumbai Flight Booking"]
        XCTAssertTrue(mumbaiChat.waitForExistence(timeout: 15))
        mumbaiChat.tap()

        // Wait for first message to confirm the chat loaded
        XCTAssertTrue(app.staticTexts["Hi! I need help booking a flight to Mumbai."].waitForExistence(timeout: 5))

        // msg-007 is an image message — wait for it to appear (it may already be visible)
        // then swipe down if needed
        let imageBubble = app.otherElements["message_msg-007"]
        if !imageBubble.waitForExistence(timeout: 3) {
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(imageBubble.waitForExistence(timeout: 5))
        imageBubble.tap()

        // Image viewer should be presented (close button visible)
        XCTAssertTrue(app.buttons["imageViewerCloseButton"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testImageViewerCloseButtonDismissesViewer() throws {
        let mumbaiChat = app.staticTexts["Mumbai Flight Booking"]
        XCTAssertTrue(mumbaiChat.waitForExistence(timeout: 15))
        mumbaiChat.tap()

        XCTAssertTrue(app.staticTexts["Hi! I need help booking a flight to Mumbai."].waitForExistence(timeout: 5))

        let imageBubble = app.otherElements["message_msg-007"]
        if !imageBubble.waitForExistence(timeout: 3) {
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(imageBubble.waitForExistence(timeout: 5))
        imageBubble.tap()

        let closeButton = app.buttons["imageViewerCloseButton"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 3))
        closeButton.tap()

        // Viewer dismissed — close button gone
        XCTAssertFalse(app.buttons["imageViewerCloseButton"].waitForExistence(timeout: 2))
    }

    // MARK: - Title Edit

    @MainActor
    func testTitleEditSheetAppearsOnTitleTap() throws {
        app.buttons["newChatButton"].tap()
        XCTAssertTrue(app.staticTexts["No Messages"].waitForExistence(timeout: 5))

        let titleButton = app.buttons["chatTitleButton"]
        XCTAssertTrue(titleButton.waitForExistence(timeout: 3))
        titleButton.tap()

        // Title edit sheet should appear with "Rename Chat" nav title
        XCTAssertTrue(app.staticTexts["Rename Chat"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testTitleEditSaveUpdatesTitle() throws {
        app.buttons["newChatButton"].tap()
        XCTAssertTrue(app.staticTexts["No Messages"].waitForExistence(timeout: 5))

        // Tap title button to open sheet
        app.buttons["chatTitleButton"].tap()
        XCTAssertTrue(app.staticTexts["Rename Chat"].waitForExistence(timeout: 3))

        // Clear existing title and type new one
        let titleField = app.textFields["Chat title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 3))
        titleField.tap()
        titleField.clearAndEnterText("My Custom Chat")

        app.buttons["Save"].tap()

        // Sheet dismissed, title updated in nav bar
        XCTAssertTrue(app.buttons["My Custom Chat"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testTitleEditCancelDoesNotChangeTitle() throws {
        app.buttons["newChatButton"].tap()
        XCTAssertTrue(app.staticTexts["No Messages"].waitForExistence(timeout: 5))

        app.buttons["chatTitleButton"].tap()
        XCTAssertTrue(app.staticTexts["Rename Chat"].waitForExistence(timeout: 3))

        let titleField = app.textFields["Chat title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 3))
        titleField.tap()
        titleField.clearAndEnterText("Should Not Save")

        app.buttons["Cancel"].tap()

        // Title should still be "New Chat"
        XCTAssertTrue(app.buttons["New Chat"].waitForExistence(timeout: 3))
    }

    // MARK: - New Message Toast

    @MainActor
    func testAgentReplyShowsNewMessageToast() throws {
        // Relaunch with slow agent (6–8s delay) so we have time to scroll away before reply arrives.
        // --uitesting-reply-every-4 forces interval=4 so the agent always replies after exactly 4 messages.
        app.terminate()
        app.launchArguments = ["--uitesting-reset", "--uitesting-slow-agent", "--uitesting-reply-every-4"]
        app.launch()

        // Use Hotel Reservation Help — last seed message is from agent (msg-016),
        // gap starts at 0. Send 4 messages → gap=4 → triggers reply.
        let hotelChat = app.staticTexts["Hotel Reservation Help"]
        XCTAssertTrue(hotelChat.waitForExistence(timeout: 15))
        hotelChat.tap()

        XCTAssertTrue(app.staticTexts["I need to find a hotel in Bangalore for 3 nights."].waitForExistence(timeout: 5))

        let messageInput = app.textViews["messageInput"]
        XCTAssertTrue(messageInput.waitForExistence(timeout: 3))
        for i in 1...4 {
            messageInput.tap()
            messageInput.typeText("msg \(i)")
            app.buttons["sendButton"].tap()
            _ = app.staticTexts["msg \(i)"].waitForExistence(timeout: 3)
        }

        // Drag from the last bubble upward to scroll toward older messages
        let lastBubble = app.staticTexts["msg 4"]
        XCTAssertTrue(lastBubble.waitForExistence(timeout: 3))
        let bubbleCenter = lastBubble.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let dragEnd = lastBubble.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 5.0))
        bubbleCenter.press(forDuration: 0.05, thenDragTo: dragEnd)
        bubbleCenter.press(forDuration: 0.05, thenDragTo: dragEnd)
        bubbleCenter.press(forDuration: 0.05, thenDragTo: dragEnd)

        // Agent reply arrives (6–8s delay) → toast appears because isNearBottom == false
        XCTAssertTrue(app.buttons["newMessageToastButton"].waitForExistence(timeout: 15))
    }

    @MainActor
    func testTappingToastDismissesIt() throws {
        // Relaunch with slow agent (6–8s delay) so we have time to scroll away before reply arrives.
        // --uitesting-reply-every-4 forces interval=4 so the agent always replies after exactly 4 messages.
        app.terminate()
        app.launchArguments = ["--uitesting-reset", "--uitesting-slow-agent", "--uitesting-reply-every-4"]
        app.launch()

        let hotelChat = app.staticTexts["Hotel Reservation Help"]
        XCTAssertTrue(hotelChat.waitForExistence(timeout: 15))
        hotelChat.tap()

        XCTAssertTrue(app.staticTexts["I need to find a hotel in Bangalore for 3 nights."].waitForExistence(timeout: 5))

        let messageInput = app.textViews["messageInput"]
        XCTAssertTrue(messageInput.waitForExistence(timeout: 3))
        for i in 1...4 {
            messageInput.tap()
            messageInput.typeText("msg \(i)")
            app.buttons["sendButton"].tap()
            _ = app.staticTexts["msg \(i)"].waitForExistence(timeout: 3)
        }

        // Drag from the last bubble upward to scroll toward older messages
        let lastBubble = app.staticTexts["msg 4"]
        XCTAssertTrue(lastBubble.waitForExistence(timeout: 3))
        let bubbleCenter = lastBubble.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let dragEnd = lastBubble.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 5.0))
        bubbleCenter.press(forDuration: 0.05, thenDragTo: dragEnd)
        bubbleCenter.press(forDuration: 0.05, thenDragTo: dragEnd)
        bubbleCenter.press(forDuration: 0.05, thenDragTo: dragEnd)

        let toastButton = app.buttons["newMessageToastButton"]
        XCTAssertTrue(toastButton.waitForExistence(timeout: 15))

        toastButton.tap()
        let gone = XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: toastButton
        )], timeout: 5)
        XCTAssertEqual(gone, .completed, "Toast should disappear after tap")
    }

    // MARK: - InputBar

    @MainActor
    func testSendButtonDisabledWhenInputEmpty() throws {
        app.buttons["newChatButton"].tap()
        XCTAssertTrue(app.staticTexts["No Messages"].waitForExistence(timeout: 5))

        let sendButton = app.buttons["sendButton"]
        XCTAssertTrue(sendButton.waitForExistence(timeout: 3))
        XCTAssertFalse(sendButton.isEnabled)
    }

    @MainActor
    func testSendButtonEnabledAfterTyping() throws {
        app.buttons["newChatButton"].tap()
        XCTAssertTrue(app.staticTexts["No Messages"].waitForExistence(timeout: 5))

        let messageInput = app.textViews["messageInput"]
        XCTAssertTrue(messageInput.waitForExistence(timeout: 3))
        messageInput.tap()
        messageInput.typeText("Hello")

        XCTAssertTrue(app.buttons["sendButton"].isEnabled)
    }

    @MainActor
    func testSendClearsInputField() throws {
        app.buttons["newChatButton"].tap()
        XCTAssertTrue(app.staticTexts["No Messages"].waitForExistence(timeout: 5))

        let messageInput = app.textViews["messageInput"]
        XCTAssertTrue(messageInput.waitForExistence(timeout: 3))
        messageInput.tap()
        messageInput.typeText("Test message")

        app.buttons["sendButton"].tap()

        // Input should be empty after send
        let value = messageInput.value as? String ?? ""
        XCTAssertTrue(value.isEmpty, "Input should be cleared after sending")
    }

    @MainActor
    func testPlaceholderVisibleWhenEmpty() throws {
        app.buttons["newChatButton"].tap()
        XCTAssertTrue(app.staticTexts["No Messages"].waitForExistence(timeout: 5))

        // "Message" placeholder is shown when input is empty
        XCTAssertTrue(app.staticTexts["Message"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testAttachmentButtonShowsSourceMenu() throws {
        app.buttons["newChatButton"].tap()
        XCTAssertTrue(app.staticTexts["No Messages"].waitForExistence(timeout: 5))

        let attachmentButton = app.buttons["attachmentButton"]
        XCTAssertTrue(attachmentButton.waitForExistence(timeout: 3))
        attachmentButton.tap()

        // confirmationDialog presents options — Photo Library appears as a button in the sheet
        let photoLibrary = app.buttons["Photo Library"]
        XCTAssertTrue(photoLibrary.waitForExistence(timeout: 3))
        // Dismiss by tapping outside the sheet
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)).tap()
    }

    // MARK: - Agent Reply Behaviour

    @MainActor
    func testAgentReplyUpdatesLastMessageInChatList() throws {
        // Relaunch forcing interval=4 so the agent always replies after exactly 4 messages.
        app.terminate()
        app.launchArguments = ["--uitesting-reset", "--uitesting-reply-every-4"]
        app.launch()

        // Hotel chat ends with agent message — send 4 to trigger reply
        let hotelChat = app.staticTexts["Hotel Reservation Help"]
        XCTAssertTrue(hotelChat.waitForExistence(timeout: 15))
        hotelChat.tap()

        XCTAssertTrue(app.staticTexts["I need to find a hotel in Bangalore for 3 nights."].waitForExistence(timeout: 5))

        let messageInput = app.textViews["messageInput"]
        XCTAssertTrue(messageInput.waitForExistence(timeout: 3))
        for i in 1...4 {
            messageInput.tap()
            messageInput.typeText("msg \(i)")
            app.buttons["sendButton"].tap()
            _ = app.staticTexts["msg \(i)"].waitForExistence(timeout: 3)
        }

        // Wait for agent reply to arrive
        sleep(4)

        // Go back and verify the chat row shows the agent's reply as last message (not user's)
        app.navigationBars.buttons.firstMatch.tap()

        // The last message shown in the row should NOT be the user's last message
        // (agent replied, so its text is the preview)
        let lastUserMsg = app.staticTexts["msg 4"]
        XCTAssertFalse(lastUserMsg.waitForExistence(timeout: 2), "Last message should be agent reply, not user message")
    }

    @MainActor
    func testAgentReplyNearBottomAutoScrolls() throws {
        // Relaunch forcing interval=4 so the agent always replies after exactly 4 messages.
        app.terminate()
        app.launchArguments = ["--uitesting-reset", "--uitesting-reply-every-4"]
        app.launch()

        // Hotel chat, send 4 messages, stay at bottom — agent reply should auto-scroll (no toast)
        let hotelChat = app.staticTexts["Hotel Reservation Help"]
        XCTAssertTrue(hotelChat.waitForExistence(timeout: 15))
        hotelChat.tap()

        XCTAssertTrue(app.staticTexts["I need to find a hotel in Bangalore for 3 nights."].waitForExistence(timeout: 5))

        let messageInput = app.textViews["messageInput"]
        XCTAssertTrue(messageInput.waitForExistence(timeout: 3))
        for i in 1...4 {
            messageInput.tap()
            messageInput.typeText("msg \(i)")
            app.buttons["sendButton"].tap()
            _ = app.staticTexts["msg \(i)"].waitForExistence(timeout: 3)
        }

        // Stay at bottom — wait for agent reply (2–3s)
        sleep(4)

        // Toast should NOT appear since we were near bottom
        XCTAssertFalse(app.buttons["newMessageToastButton"].exists, "Toast should not appear when near bottom")
    }

    // MARK: - Draft

    @MainActor
    func testDraftPersistsAcrossNavigation() throws {
        // Create new chat and type a draft without sending
        app.buttons["newChatButton"].tap()
        XCTAssertTrue(app.staticTexts["No Messages"].waitForExistence(timeout: 5))

        let messageInput = app.textViews["messageInput"]
        XCTAssertTrue(messageInput.waitForExistence(timeout: 3))
        messageInput.tap()
        messageInput.typeText("My unsent draft")

        // Wait for debounce to persist (300ms)
        sleep(1)

        // Go back — chat row shows "Draft: <text>" when lastMessage is empty
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Draft: My unsent draft"].waitForExistence(timeout: 3))

        // Re-enter the chat — draft should be restored in the input
        app.staticTexts["Draft: My unsent draft"].tap()
        let restoredInput = app.textViews["messageInput"]
        XCTAssertTrue(restoredInput.waitForExistence(timeout: 3))
        let value = restoredInput.value as? String ?? ""
        XCTAssertEqual(value, "My unsent draft")
    }

    @MainActor
    func testDraftPersistsAfterAppRelaunch() throws {
        // Create a new chat and type a draft without sending (no auto-title, title stays "New Chat")
        app.buttons["newChatButton"].tap()
        XCTAssertTrue(app.staticTexts["No Messages"].waitForExistence(timeout: 5))

        let messageInput = app.textViews["messageInput"]
        XCTAssertTrue(messageInput.waitForExistence(timeout: 3))
        messageInput.tap()
        messageInput.typeText("Relaunch draft")

        // Wait for debounce + DB write
        sleep(1)

        // Go back so cleanUpIfEmpty is called — but draft is non-empty so chat survives
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Draft: Relaunch draft"].waitForExistence(timeout: 3))

        // Terminate and relaunch without reset (preserves DB)
        app.terminate()
        app.launchArguments = []
        app.launch()

        // Chat row should still show the draft preview after relaunch
        XCTAssertTrue(app.staticTexts["Draft: Relaunch draft"].waitForExistence(timeout: 15))
        app.staticTexts["Draft: Relaunch draft"].tap()

        // Draft should be restored in the input field
        let restoredInput = app.textViews["messageInput"]
        XCTAssertTrue(restoredInput.waitForExistence(timeout: 3))
        let value = restoredInput.value as? String ?? ""
        XCTAssertEqual(value, "Relaunch draft")
    }

    // MARK: - Navigate Back

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

// MARK: - XCUIElement helpers

private extension XCUIElement {
    /// Clears any existing text then types the given string into the element.
    func clearAndEnterText(_ text: String) {
        tap()
        // Triple-tap selects all text in a text field
        tap(withNumberOfTaps: 3, numberOfTouches: 1)
        typeText(text)
    }
}
