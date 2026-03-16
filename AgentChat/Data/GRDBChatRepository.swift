import Foundation
import GRDB

final class GRDBChatRepository: ChatRepositoryProtocol, @unchecked Sendable {
    private let appDatabase: AppDatabase

    init(appDatabase: AppDatabase) {
        self.appDatabase = appDatabase
    }

    func fetchAll() async throws -> [Chat] {
        let records = try await appDatabase.dbQueue.read { db in
            try ChatRecord
                .order(Column("lastMessageTimestamp").desc)
                .fetchAll(db)
        }
        return records.map { $0.toChat() }
    }

    func fetch(id: String) async throws -> Chat? {
        let record = try await appDatabase.dbQueue.read { db in
            try ChatRecord.fetchOne(db, key: id)
        }
        return record?.toChat()
    }

    func create(_ chat: Chat) async throws {
        do {
            try await appDatabase.dbQueue.write { db in
                let record = ChatRecord.from(chat)
                try record.insert(db)
            }
        } catch let error as ChatError {
            throw error
        } catch {
            throw ChatError.createFailed(underlying: error)
        }
    }

    func update(_ chat: Chat) async throws {
        do {
            try await appDatabase.dbQueue.write { db in
                guard try ChatRecord.fetchOne(db, key: chat.id) != nil else {
                    throw ChatError.notFound
                }
                let record = ChatRecord.from(chat)
                try record.update(db)
            }
        } catch let error as ChatError {
            throw error
        } catch {
            throw ChatError.updateFailed(underlying: error)
        }
    }

    func updateTitle(id: String, title: String) async throws {
        do {
            try await appDatabase.dbQueue.write { db in
                guard try ChatRecord.fetchOne(db, key: id) != nil else {
                    throw ChatError.notFound
                }
                try db.execute(
                    sql: "UPDATE chats SET title = ?, updatedAt = ? WHERE id = ?",
                    arguments: [title, Int64(Date().timeIntervalSince1970 * 1000), id]
                )
            }
        } catch let error as ChatError {
            throw error
        } catch {
            throw ChatError.updateFailed(underlying: error)
        }
    }

    func updateDraft(id: String, draftText: String) async throws {
        do {
            try await appDatabase.dbQueue.write { db in
                guard try ChatRecord.fetchOne(db, key: id) != nil else {
                    throw ChatError.notFound
                }
                try db.execute(
                    sql: "UPDATE chats SET draftText = ? WHERE id = ?",
                    arguments: [draftText, id]
                )
            }
        } catch let error as ChatError {
            throw error
        } catch {
            throw ChatError.updateFailed(underlying: error)
        }
    }

    func delete(id: String) async throws {
        do {
            try await appDatabase.dbQueue.write { db in
                guard try ChatRecord.fetchOne(db, key: id) != nil else {
                    throw ChatError.notFound
                }
                try ChatRecord.deleteOne(db, key: id)
            }
        } catch let error as ChatError {
            throw error
        } catch {
            throw ChatError.deleteFailed(underlying: error)
        }
    }

    func chatStream() -> AsyncStream<[Chat]> {
        let observation = ValueObservation.tracking { db in
            try ChatRecord
                .order(Column("lastMessageTimestamp").desc)
                .fetchAll(db)
        }
        return AsyncStream { continuation in
            let cancellable = observation.start(
                in: appDatabase.dbQueue,
                scheduling: .async(onQueue: .main),
                onError: { _ in continuation.finish() },
                onChange: { records in
                    continuation.yield(records.map { $0.toChat() })
                }
            )
            continuation.onTermination = { _ in cancellable.cancel() }
        }
    }
}
