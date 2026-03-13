import Testing
@testable import AgentChat

@MainActor
struct MessageTests {

    // MARK: - MessageType raw values

    @Test func messageTypeTextRawValue() {
        #expect(MessageType.text.rawValue == "text")
    }

    @Test func messageTypeFileRawValue() {
        #expect(MessageType.file.rawValue == "file")
    }

    // MARK: - Sender raw values

    @Test func senderUserRawValue() {
        #expect(Sender.user.rawValue == "user")
    }

    @Test func senderAgentRawValue() {
        #expect(Sender.agent.rawValue == "agent")
    }

    // MARK: - FileAttachment.formattedFileSize

    @Test func fileSizeFormatsAsBytes() {
        let attachment = FileAttachment(path: "img.jpg", fileSize: 512, thumbnailPath: nil)
        #expect(attachment.formattedFileSize == "512 bytes")
    }

    @Test func fileSizeFormatsAsKB() {
        let attachment = FileAttachment(path: "img.jpg", fileSize: 245_680, thumbnailPath: nil)
        #expect(attachment.formattedFileSize == "240 KB")
    }

    @Test func fileSizeFormatsAsMB() {
        let attachment = FileAttachment(path: "img.jpg", fileSize: 1_200_000, thumbnailPath: nil)
        #expect(attachment.formattedFileSize == "1.1 MB")
    }

    @Test func fileSizeFormatsAsGB() {
        let attachment = FileAttachment(path: "img.jpg", fileSize: 2_000_000_000, thumbnailPath: nil)
        #expect(attachment.formattedFileSize == "1.9 GB")
    }

    // MARK: - FileAttachment thumbnail

    @Test func thumbnailPathIsPresentWhenProvided() {
        let attachment = FileAttachment(path: "img.jpg", fileSize: 1_024, thumbnailPath: "thumb.jpg")
        #expect(attachment.thumbnailPath == "thumb.jpg")
    }

    @Test func thumbnailPathIsNilWhenAbsent() {
        let attachment = FileAttachment(path: "img.jpg", fileSize: 1_024, thumbnailPath: nil)
        #expect(attachment.thumbnailPath == nil)
    }

    // MARK: - Message construction

    @Test func textMessageHasNilFile() {
        let message = Message(
            id: "msg-001",
            chatId: "chat-001",
            text: "Hello",
            type: .text,
            file: nil,
            sender: .user,
            timestamp: 1_703_520_000_000
        )
        #expect(message.file == nil)
        #expect(message.type == .text)
        #expect(message.sender == .user)
    }

    @Test func fileMessageHasNonNilFile() {
        let attachment = FileAttachment(path: "img.jpg", fileSize: 1_024, thumbnailPath: nil)
        let message = Message(
            id: "msg-002",
            chatId: "chat-001",
            text: "",
            type: .file,
            file: attachment,
            sender: .agent,
            timestamp: 1_703_520_000_000
        )
        #expect(message.file != nil)
        #expect(message.type == .file)
        #expect(message.sender == .agent)
    }

    // MARK: - Equality (ID-based)

    @Test func messagesWithSameIDAreEqual() {
        let msg1 = Message(id: "m1", chatId: "c1", text: "A", type: .text, file: nil, sender: .user, timestamp: 0)
        let msg2 = Message(id: "m1", chatId: "c1", text: "B", type: .text, file: nil, sender: .agent, timestamp: 999)
        #expect(msg1 == msg2)
    }

    @Test func messagesWithDifferentIDsAreNotEqual() {
        let msg1 = Message(id: "m1", chatId: "c1", text: "A", type: .text, file: nil, sender: .user, timestamp: 0)
        let msg2 = Message(id: "m2", chatId: "c1", text: "A", type: .text, file: nil, sender: .user, timestamp: 0)
        #expect(msg1 != msg2)
    }

    // MARK: - Timestamp precision

    @Test func millisecondsStoredWithoutPrecisionLoss() {
        let timestamp: Int64 = 1_703_520_480_999
        let message = Message(id: "m1", chatId: "c1", text: "", type: .text, file: nil, sender: .user, timestamp: timestamp)
        #expect(message.timestamp == 1_703_520_480_999)
    }

    // MARK: - Sendable (compile-time)

    @Test func messageIsSendableAcrossActorBoundary() async {
        let message = Message(id: "m1", chatId: "c1", text: "hi", type: .text, file: nil, sender: .user, timestamp: 0)
        let captured = await Task.detached { message }.value
        #expect(captured.id == "m1")
    }
}
