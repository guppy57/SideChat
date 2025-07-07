import Foundation
import SQLite

// MARK: - Database Migrator

/// DatabaseMigrator handles database schema versioning and migrations
/// Provides a robust system for evolving the database schema over time

@MainActor
class DatabaseMigrator: ObservableObject {
    static let shared = DatabaseMigrator()
    
    private let db: Connection?
    private let currentSchemaVersion = DatabaseSchema.currentVersion
    
    // MARK: - Migration Registry
    
    private let migrations: [Migration] = [
        // Version 1 is the initial schema - no migration needed
        // Future migrations would be added here like:
        // Migration(fromVersion: 1, toVersion: 2, migrationBlock: migrateV1ToV2),
        // Migration(fromVersion: 2, toVersion: 3, migrationBlock: migrateV2ToV3),
    ]
    
    private init() {
        self.db = nil // Will be set by DatabaseManager
    }
    
    // MARK: - Public Methods
    
    func migrateIfNeeded(db: Connection) async throws {
        let currentVersion = try getCurrentSchemaVersion(db: db)
        
        if currentVersion < currentSchemaVersion {
            try await performMigration(
                db: db,
                fromVersion: currentVersion,
                toVersion: currentSchemaVersion
            )
        }
    }
    
    func getCurrentSchemaVersion(db: Connection) throws -> Int {
        // Check if migration info table exists
        let tableExists = try db.scalar(
            "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='migration_info'"
        ) as! Int64 > 0
        
        if !tableExists {
            // Create migration info table
            try createMigrationInfoTable(db: db)
            return 0 // Fresh database
        }
        
        // Get current version
        let version = try db.scalar(
            "SELECT MAX(version) FROM migration_info WHERE status = 'completed'"
        ) as? Int64 ?? 0
        
        return Int(version)
    }
    
    // MARK: - Migration System
    
    private func performMigration(
        db: Connection,
        fromVersion: Int,
        toVersion: Int
    ) async throws {
        print("Migrating database from version \(fromVersion) to \(toVersion)")
        
        // Create backup before migration
        let backupPath = try await createBackup(db: db, version: fromVersion)
        
        do {
            // Begin transaction
            try db.transaction {
                // If migrating from version 0, just create the initial schema
                if fromVersion == 0 {
                    try DatabaseSchema.createTables(db: db)
                    try recordMigration(
                        db: db,
                        version: 1,
                        description: "Initial schema creation"
                    )
                } else {
                    // Apply migrations sequentially
                    for version in (fromVersion + 1)...toVersion {
                        if let migration = findMigration(toVersion: version) {
                            try migration.migrationBlock(db)
                            try recordMigration(
                                db: db,
                                version: version,
                                description: migration.description
                            )
                        }
                    }
                }
            }
            
            print("Migration completed successfully")
            
            // Clean up old backups (keep last 5)
            try await cleanupOldBackups()
            
        } catch {
            print("Migration failed: \(error)")
            
            // Attempt to restore from backup
            if FileManager.default.fileExists(atPath: backupPath) {
                print("Attempting to restore from backup...")
                throw DatabaseMigrationError.migrationFailed(
                    reason: error.localizedDescription,
                    backupPath: backupPath
                )
            }
            
            throw error
        }
    }
    
    private func findMigration(toVersion: Int) -> Migration? {
        return migrations.first { $0.toVersion == toVersion }
    }
    
    // MARK: - Migration Info Table
    
    private func createMigrationInfoTable(db: Connection) throws {
        try db.execute("""
            CREATE TABLE IF NOT EXISTS migration_info (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                version INTEGER NOT NULL,
                description TEXT,
                applied_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                status TEXT NOT NULL DEFAULT 'completed',
                error_message TEXT
            )
        """)
        
        // Create index on version
        try db.execute("""
            CREATE INDEX IF NOT EXISTS idx_migration_info_version 
            ON migration_info(version)
        """)
    }
    
    private func recordMigration(
        db: Connection,
        version: Int,
        description: String
    ) throws {
        try db.run("""
            INSERT INTO migration_info (version, description, status)
            VALUES (?, ?, 'completed')
        """, version, description)
    }
    
