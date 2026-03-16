import Foundation
import GRDB

final class GRDBMessageRepository: MessageRepositoryProtocol, @unchecked Sendable {
    private let appDatabase: AppDatabase

    init(appDatabase: AppDatabase) {
        self.appDatabase = appDatabase
    }

    func fetchMessages(for chatId: String, before: Int64?, limit: Int) async throws -> [Message] {
        let records = try await appDatabase.dbQueue.read { db in
            if let cursor = before {
                return try MessageRecord
                    .filter(Column("chatId") == chatId && Column("timestamp") < cursor)
                    .order(Column("timestamp").desc)
                    .limit(limit)
                    .fetchAll(db)
            } else {
                return try MessageRecord
                    .filter(Column("chatId") == chatId)
                    .order(Column("timestamp").desc)
                    .limit(limit)
                    .fetchAll(db)
            }
        }
        return records.reversed().map { $0.toMessage() }
    }

    func insert(_ message: Message) async throws {
        do {
            try await appDatabase.dbQueue.write { db in
                let record = MessageRecord.from(message)
                try record.insert(db)
                // Update parent chat's lastMessage, lastMessageTimestamp, updatedAt
                if var chatRecord = try ChatRecord.fetchOne(db, key: message.chatId) {
                    chatRecord.lastMessage = message.text
                    chatRecord.lastMessageTimestamp = message.timestamp
                    chatRecord.updatedAt = message.timestamp
                    try chatRecord.update(db)
                }
                // If chat doesn't exist (orphan message), silently skip the update
            }
        } catch let error as MessageError {
            throw error
        } catch {
            throw MessageError.sendFailed(underlying: error)
        }
    }

    func deleteAll(for chatId: String) async throws {
        do {
            try await appDatabase.dbQueue.write { db in
                _ = try MessageRecord
                    .filter(Column("chatId") == chatId)
                    .deleteAll(db)
            }
        } catch let error as MessageError {
            throw error
        } catch {
            throw MessageError.deleteFailed(underlying: error)
        }
    }

    func newMessageStream(for chatId: String) -> AsyncStream<Message> {
        let observation = ValueObservation.tracking { db in
            try MessageRecord
                .filter(Column("chatId") == chatId)
                .order(Column("timestamp").asc)
                .fetchAll(db)
        }
        return AsyncStream { continuation in
            var isFirst = true
            var lastSeenTimestamp: Int64 = 0
            let cancellable = observation.start(
                in: appDatabase.dbQueue,
                scheduling: .async(onQueue: .main),
                onError: { _ in continuation.finish() },
                onChange: { records in
                    if isFirst {
                        // Seed: record current max timestamp, don't emit existing messages
                        isFirst = false
                        lastSeenTimestamp = records.map(\.timestamp).max() ?? 0
                    } else {
                        // Emit only new messages since last seen
                        let newRecords = records.filter { $0.timestamp > lastSeenTimestamp }
                        for record in newRecords {
                            continuation.yield(record.toMessage())
                            if record.timestamp > lastSeenTimestamp {
                                lastSeenTimestamp = record.timestamp
                            }
                        }
                    }
                }
            )
            continuation.onTermination = { _ in cancellable.cancel() }
        }
    }
}
