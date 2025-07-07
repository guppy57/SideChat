import XCTest
import SQLite
import KeychainAccess
@testable import SideChat

final class DatabaseSecurityTests: XCTestCase {
    
    var testConnection: Connection!
    var testDatabasePath: String!
    var security: DatabaseSecurity!
    var testKeychain: Keychain!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create a temporary database for testing
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_security.db")
        testDatabasePath = tempURL.path
        
        // Remove existing test database if it exists
        if FileManager.default.fileExists(atPath: testDatabasePath) {
            try FileManager.default.removeItem(atPath: testDatabasePath)
        }
        
        // Create test database connection
        testConnection = try Connection(testDatabasePath)
        
        // Get security instance
        security = DatabaseSecurity.shared
        
        // Use test keychain service
        testKeychain = Keychain(service: "com.sidechat.database.test")
        
        // Clean up any existing test keys
        try? testKeychain.removeAll()
    }
    
    override func tearDown() async throws {
        // Clean up test database
        testConnection = nil
        
        if let testPath = testDatabasePath,
           FileManager.default.fileExists(atPath: testPath) {
            try FileManager.default.removeItem(atPath: testPath)
        }
        
        // Clean up test keychain
        try? testKeychain.removeAll()
        
        testDatabasePath = nil
        security = nil
        testKeychain = nil
        
        try await super.tearDown()
    }
    
    // MARK: - Encryption Key Management Tests
    
    func testGetOrCreateEncryptionKey() throws {
        // First call should create a new key
        let key1 = try security.getOrCreateEncryptionKey()
        XCTAssertFalse(key1.isEmpty, "Encryption key should not be empty")
        
        // Second call should return the same key
        let key2 = try security.getOrCreateEncryptionKey()
        XCTAssertEqual(key1, key2, "Should return the same key on subsequent calls")
    }
    
    func testRegenerateEncryptionKey() throws {
        // Create initial key
        let originalKey = try security.getOrCreateEncryptionKey()
        
        // Regenerate key
        let newKey = try security.regenerateEncryptionKey()
        
        XCTAssertNotEqual(originalKey, newKey, "Regenerated key should be different")
        XCTAssertFalse(newKey.isEmpty, "New key should not be empty")
        
        // Verify the new key is stored
        let retrievedKey = try security.getOrCreateEncryptionKey()
        XCTAssertEqual(newKey, retrievedKey, "Retrieved key should match the regenerated key")
    }
    
    func testRemoveEncryptionKey() throws {
        // Create key
        _ = try security.getOrCreateEncryptionKey()
        
        // Remove key
        try security.removeEncryptionKey()
        
        // Next call should create a new key
        let newKey = try security.getOrCreateEncryptionKey()
        XCTAssertFalse(newKey.isEmpty, "Should create new key after removal")
    }
    
    // MARK: - Database Connection Tests
    
    func testCreateEncryptedConnection() throws {
        let encryptedConnection = try security.createEncryptedConnection(to: testDatabasePath)
        XCTAssertNotNil(encryptedConnection, "Should create encrypted connection")
        
        // Verify encryption metadata table exists
        let metadataTableExists = try encryptedConnection.scalar(
            "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='_encryption_metadata'"
        ) as! Int64 > 0
        XCTAssertTrue(metadataTableExists, "Encryption metadata table should exist")
        
        // Verify encryption metadata is recorded
        let metadataCount = try encryptedConnection.scalar(
            "SELECT COUNT(*) FROM _encryption_metadata"
        ) as! Int64
        XCTAssertEqual(metadataCount, 1, "Should have encryption metadata record")
    }
    
    func testCreateMultipleEncryptedConnections() throws {
        // Create first connection
        let connection1 = try security.createEncryptedConnection(to: testDatabasePath)
        
        // Create second connection to same database
        let connection2 = try security.createEncryptedConnection(to: testDatabasePath)
        
        XCTAssertNotNil(connection1, "First connection should be created")
        XCTAssertNotNil(connection2, "Second connection should be created")
        
        // Both should access the same encryption metadata
        let metadata1 = try connection1.scalar("SELECT COUNT(*) FROM _encryption_metadata") as! Int64
        let metadata2 = try connection2.scalar("SELECT COUNT(*) FROM _encryption_metadata") as! Int64
        
        XCTAssertEqual(metadata1, metadata2, "Both connections should see same metadata")
    }
    
    // MARK: - Database Encryption Tests
    
    func testEncryptExistingDatabase() throws {
        // Create unencrypted database with data
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
        
        // Close connection
        testConnection = nil
        
        // Encrypt existing database
        try security.encryptExistingDatabase(at: testDatabasePath)
        
        // Verify database is now encrypted
        XCTAssertTrue(security.isDatabaseEncrypted(at: testDatabasePath), "Database should be encrypted")
        
        // Verify data is still accessible
        let encryptedConnection = try security.createEncryptedConnection(to: testDatabasePath)
        let chatCount = try encryptedConnection.scalar("SELECT COUNT(*) FROM chats") as! Int64
        XCTAssertEqual(chatCount, 1, "Data should still be accessible after encryption")
    }
    
    func testDecryptDatabase() throws {
        // Create and encrypt database
        try DatabaseSchema.createTables(db: testConnection)
        try security.encryptExistingDatabase(at: testDatabasePath)
        
        // Verify it's encrypted
        XCTAssertTrue(security.isDatabaseEncrypted(at: testDatabasePath), "Database should be encrypted")
        
        // Decrypt database
        try security.decryptDatabase(at: testDatabasePath)
        
        // Verify it's no longer encrypted
        XCTAssertFalse(security.isDatabaseEncrypted(at: testDatabasePath), "Database should not be encrypted")
    }
    
    func testEncryptNonExistentDatabase() {
        let nonExistentPath = "/tmp/nonexistent_database.db"
        
        XCTAssertThrowsError(try security.encryptExistingDatabase(at: nonExistentPath)) { error in
            XCTAssertTrue(error is DatabaseSecurityError, "Should throw DatabaseSecurityError")
            if let securityError = error as? DatabaseSecurityError {
                switch securityError {
                case .databaseNotFound:
                    break // Expected error
                default:
                    XCTFail("Should throw databaseNotFound error")
                }
            }
        }
    }
    
    // MARK: - Encryption Status Tests
    
    func testIsDatabaseEncryptedFalse() {
        // Create unencrypted database
        try! DatabaseSchema.createTables(db: testConnection)
        
        XCTAssertFalse(security.isDatabaseEncrypted(at: testDatabasePath), "New database should not be encrypted")
    }
    
    func testIsDatabaseEncryptedTrue() throws {
        // Create and encrypt database
        try DatabaseSchema.createTables(db: testConnection)
        try security.encryptExistingDatabase(at: testDatabasePath)
        
        XCTAssertTrue(security.isDatabaseEncrypted(at: testDatabasePath), "Encrypted database should be detected")
    }
    
    func testIsDatabaseEncryptedNonExistent() {
        let nonExistentPath = "/tmp/nonexistent_database.db"
        
        XCTAssertFalse(security.isDatabaseEncrypted(at: nonExistentPath), "Non-existent database should not be encrypted")
    }
    
    // MARK: - Key Rotation Tests
    
    func testRotateEncryptionKey() throws {
        // Create encrypted database
        try DatabaseSchema.createTables(db: testConnection)
        try security.encryptExistingDatabase(at: testDatabasePath)
        
        // Get initial key hash
        let encryptedConnection = try security.createEncryptedConnection(to: testDatabasePath)
        let initialKeyHash = try encryptedConnection.scalar(
            "SELECT key_hash FROM _encryption_metadata LIMIT 1"
        ) as! String
        
        // Rotate key
        try security.rotateEncryptionKey(at: testDatabasePath)
        
        // Get new key hash
        let newConnection = try security.createEncryptedConnection(to: testDatabasePath)
        let newKeyHash = try newConnection.scalar(
            "SELECT key_hash FROM _encryption_metadata LIMIT 1"
        ) as! String
        
        XCTAssertNotEqual(initialKeyHash, newKeyHash, "Key hash should change after rotation")
    }
    
    func testShouldRotateKey() throws {
        // Initially should rotate (no rotation recorded)
        XCTAssertTrue(security.shouldRotateKey(), "Should rotate key initially")
        
        // Record a rotation
        try security.recordKeyRotation()
        
        // Should not rotate immediately after recording
        XCTAssertFalse(security.shouldRotateKey(), "Should not rotate immediately after recording")
    }
    
    func testRecordKeyRotation() throws {
        // Record key rotation
        try security.recordKeyRotation()
        
        // Verify rotation was recorded (should not need to rotate immediately)
        XCTAssertFalse(security.shouldRotateKey(), "Should not need rotation after recording")
    }
    
    // MARK: - Security Validation Tests
    
    func testValidateDatabaseSecuritySuccess() throws {
        // Create encrypted database
        try DatabaseSchema.createTables(db: testConnection)
        try security.encryptExistingDatabase(at: testDatabasePath)
        
        let result = try security.validateDatabaseSecurity(at: testDatabasePath)
        
        XCTAssertTrue(result.isSecure, "Encrypted database should be secure")
        XCTAssertTrue(result.issues.isEmpty, "Should have no security issues")
    }
    
    func testValidateDatabaseSecurityFailure() throws {
        // Create unencrypted database
        try DatabaseSchema.createTables(db: testConnection)
        
        let result = try security.validateDatabaseSecurity(at: testDatabasePath)
        
        XCTAssertFalse(result.isSecure, "Unencrypted database should not be secure")
        XCTAssertFalse(result.issues.isEmpty, "Should have security issues")
        XCTAssertTrue(result.issues.contains("Database is not encrypted"), "Should report encryption issue")
    }
    
    func testValidateDatabaseSecurityNonExistent() throws {
        let nonExistentPath = "/tmp/nonexistent_database.db"
        
        let result = try security.validateDatabaseSecurity(at: nonExistentPath)
        
        XCTAssertFalse(result.isSecure, "Non-existent database should not be secure")
        XCTAssertTrue(result.issues.contains("Database file not found"), "Should report missing file")
    }
    
    // MARK: - Security Settings Tests
    
    func testGetSecuritySettings() {
        let settings = security.getSecuritySettings()
        
        XCTAssertEqual(settings.encryptionEnabled, true, "Default encryption should be enabled")
        XCTAssertEqual(settings.keyRotationInterval, 30 * 24 * 60 * 60, "Default rotation interval should be 30 days")
        XCTAssertEqual(settings.backupRetentionDays, 7, "Default backup retention should be 7 days")
        XCTAssertEqual(settings.auditLogEnabled, true, "Default audit log should be enabled")
    }
    
    // MARK: - Error Handling Tests
    
    func testDatabaseSecurityErrorTypes() {
        let errors: [DatabaseSecurityError] = [
            .databaseNotFound,
            .invalidEncryptionKey,
            .encryptionFailed(NSError(domain: "test", code: 1)),
            .decryptionFailed(NSError(domain: "test", code: 2)),
            .keyRotationFailed(NSError(domain: "test", code: 3)),
            .keychainAccessFailed
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription, "Error should have description")
            XCTAssertFalse(error.errorDescription!.isEmpty, "Error description should not be empty")
        }
    }
    
    // MARK: - Performance Tests
    
    func testEncryptionPerformance() throws {
        // Create database with test data
        try DatabaseSchema.createTables(db: testConnection)
        
        // Insert multiple records for performance testing
        for i in 0..<100 {
            let chatId = UUID().uuidString
            try testConnection.run(DatabaseSchema.Tables.chats.insert(
                DatabaseSchema.Tables.chatId <- chatId,
                DatabaseSchema.Tables.chatTitle <- "Test Chat \(i)",
                DatabaseSchema.Tables.chatCreatedAt <- Date(),
                DatabaseSchema.Tables.chatUpdatedAt <- Date(),
                DatabaseSchema.Tables.chatLLMProvider <- "openai",
                DatabaseSchema.Tables.chatModelName <- "gpt-4",
                DatabaseSchema.Tables.chatIsArchived <- false,
                DatabaseSchema.Tables.chatMessageCount <- 0
            ))
        }
        
        // Close connection
        testConnection = nil
        
        // Measure encryption performance
        let startTime = CFAbsoluteTimeGetCurrent()
        
        try security.encryptExistingDatabase(at: testDatabasePath)
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let encryptionTime = endTime - startTime
        
        XCTAssertLessThan(encryptionTime, 1.0, "Encryption should complete in under 1 second")
        
        // Verify data is still accessible
        let encryptedConnection = try security.createEncryptedConnection(to: testDatabasePath)
        let chatCount = try encryptedConnection.scalar("SELECT COUNT(*) FROM chats") as! Int64
        XCTAssertEqual(chatCount, 100, "All data should be accessible after encryption")
    }
    
    func testKeyGenerationPerformance() throws {
        // Measure key generation performance
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for _ in 0..<100 {
            _ = try security.regenerateEncryptionKey()
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let keyGenTime = endTime - startTime
        
        XCTAssertLessThan(keyGenTime, 1.0, "Key generation should be fast")
    }
    
    // MARK: - Integration Tests
    
    func testFullEncryptionWorkflow() throws {
        // Create unencrypted database with data
        try DatabaseSchema.createTables(db: testConnection)
        
        let originalChatId = UUID().uuidString
        try testConnection.run(DatabaseSchema.Tables.chats.insert(
            DatabaseSchema.Tables.chatId <- originalChatId,
            DatabaseSchema.Tables.chatTitle <- "Original Chat",
            DatabaseSchema.Tables.chatCreatedAt <- Date(),
            DatabaseSchema.Tables.chatUpdatedAt <- Date(),
            DatabaseSchema.Tables.chatLLMProvider <- "openai",
            DatabaseSchema.Tables.chatModelName <- "gpt-4",
            DatabaseSchema.Tables.chatIsArchived <- false,
            DatabaseSchema.Tables.chatMessageCount <- 0
        ))
        
        // Close connection
        testConnection = nil
        
        // Step 1: Encrypt database
        try security.encryptExistingDatabase(at: testDatabasePath)
        XCTAssertTrue(security.isDatabaseEncrypted(at: testDatabasePath), "Database should be encrypted")
        
        // Step 2: Access encrypted database
        let encryptedConnection = try security.createEncryptedConnection(to: testDatabasePath)
        let chatCount = try encryptedConnection.scalar("SELECT COUNT(*) FROM chats") as! Int64
        XCTAssertEqual(chatCount, 1, "Should access original data")
        
        // Step 3: Add new data to encrypted database
        let newChatId = UUID().uuidString
        try encryptedConnection.run(DatabaseSchema.Tables.chats.insert(
            DatabaseSchema.Tables.chatId <- newChatId,
            DatabaseSchema.Tables.chatTitle <- "New Chat",
            DatabaseSchema.Tables.chatCreatedAt <- Date(),
            DatabaseSchema.Tables.chatUpdatedAt <- Date(),
            DatabaseSchema.Tables.chatLLMProvider <- "anthropic",
            DatabaseSchema.Tables.chatModelName <- "claude-3-sonnet",
            DatabaseSchema.Tables.chatIsArchived <- false,
            DatabaseSchema.Tables.chatMessageCount <- 0
        ))
        
        // Step 4: Rotate encryption key
        try security.rotateEncryptionKey(at: testDatabasePath)
        
        // Step 5: Verify data is still accessible after key rotation
        let rotatedConnection = try security.createEncryptedConnection(to: testDatabasePath)
        let finalChatCount = try rotatedConnection.scalar("SELECT COUNT(*) FROM chats") as! Int64
        XCTAssertEqual(finalChatCount, 2, "Should access all data after key rotation")
        
        // Step 6: Validate security
        let validation = try security.validateDatabaseSecurity(at: testDatabasePath)
        XCTAssertTrue(validation.isSecure, "Database should be secure")
        
        // Step 7: Decrypt database
        try security.decryptDatabase(at: testDatabasePath)
        XCTAssertFalse(security.isDatabaseEncrypted(at: testDatabasePath), "Database should be decrypted")
    }
}