    // MARK: - Backup Management
    
    func createBackup(db: Connection, version: Int) async throws -> String {
        let backupDir = getBackupDirectory()
        
        // Create backup directory if needed
        try FileManager.default.createDirectory(
            at: backupDir,
            withIntermediateDirectories: true
        )
        
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let backupName = "sidechat_v\(version)_\(timestamp).db"
        let backupPath = backupDir.appendingPathComponent(backupName).path
        
        // Use SQLite backup API
        _ = try db.backup(usingConnection: Connection(backupPath))
        
        print("Created backup at: \(backupPath)")
        return backupPath
    }
    
    private func getBackupDirectory() -> URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        
        return appSupport
            .appendingPathComponent("SideChat")
            .appendingPathComponent("DatabaseBackups")
    }
    
    func cleanupOldBackups(keepCount: Int = 5) async throws {
        let backupDir = getBackupDirectory()
        
        guard FileManager.default.fileExists(atPath: backupDir.path) else {
            return
        }
        
        let backups = try FileManager.default.contentsOfDirectory(
            at: backupDir,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        )
        
        // Sort by creation date (newest first)
        let sortedBackups = try backups.sorted { url1, url2 in
            let date1 = try url1.resourceValues(forKeys: [.creationDateKey]).creationDate!
            let date2 = try url2.resourceValues(forKeys: [.creationDateKey]).creationDate!
            return date1 > date2
        }
        
        // Remove old backups
        if sortedBackups.count > keepCount {
            for backup in sortedBackups[keepCount...] {
                try FileManager.default.removeItem(at: backup)
                print("Removed old backup: \(backup.lastPathComponent)")
            }
        }
    }
    
    func restoreFromBackup(backupPath: String) async throws {
        guard FileManager.default.fileExists(atPath: backupPath) else {
            throw DatabaseMigrationError.backupNotFound(path: backupPath)
        }
        
        // Implementation would restore the database from backup
        // This is a placeholder for the actual restoration logic
        print("Restoring database from: \(backupPath)")
    }
    
    // MARK: - Schema Validation
    
    func validateSchema(db: Connection) async throws -> SchemaValidationResult {
        var issues: [String] = []
        
        // Check if all required tables exist
        let requiredTables = ["chats", "messages", "settings", "chat_stats", "migration_info"]
        
        for table in requiredTables {
            let exists = try db.scalar(
                "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name=?"
            , table) as! Int64 > 0
            
            if !exists {
                issues.append("Missing required table: \(table)")
            }
        }
        
        // Check if all required indexes exist
        let requiredIndexes = [
            "idx_chats_updated_at",
            "idx_messages_chat_id",
            "idx_messages_timestamp"
        ]
        
        for index in requiredIndexes {
            let exists = try db.scalar(
                "SELECT COUNT(*) FROM sqlite_master WHERE type='index' AND name=?"
            , index) as! Int64 > 0
            
            if !exists {
                issues.append("Missing required index: \(index)")
            }
        }
        
        return SchemaValidationResult(
            isValid: issues.isEmpty,
            version: try getCurrentSchemaVersion(db: db),
            issues: issues
        )
    }
}

// MARK: - Migration Definition

struct Migration {
    let fromVersion: Int
    let toVersion: Int
    let description: String
    let migrationBlock: (Connection) throws -> Void
    
    init(
        fromVersion: Int,
        toVersion: Int,
        description: String = "",
        migrationBlock: @escaping (Connection) throws -> Void
    ) {
        self.fromVersion = fromVersion
        self.toVersion = toVersion
        self.description = description.isEmpty ? "Migration from v\(fromVersion) to v\(toVersion)" : description
        self.migrationBlock = migrationBlock
    }
}

// MARK: - Database Migration Error

enum DatabaseMigrationError: LocalizedError {
    case migrationFailed(reason: String, backupPath: String)
    case backupNotFound(path: String)
    case invalidSchemaVersion(current: Int, target: Int)
    case validationFailed(issues: [String])
    
