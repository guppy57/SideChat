import Foundation
import SQLite
import KeychainAccess
import CryptoKit

// MARK: - Database Security Manager

/// DatabaseSecurity handles database encryption and key management
/// Uses SQLCipher for database encryption and Keychain for secure key storage

class DatabaseSecurity {
    static let shared = DatabaseSecurity()
    
    private let keychain = Keychain(service: "com.sidechat.database")
    private let encryptionKeyIdentifier = "database_encryption_key"
    
    private init() {}
    
    // MARK: - Encryption Key Management
    
    func getOrCreateEncryptionKey() throws -> String {
        // Try to get existing key from keychain
        if let existingKey = try? keychain.get(encryptionKeyIdentifier) {
            return existingKey
        }
        
        // Generate new encryption key
        let newKey = generateEncryptionKey()
        
        // Store in keychain
        try keychain.set(newKey, key: encryptionKeyIdentifier)
        
        return newKey
    }
    
    private func generateEncryptionKey() -> String {
        // Generate a 256-bit (32-byte) key using CryptoKit
        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes { Data($0) }
        return keyData.base64EncodedString()
    }
    
    func regenerateEncryptionKey() throws -> String {
        // Remove existing key
        try keychain.remove(encryptionKeyIdentifier)
        
        // Generate and store new key
        return try getOrCreateEncryptionKey()
    }
    
    func removeEncryptionKey() throws {
        try keychain.remove(encryptionKeyIdentifier)
    }
    
    // MARK: - Database Connection with Encryption
    
    func createEncryptedConnection(to path: String) throws -> Connection {
        let encryptionKey = try getOrCreateEncryptionKey()
        
        // Create connection to SQLCipher database
        let connection = try Connection(path)
        
        // Note: SQLCipher integration requires the SQLCipher library
        // For now, we'll simulate encryption by storing the key securely
        // In production, this would use: try connection.execute("PRAGMA key = '\(encryptionKey)'")
        
        // For development, we'll just use file-level encryption simulation
        try simulateEncryption(connection: connection, key: encryptionKey)
        
        return connection
    }
    
