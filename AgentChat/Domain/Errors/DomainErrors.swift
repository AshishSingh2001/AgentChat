import Foundation

enum ChatError: Error, LocalizedError, Equatable, Sendable {
    case notFound
    case createFailed(underlying: Error?)
    case updateFailed(underlying: Error?)
    case deleteFailed(underlying: Error?)

    var errorDescription: String? {
        switch self {
        case .notFound:        return "Chat not found"
        case .createFailed:    return "Failed to create chat"
        case .updateFailed:    return "Failed to update chat"
        case .deleteFailed:    return "Failed to delete chat"
        }
    }

    static func == (lhs: ChatError, rhs: ChatError) -> Bool {
        switch (lhs, rhs) {
        case (.notFound, .notFound):                     return true
        case (.createFailed, .createFailed):             return true
        case (.updateFailed, .updateFailed):             return true
        case (.deleteFailed, .deleteFailed):             return true
        default:                                         return false
        }
    }
}

enum MessageError: Error, LocalizedError, Equatable, Sendable {
    case notFound
    case sendFailed(underlying: Error?)
    case deleteFailed(underlying: Error?)

    var errorDescription: String? {
        switch self {
        case .notFound:      return "Message not found"
        case .sendFailed:    return "Failed to send message"
        case .deleteFailed:  return "Failed to delete message"
        }
    }

    static func == (lhs: MessageError, rhs: MessageError) -> Bool {
        switch (lhs, rhs) {
        case (.notFound, .notFound):             return true
        case (.sendFailed, .sendFailed):         return true
        case (.deleteFailed, .deleteFailed):     return true
        default:                                 return false
        }
    }
}

enum FileStorageError: Error, LocalizedError, Equatable, Sendable {
    case saveFailed(underlying: Error)
    case loadFailed(underlying: Error)
    case thumbnailGenerationFailed
    case invalidImageData

    var errorDescription: String? {
        switch self {
        case .saveFailed:                  return "Failed to save file"
        case .loadFailed:                  return "Failed to load file"
        case .thumbnailGenerationFailed:   return "Failed to generate thumbnail"
        case .invalidImageData:            return "Invalid image data"
        }
    }

    static func == (lhs: FileStorageError, rhs: FileStorageError) -> Bool {
        switch (lhs, rhs) {
        case (.saveFailed, .saveFailed):                             return true
        case (.loadFailed, .loadFailed):                             return true
        case (.thumbnailGenerationFailed, .thumbnailGenerationFailed): return true
        case (.invalidImageData, .invalidImageData):                 return true
        default:                                                     return false
        }
    }
}

enum AgentError: Error, LocalizedError, Equatable, Sendable {
    case replyFailed(underlying: Error?)
    case serviceUnavailable

    var errorDescription: String? {
        switch self {
        case .replyFailed:          return "Failed to get agent response"
        case .serviceUnavailable:   return "Agent service is unavailable"
        }
    }

    static func == (lhs: AgentError, rhs: AgentError) -> Bool {
        switch (lhs, rhs) {
        case (.replyFailed, .replyFailed):                   return true
        case (.serviceUnavailable, .serviceUnavailable):     return true
        default:                                             return false
        }
    }
}
