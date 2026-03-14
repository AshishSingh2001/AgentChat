import Foundation

struct SendAttachmentMessageUseCase {
    let fileStorageService: FileStorageService
    let sendMessageUseCase: SendMessageUseCase

    func execute(
        attachment: PendingAttachment,
        text: String,
        chat: Chat,
        isFirstMessage: Bool
    ) async throws -> (message: Message, updatedChat: Chat) {
        let filename = UUID().uuidString + ".jpg"
        let savedPath = try fileStorageService.save(data: attachment.data, filename: filename)

        let thumbnailData = try? fileStorageService.generateThumbnail(from: attachment.data, maxWidth: 150)
        var thumbnailPath: String? = nil
        if let thumbData = thumbnailData {
            thumbnailPath = try? fileStorageService.save(data: thumbData, filename: "thumb_" + filename)
        }

        let fileAttachment = FileAttachment(
            path: savedPath,
            fileSize: Int64(attachment.data.count),
            thumbnailPath: thumbnailPath
        )

        return try await sendMessageUseCase.execute(
            text: text,
            file: fileAttachment,
            chat: chat,
            isFirstMessage: isFirstMessage
        )
    }
}