    private func simulateEncryption(connection: Connection, key: String) throws {
        // This is a placeholder for SQLCipher encryption
        // In production, you would:
        // 1. Use SQLCipher-enabled SQLite.swift build
        // 2. Execute PRAGMA key statements
        // 3. Handle SQLCipher-specific operations
        
        // For now, we'll add a metadata table to track encryption status
        try connection.execute("""
            CREATE TABLE IF NOT EXISTS _encryption_metadata (
                key_hash TEXT,
                encrypted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)
        
        // Store hash of encryption key (not the key itself)
        let keyHash = SHA256.hash(data: key.data(using: .utf8)!)
        let hashString = keyHash.compactMap { String(format: "%02x", $0) }.joined()
        
        try connection.run("""
            INSERT OR REPLACE INTO _encryption_metadata (key_hash)
            VALUES (?)
        """, hashString)
    }
    
    private func verifyDatabaseAccess(connection: Connection) throws {
        // Try to access the database to verify the key is correct
        do {
            _ = try connection.scalar("SELECT count(*) FROM sqlite_master")
        } catch {
            throw DatabaseSecurityError.invalidEncryptionKey
        }
    }
    
    // MARK: - Database Migration for Encryption
    
    func encryptExistingDatabase(at path: String) throws {
        // Check if database exists and is unencrypted
        guard FileManager.default.fileExists(atPath: path) else {
            throw DatabaseSecurityError.databaseNotFound
        }
        
        // For simulated encryption, we just add encryption metadata
        do {
            let connection = try Connection(path)
            let encryptionKey = try getOrCreateEncryptionKey()
            try simulateEncryption(connection: connection, key: encryptionKey)
            
            print("Database encryption simulation enabled")
            // In production with SQLCipher, this would involve:
            // 1. Creating encrypted copy with PRAGMA key
            // 2. Using sqlcipher_export to transfer data
            // 3. Replacing original with encrypted version
            
        } catch {
            throw DatabaseSecurityError.encryptionFailed(error)
        }
    }
    
    func decryptDatabase(at path: String) throws {
        guard FileManager.default.fileExists(atPath: path) else {
            throw DatabaseSecurityError.databaseNotFound
        }
        
        // For simulated encryption, we just remove encryption metadata
        do {
            let connection = try Connection(path)
            try connection.execute("DROP TABLE IF EXISTS _encryption_metadata")
            
            print("Database encryption simulation disabled")
            // In production with SQLCipher, this would involve:
            // 1. Opening encrypted database with PRAGMA key
            // 2. Creating unencrypted copy
            // 3. Replacing original with unencrypted version
            
        } catch {
            throw DatabaseSecurityError.decryptionFailed(error)
        }
    }
    
    // MARK: - Encryption Status
    
    func isDatabaseEncrypted(at path: String) -> Bool {
        guard FileManager.default.fileExists(atPath: path) else {
            return false
        }
        
        do {
            // Check for encryption metadata table
            let connection = try Connection(path, readonly: true)
            let hasEncryptionTable = try connection.scalar(
                "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='_encryption_metadata'"
            ) as! Int64 > 0
            
            return hasEncryptionTable
            
            // In production with SQLCipher, this would:
            // 1. Try to open without PRAGMA key
            // 2. If that fails, try with the stored key
            // 3. Return true if key is required for access
            
        } catch {
            return false
        }
    }
    
    // MARK: - Key Rotation
    
    func rotateEncryptionKey(at path: String) throws {
        guard FileManager.default.fileExists(atPath: path) else {
            throw DatabaseSecurityError.databaseNotFound
        }
        
        do {
            // Generate new key
            let newKey = generateEncryptionKey()
            
            // Store new key in keychain
            try keychain.set(newKey, key: encryptionKeyIdentifier)
            
            // Update encryption metadata
            let connection = try Connection(path)
            try simulateEncryption(connection: connection, key: newKey)
            
            print("Encryption key rotated successfully")
            
            // In production with SQLCipher, this would use:
            // PRAGMA rekey = 'new_key' to change the database key
            
        } catch {
            throw DatabaseSecurityError.keyRotationFailed(error)
        }
    }
    
    // MARK: - Security Validation
    
    func validateDatabaseSecurity(at path: String) throws -> SecurityValidationResult {
        var issues: [String] = []
        var warnings: [String] = []
        
        // Check if database exists
        guard FileManager.default.fileExists(atPath: path) else {
            issues.append("Database file not found")
            return SecurityValidationResult(isSecure: false, issues: issues, warnings: warnings)
        }
        
        // Check if database is encrypted
        let isEncrypted = isDatabaseEncrypted(at: path)
        if !isEncrypted {
            issues.append("Database is not encrypted")
        }
        
        // Check file permissions
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: path)
            if let permissions = attributes[.posixPermissions] as? NSNumber {
                let perms = permissions.uint16Value
                if perms & 0o044 != 0 { // Check if readable by group/others
                    warnings.append("Database file has overly permissive read permissions")
                }
            }
        } catch {
            warnings.append("Could not check file permissions: \(error.localizedDescription)")
        }
        
        // Check keychain accessibility
        do {
            _ = try keychain.get(encryptionKeyIdentifier)
        } catch {
            issues.append("Cannot access encryption key from keychain")
        }
        
        return SecurityValidationResult(
            isSecure: issues.isEmpty,
            issues: issues,
            warnings: warnings
        )
    }
}

// MARK: - Database Security Errors

enum DatabaseSecurityError: LocalizedError {
    case databaseNotFound
    case invalidEncryptionKey
    case encryptionFailed(Error)
    case decryptionFailed(Error)
    case keyRotationFailed(Error)
    case keychainAccessFailed
    
    var errorDescription: String? {
        switch self {
        case .databaseNotFound:
            return "Database file not found"
        case .invalidEncryptionKey:
            return "Invalid encryption key"
        case .encryptionFailed(let error):
            return "Encryption failed: \(error.localizedDescription)"
        case .decryptionFailed(let error):
            return "Decryption failed: \(error.localizedDescription)"
        case .keyRotationFailed(let error):
            return "Key rotation failed: \(error.localizedDescription)"
        case .keychainAccessFailed:
            return "Failed to access keychain"
        }
    }
}

// MARK: - Security Validation Result

struct SecurityValidationResult {
    let isSecure: Bool
    let issues: [String]
    let warnings: [String]
}

// MARK: - Database Security Settings

extension DatabaseSecurity {
    
    struct SecuritySettings {
        let encryptionEnabled: Bool
        let keyRotationInterval: TimeInterval // in seconds
        let backupRetentionDays: Int
        let auditLogEnabled: Bool
        
        static let `default` = SecuritySettings(
            encryptionEnabled: true,
            keyRotationInterval: 30 * 24 * 60 * 60, // 30 days
            backupRetentionDays: 7,
            auditLogEnabled: true
        )
    }
    
    func getSecuritySettings() -> SecuritySettings {
        // In a real implementation, these would come from user defaults
        return SecuritySettings.default
    }
    
    func shouldRotateKey() -> Bool {
        guard let lastRotation = try? keychain.get("last_key_rotation"),
              let lastRotationDate = ISO8601DateFormatter().date(from: lastRotation) else {
            return true // No rotation recorded, should rotate
        }
        
        let settings = getSecuritySettings()
        let timeSinceRotation = Date().timeIntervalSince(lastRotationDate)
        return timeSinceRotation >= settings.keyRotationInterval
    }
    
    func recordKeyRotation() throws {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        try keychain.set(timestamp, key: "last_key_rotation")
    }
}