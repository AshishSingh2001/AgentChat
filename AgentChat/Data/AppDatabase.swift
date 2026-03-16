import Foundation
import GRDB

final class AppDatabase: Sendable {
    let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue) throws {
        self.dbQueue = dbQueue
        try Self.runMigrations(on: dbQueue)
    }

    static func onDisk() throws -> AppDatabase {
        let fm = FileManager.default
        let supportDir = try fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dbDir = supportDir.appendingPathComponent("AgentChat", isDirectory: true)
        try fm.createDirectory(at: dbDir, withIntermediateDirectories: true)
        let dbPath = dbDir.appendingPathComponent("agentchat.db").path
        let dbQueue = try DatabaseQueue(path: dbPath)
        return try AppDatabase(dbQueue: dbQueue)
    }

    static func inMemory() throws -> AppDatabase {
        let dbQueue = try DatabaseQueue()
        return try AppDatabase(dbQueue: dbQueue)
    }

    private static func runMigrations(on dbQueue: DatabaseQueue) throws {
        var migrator = DatabaseMigrator()
        #if DEBUG
        migrator.eraseDatabaseOnSchemaChange = true
        #endif

        migrator.registerMigration("v1_initial") { db in
            try db.create(table: "chats") { t in
                t.primaryKey("id", .text)
                t.column("title", .text).notNull()
                t.column("lastMessage", .text).notNull().defaults(to: "")
                t.column("lastMessageTimestamp", .integer).notNull().defaults(to: 0)
                t.column("createdAt", .integer).notNull()
                t.column("updatedAt", .integer).notNull()
                t.column("draftText", .text).notNull().defaults(to: "")
            }

            try db.create(table: "messages") { t in
                t.primaryKey("id", .text)
                t.column("chatId", .text).notNull().references("chats", onDelete: .cascade)
                t.column("text", .text).notNull().defaults(to: "")
                t.column("type", .text).notNull().defaults(to: "text")
                t.column("filePath", .text)
                t.column("fileSize", .integer)
                t.column("thumbnailPath", .text)
                t.column("sender", .text).notNull()
                t.column("timestamp", .integer).notNull()
            }

            try db.create(
                index: "messages_chatId_timestamp",
                on: "messages",
                columns: ["chatId", "timestamp"]
            )
        }

        try migrator.migrate(dbQueue)
    }
}
