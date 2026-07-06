import CodexBarCore
import Combine
import Foundation

enum ManagedCodexAccountCoordinatorError: Error, Equatable {
    case authenticationInProgress
}

@MainActor
final class ManagedCodexAccountCoordinator: ObservableObject {
    let service: ManagedCodexAccountService
    @Published private(set) var isAuthenticatingManagedAccount: Bool = false
    @Published private(set) var authenticatingManagedAccountID: UUID?
    @Published private(set) var isRemovingManagedAccount: Bool = false
    @Published private(set) var removingManagedAccountID: UUID?
    var onManagedAccountsDidChange: (@MainActor () -> Void)?

    var hasConflictingManagedAccountOperationInFlight: Bool {
        self.isAuthenticatingManagedAccount || self.isRemovingManagedAccount
    }

    init(service: ManagedCodexAccountService = ManagedCodexAccountService()) {
        self.service = service
    }

    func authenticateManagedAccount(
        existingAccountID: UUID? = nil,
        timeout: TimeInterval = 120)
        async throws -> ManagedCodexAccount
    {
        guard self.isAuthenticatingManagedAccount == false else {
            throw ManagedCodexAccountCoordinatorError.authenticationInProgress
        }

        self.isAuthenticatingManagedAccount = true
        self.authenticatingManagedAccountID = existingAccountID
        defer {
            self.isAuthenticatingManagedAccount = false
            self.authenticatingManagedAccountID = nil
        }

        let account = try await self.service.authenticateManagedAccount(
            existingAccountID: existingAccountID,
            timeout: timeout)
        self.onManagedAccountsDidChange?()
        return account
    }

    func removeManagedAccount(id: UUID) async throws {
        self.isRemovingManagedAccount = true
        self.removingManagedAccountID = id
        defer {
            self.isRemovingManagedAccount = false
            self.removingManagedAccountID = nil
        }

        try await self.service.removeManagedAccount(id: id)
        self.onManagedAccountsDidChange?()
    }
}
