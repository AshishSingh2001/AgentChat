import Testing
import Foundation
@testable import AgentChat

struct DomainErrorsTests {

    // MARK: - ChatError

    @Test func chatErrorNotFoundDescription() {
        #expect(ChatError.notFound.localizedDescription == "Chat not found")
    }

    @Test func chatErrorCreateFailedDescription() {
        #expect(ChatError.createFailed(underlying: nil).localizedDescription == "Failed to create chat")
    }

    @Test func chatErrorUpdateFailedDescription() {
        #expect(ChatError.updateFailed(underlying: nil).localizedDescription == "Failed to update chat")
    }

    @Test func chatErrorDeleteFailedDescription() {
        #expect(ChatError.deleteFailed(underlying: nil).localizedDescription == "Failed to delete chat")
    }

    @Test func chatErrorEquality() {
        #expect(ChatError.notFound == ChatError.notFound)
        #expect(ChatError.createFailed(underlying: nil) == ChatError.createFailed(underlying: nil))
        #expect(ChatError.notFound != ChatError.createFailed(underlying: nil))
    }

    // MARK: - MessageError

    @Test func messageErrorNotFoundDescription() {
        #expect(MessageError.notFound.localizedDescription == "Message not found")
    }

    @Test func messageErrorSendFailedDescription() {
        #expect(MessageError.sendFailed(underlying: nil).localizedDescription == "Failed to send message")
    }

    @Test func messageErrorDeleteFailedDescription() {
        #expect(MessageError.deleteFailed(underlying: nil).localizedDescription == "Failed to delete message")
    }

    @Test func messageErrorEquality() {
        #expect(MessageError.notFound == MessageError.notFound)
        #expect(MessageError.sendFailed(underlying: nil) == MessageError.sendFailed(underlying: nil))
        #expect(MessageError.notFound != MessageError.sendFailed(underlying: nil))
    }

    // MARK: - FileStorageError

    @Test func fileStorageErrorSaveFailedDescription() {
        let underlying = NSError(domain: "test", code: 1)
        #expect(FileStorageError.saveFailed(underlying: underlying).localizedDescription == "Failed to save file")
    }

    @Test func fileStorageErrorLoadFailedDescription() {
        let underlying = NSError(domain: "test", code: 2)
        #expect(FileStorageError.loadFailed(underlying: underlying).localizedDescription == "Failed to load file")
    }

    @Test func fileStorageErrorThumbnailDescription() {
        #expect(FileStorageError.thumbnailGenerationFailed.localizedDescription == "Failed to generate thumbnail")
    }

    @Test func fileStorageErrorInvalidImageDataDescription() {
        #expect(FileStorageError.invalidImageData.localizedDescription == "Invalid image data")
    }

    // MARK: - SendMessageError

    @Test func sendMessageErrorEmptyDescription() {
        #expect(SendMessageError.emptyMessage.localizedDescription == "Message cannot be empty")
    }
}
