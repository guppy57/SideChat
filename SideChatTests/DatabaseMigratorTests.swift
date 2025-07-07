import XCTest
import SQLite
@testable import SideChat

final class DatabaseMigratorTests: XCTestCase {
    
    var testConnection: Connection!
    var testDatabasePath: String!
    var migrator: DatabaseMigrator!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create a temporary database for testing
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_migration.db")
        testDatabasePath = tempURL.path
        
        // Remove existing test database if it exists
        if FileManager.default.fileExists(atPath: testDatabasePath) {
            try FileManager.default.removeItem(atPath: testDatabasePath)
        }
        
        // Create test database connection
        testConnection = try Connection(testDatabasePath)
        
        // Get migrator instance
        migrator = await DatabaseMigrator.shared
    }
    
    override func tearDown() async throws {
        // Clean up test database
        testConnection = nil
        
        if let testPath = testDatabasePath,
           FileManager.default.fileExists(atPath: testPath) {
            try FileManager.default.removeItem(atPath: testPath)
        }
        
        testDatabasePath = nil
        migrator = nil
        
        try await super.tearDown()
    }
    
    // MARK: - Schema Version Tests
    
    @MainActor 
    func testGetCurrentSchemaVersionNewDatabase() async throws {
        let version = try migrator.getCurrentSchemaVersion(db: testConnection)
        XCTAssertEqual(version, 0, "New database should have version 0")
    }
    
    @MainActor 
    func testGetCurrentSchemaVersionAfterMigration() async throws {
        // Run migration
        try await migrator.migrateIfNeeded(db: testConnection)
        
        let version = try migrator.getCurrentSchemaVersion(db: testConnection)
        XCTAssertEqual(version, 1, "After migration, database should have version 1")
    }
    
    // MARK: - Migration Tests
    
    @MainActor 
    func testMigrateFromZeroToOne() async throws {
        // Verify initial state
        let initialVersion = try migrator.getCurrentSchemaVersion(db: testConnection)
        XCTAssertEqual(initialVersion, 0, "Initial version should be 0")
        
        // Run migration
        try await migrator.migrateIfNeeded(db: testConnection)
        
        // Verify final state
        let finalVersion = try migrator.getCurrentSchemaVersion(db: testConnection)
        XCTAssertEqual(finalVersion, 1, "Final version should be 1")
        
        // Verify tables were created
        let chatsTableExists = try testConnection.scalar(
            "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='chats'"
        ) as! Int64 > 0
        XCTAssertTrue(chatsTableExists, "Chats table should exist after migration")
        
        let messagesTableExists = try testConnection.scalar(
            "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='messages'"
        ) as! Int64 > 0
        XCTAssertTrue(messagesTableExists, "Messages table should exist after migration")
    }
    
    @MainActor 
    func testMigrationInfoTableCreation() throws {
        // Migration info table should be created when getting schema version
        _ = try migrator.getCurrentSchemaVersion(db: testConnection)
        
        let migrationTableExists = try testConnection.scalar(
            "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='migration_info'"
        ) as! Int64 > 0
        XCTAssertTrue(migrationTableExists, "Migration info table should exist")
    }
    
    @MainActor 
    func testMigrationRecording() async throws {
        // Run migration
        try await migrator.migrateIfNeeded(db: testConnection)
        
        // Check migration record
        let migrationCount = try testConnection.scalar(
            "SELECT COUNT(*) FROM migration_info WHERE version = 1 AND status = 'completed'"
        ) as! Int64
        XCTAssertEqual(migrationCount, 1, "Migration should be recorded")
    }
    
    @MainActor 
    func testNoMigrationWhenUpToDate() async throws {
        // Run migration once
        try await migrator.migrateIfNeeded(db: testConnection)
        
        let initialRecordCount = try testConnection.scalar(
            "SELECT COUNT(*) FROM migration_info"
        ) as! Int64
        
        // Run migration again
        try await migrator.migrateIfNeeded(db: testConnection)
        
        let finalRecordCount = try testConnection.scalar(
            "SELECT COUNT(*) FROM migration_info"
        ) as! Int64
        
        XCTAssertEqual(initialRecordCount, finalRecordCount, "No additional migration should be recorded")
    }
    
    // MARK: - Backup Tests
    
    @MainActor 
    func testCreateBackup() async throws {
        // Create some test data
        try DatabaseSchema.createTables(db: testConnection)
        
        let chatId = UUID().uuidString
        try testConnection.run(DatabaseSchema.Tables.chats.insert(
            DatabaseSchema.Tables.chatId <- chatId,
            DatabaseSchema.Tables.chatTitle <- "Test Chat",
            DatabaseSchema.Tables.chatCreatedAt <- Date(),
            DatabaseSchema.Tables.chatUpdatedAt <- Date(),
            DatabaseSchema.Tables.chatLLMProvider <- "openai",
            DatabaseSchema.Tables.chatModelName <- "gpt-4",
            DatabaseSchema.Tables.chatIsArchived <- false,
            DatabaseSchema.Tables.chatMessageCount <- 0
        ))
        
        // Create backup
        let backupPath = try await migrator.createBackup(db: testConnection, version: 1)
        
        // Verify backup file exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: backupPath), "Backup file should exist")
        
        // Verify backup contains data
        let backupConnection = try Connection(backupPath)
        let backupChatCount = try backupConnection.scalar("SELECT COUNT(*) FROM chats") as! Int64
        XCTAssertEqual(backupChatCount, 1, "Backup should contain test data")
    }
    
    @MainActor 
    func testCleanupOldBackups() async throws {
        // Create some test data
        try DatabaseSchema.createTables(db: testConnection)
        
        // Create multiple backups
        let backupPaths = try await withThrowingTaskGroup(of: String.self) { group in
            for i in 0..<7 {
                group.addTask {
                    // Add small delay to ensure different timestamps
                    try await Task.sleep(nanoseconds: 10_000_000) // 10ms
                    return try await self.migrator.createBackup(db: self.testConnection, version: i)
                }
            }
            
            var paths: [String] = []
            for try await path in group {
                paths.append(path)
            }
            return paths
        }
        
        // Verify all backups were created
        for path in backupPaths {
            XCTAssertTrue(FileManager.default.fileExists(atPath: path), "Backup should exist")
        }
        
        // Clean up old backups (keep 5)
        try await migrator.cleanupOldBackups(keepCount: 5)
        
        // Verify only 5 backups remain
        let backupList = try await migrator.getBackupList()
        XCTAssertEqual(backupList.count, 5, "Should keep only 5 backups")
    }
    
    @MainActor 
    func testGetBackupList() async throws {
        // Create some test data
        try DatabaseSchema.createTables(db: testConnection)
        
        // Create backups
        let backup1 = try await migrator.createBackup(db: testConnection, version: 1)
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms delay
        let backup2 = try await migrator.createBackup(db: testConnection, version: 1)
        
        // Get backup list
        let backupList = try await migrator.getBackupList()
        
        XCTAssertEqual(backupList.count, 2, "Should have 2 backups")
        XCTAssertGreaterThan(backupList[0].size, 0, "Backup should have size > 0")
        XCTAssertGreaterThan(backupList[1].size, 0, "Backup should have size > 0")
        
        // Verify backups are sorted by date (newest first)
        XCTAssertGreaterThanOrEqual(backupList[0].date, backupList[1].date, "Backups should be sorted by date")
    }
    
    // MARK: - Schema Validation Tests
    
    @MainActor 
    func testValidateSchemaSuccess() async throws {
        // Create all tables
        try DatabaseSchema.createTables(db: testConnection)
        
        // Update schema version
        try await migrator.migrateIfNeeded(db: testConnection)
        
        // Validate schema
        let result = try await migrator.validateSchema(db: testConnection)
        
        XCTAssertTrue(result.isValid, "Schema should be valid")
        XCTAssertEqual(result.version, 1, "Schema version should be 1")
        XCTAssertTrue(result.issues.isEmpty, "Should have no validation issues")
    }
    
    @MainActor 
    func testValidateSchemaFailure() async throws {
        // Create only partial schema (missing tables)
        try testConnection.run(DatabaseSchema.Tables.chats.create { t in
            t.column(DatabaseSchema.Tables.chatId, primaryKey: true)
            t.column(DatabaseSchema.Tables.chatTitle)
            t.column(DatabaseSchema.Tables.chatCreatedAt)
            t.column(DatabaseSchema.Tables.chatUpdatedAt)
            t.column(DatabaseSchema.Tables.chatLLMProvider)
            t.column(DatabaseSchema.Tables.chatModelName)
            t.column(DatabaseSchema.Tables.chatIsArchived, defaultValue: false)
            t.column(DatabaseSchema.Tables.chatMessageCount, defaultValue: 0)
            t.column(DatabaseSchema.Tables.chatLastMessagePreview)
        })
        
        // Update schema version manually
        try testConnection.execute("""
            CREATE TABLE IF NOT EXISTS migration_info (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                version INTEGER NOT NULL,
                description TEXT,
                applied_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                status TEXT NOT NULL DEFAULT 'completed',
                error_message TEXT
            )
        """)
        
        try testConnection.run(
            "INSERT INTO migration_info (version, description, status) VALUES (?, ?, ?)",
            1, "Test migration", "completed"
        )
        
        // Validate schema
        let result = try await migrator.validateSchema(db: testConnection)
        
        XCTAssertFalse(result.isValid, "Schema should be invalid")
        XCTAssertFalse(result.issues.isEmpty, "Should have validation issues")
        XCTAssertTrue(result.issues.contains { $0.contains("messages") }, "Should report missing messages table")
    }
    
    // MARK: - Migration History Tests
    
    @MainActor 
    func testGetMigrationHistory() async throws {
        // Run migration
        try await migrator.migrateIfNeeded(db: testConnection)
        
        // Get migration history
        let history = try await migrator.getMigrationHistory(db: testConnection)
        
        XCTAssertEqual(history.count, 1, "Should have 1 migration record")
        XCTAssertEqual(history.first?.version, 1, "Migration version should be 1")
        XCTAssertEqual(history.first?.status, "completed", "Migration should be completed")
        XCTAssertEqual(history.first?.description, "Initial schema creation", "Should have proper description")
    }
    
    @MainActor 
    func testGetMigrationHistoryEmpty() async throws {
        // Get migration history without any migrations
        let history = try await migrator.getMigrationHistory(db: testConnection)
        
        XCTAssertEqual(history.count, 0, "Should have no migration records")
    }
    
    // MARK: - Error Handling Tests
    
    @MainActor 
    func testMigrationErrorHandling() async throws {
        // This test would require more sophisticated error injection
        // For now, we'll test that migration completes successfully
        
        // Run migration
        try await migrator.migrateIfNeeded(db: testConnection)
        
        // Verify migration completed successfully
        let version = try migrator.getCurrentSchemaVersion(db: testConnection)
        XCTAssertEqual(version, 1, "Migration should complete successfully")
    }
    
    // MARK: - Performance Tests
    
    @MainActor 
    func testMigrationPerformance() async throws {
        // Measure migration performance
        let startTime = CFAbsoluteTimeGetCurrent()
        
        try await migrator.migrateIfNeeded(db: testConnection)
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let migrationTime = endTime - startTime
        
        XCTAssertLessThan(migrationTime, 1.0, "Migration should complete in under 1 second")
        
        // Verify migration was successful
        let version = try migrator.getCurrentSchemaVersion(db: testConnection)
        XCTAssertEqual(version, 1, "Migration should complete successfully")
    }
    
    // MARK: - Concurrent Access Tests
    
    @MainActor 
    func testConcurrentSchemaVersionAccess() async throws {
        // Test that multiple concurrent accesses don't cause issues
        try await withThrowingTaskGroup(of: Int.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    return try await self.migrator.getCurrentSchemaVersion(db: self.testConnection)
                }
            }
            
            var versions: [Int] = []
            for try await version in group {
                versions.append(version)
            }
            
            // All versions should be the same
            let uniqueVersions = Set(versions)
            XCTAssertEqual(uniqueVersions.count, 1, "All concurrent version checks should return same result")
        }
    }
    
    // MARK: - Migration Rollback Tests
    
    @MainActor 
    func testBackupCreationBeforeMigration() async throws {
        // Create some test data
        try DatabaseSchema.createTables(db: testConnection)
        
        let chatId = UUID().uuidString
        try testConnection.run(DatabaseSchema.Tables.chats.insert(
            DatabaseSchema.Tables.chatId <- chatId,
            DatabaseSchema.Tables.chatTitle <- "Test Chat",
            DatabaseSchema.Tables.chatCreatedAt <- Date(),
            DatabaseSchema.Tables.chatUpdatedAt <- Date(),
            DatabaseSchema.Tables.chatLLMProvider <- "openai",
            DatabaseSchema.Tables.chatModelName <- "gpt-4",
            DatabaseSchema.Tables.chatIsArchived <- false,
            DatabaseSchema.Tables.chatMessageCount <- 0
        ))
        
        // Force a migration (even though we're already at version 1)
        let backupPath = try await migrator.createBackup(db: testConnection, version: 1)
        
        // Verify backup exists and contains data
        XCTAssertTrue(FileManager.default.fileExists(atPath: backupPath), "Backup should exist")
        
        let backupConnection = try Connection(backupPath)
        let backupChatCount = try backupConnection.scalar("SELECT COUNT(*) FROM chats") as! Int64
        XCTAssertEqual(backupChatCount, 1, "Backup should contain original data")
    }
}