    var errorDescription: String? {
        switch self {
        case .migrationFailed(let reason, let backupPath):
            return "Migration failed: \(reason). Backup available at: \(backupPath)"
        case .backupNotFound(let path):
            return "Backup not found at: \(path)"
        case .invalidSchemaVersion(let current, let target):
            return "Invalid schema version. Current: \(current), Target: \(target)"
        case .validationFailed(let issues):
            return "Schema validation failed: \(issues.joined(separator: ", "))"
        }
    }
}

// MARK: - Schema Validation Result

struct SchemaValidationResult {
    let isValid: Bool
    let version: Int
    let issues: [String]
}

// MARK: - Example Migrations

// These are examples of how to define migrations for future schema changes

extension DatabaseMigrator {
    
    // Example: Migration from v1 to v2
    private static func migrateV1ToV2(db: Connection) throws {
        // Add new column to chats table
        try db.execute("""
            ALTER TABLE chats 
            ADD COLUMN tags TEXT
        """)
        
        // Create new tags table
        try db.execute("""
            CREATE TABLE IF NOT EXISTS tags (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                color TEXT,
                created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
            )
        """)
        
        // Create junction table for many-to-many relationship
        try db.execute("""
            CREATE TABLE IF NOT EXISTS chat_tags (
                chat_id TEXT NOT NULL,
                tag_id TEXT NOT NULL,
                PRIMARY KEY (chat_id, tag_id),
                FOREIGN KEY (chat_id) REFERENCES chats(id) ON DELETE CASCADE,
                FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
            )
        """)
        
        // Add indexes
        try db.execute("CREATE INDEX idx_tags_name ON tags(name)")
        try db.execute("CREATE INDEX idx_chat_tags_chat_id ON chat_tags(chat_id)")
        try db.execute("CREATE INDEX idx_chat_tags_tag_id ON chat_tags(tag_id)")
    }
    
    // Example: Migration from v2 to v3
    private static func migrateV2ToV3(db: Connection) throws {
        // Add support for message reactions
        try db.execute("""
            CREATE TABLE IF NOT EXISTS message_reactions (
                id TEXT PRIMARY KEY,
                message_id TEXT NOT NULL,
                emoji TEXT NOT NULL,
                created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (message_id) REFERENCES messages(id) ON DELETE CASCADE
            )
        """)
        
        // Add index
        try db.execute("CREATE INDEX idx_message_reactions_message_id ON message_reactions(message_id)")
        
        // Update messages table to include reaction count
        try db.execute("""
            ALTER TABLE messages 
            ADD COLUMN reaction_count INTEGER DEFAULT 0
        """)
    }
}

// MARK: - Database Migration Manager UI Support

extension DatabaseMigrator {
    
    struct MigrationStatus: Identifiable {
        let id = UUID()
        let version: Int
        let description: String
        let appliedAt: Date
        let status: String
        let errorMessage: String?
    }
    
    func getMigrationHistory(db: Connection) async throws -> [MigrationStatus] {
        var history: [MigrationStatus] = []
        
        let query = """
            SELECT version, description, applied_at, status, error_message
            FROM migration_info
            ORDER BY version DESC
        """
        
        for row in try db.prepare(query) {
            history.append(MigrationStatus(
                version: Int(row[0] as! Int64),
                description: row[1] as! String,
                appliedAt: ISO8601DateFormatter().date(from: row[2] as! String) ?? Date(),
                status: row[3] as! String,
                errorMessage: row[4] as? String
            ))
        }
        
        return history
    }
    
    func getBackupList() async throws -> [(url: URL, size: Int64, date: Date)] {
        let backupDir = getBackupDirectory()
        
        guard FileManager.default.fileExists(atPath: backupDir.path) else {
            return []
        }
        
        let backups = try FileManager.default.contentsOfDirectory(
            at: backupDir,
            includingPropertiesForKeys: [.fileSizeKey, .creationDateKey],
            options: .skipsHiddenFiles
        )
        
        return try backups.map { url in
            let values = try url.resourceValues(forKeys: [.fileSizeKey, .creationDateKey])
            return (
                url: url,
                size: Int64(values.fileSize ?? 0),
                date: values.creationDate ?? Date()
            )
        }.sorted { $0.date > $1.date }
    }
}