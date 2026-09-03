import FieldNotesAgentLoop
import Foundation
import OSLog
import Security

enum AgentSecurityFailure: Error {
    case keychain(OSStatus)
    case missingCredential
}

struct DeviceCredentialVault: Sendable {
    let service: String
    let account: String

    func save(_ credential: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        var item = query
        item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        item[kSecValueData as String] = credential
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else { throw AgentSecurityFailure.keychain(status) }
    }

    func load() throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { throw AgentSecurityFailure.missingCredential }
        guard status == errSecSuccess, let data = result as? Data else {
            throw AgentSecurityFailure.keychain(status)
        }
        return data
    }
}

struct SecurePersonalContextExporter: Sendable {
    func write(_ contents: String, to url: URL) throws {
        try Data(contents.utf8).write(
            to: url,
            options: [.atomic, .completeFileProtection]
        )
    }
}

struct AgentSecurityLogger: Sendable {
    private let logger = Logger(
        subsystem: "com.example.MasteringAgenticAI.FieldNotes",
        category: "agent-audit"
    )

    func record(outcome: String, correlationIdentifier: String) {
        logger.info(
            "Agent outcome=\(outcome, privacy: .public) correlation=\(correlationIdentifier, privacy: .private(mask: .hash))"
        )
    }
}

extension SwiftDataPersonalContextStore {
    func promptEnvelope(
        grant: MemoryConsentGrant,
        ledger: MemoryConsentLedger,
        now: Date
    ) async throws -> ToolResultEnvelope<[PersonalContextRecord]> {
        ToolResultEnvelope(
            sourceTool: "personalContext",
            data: try await records(grant: grant, ledger: ledger, now: now)
        )
    }
}
