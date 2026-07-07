import CodexBarCore
import Foundation
import ServiceManagement

enum LaunchAtLoginStatus {
    case enabled
    case requiresApproval
    case notRegistered
    case notFound
}

enum LaunchAtLoginManager {
    typealias StatusProvider = () -> LaunchAtLoginStatus
    typealias RegistrationAction = () throws -> Void

    private static let isRunningTests: Bool = {
        let env = ProcessInfo.processInfo.environment
        if env["XCTestConfigurationFilePath"] != nil { return true }
        if env["TESTING_LIBRARY_VERSION"] != nil { return true }
        if env["SWIFT_TESTING"] != nil { return true }
        return NSClassFromString("XCTestCase") != nil
    }()

    static func setEnabled(_ enabled: Bool) {
        if self.isRunningTests { return }
        do {
            if #available(macOS 13, *) {
                let service = SMAppService.mainApp
                self.setEnabled(
                    enabled,
                    status: { self.status(for: service) },
                    register: { try service.register() },
                    unregister: { try service.unregister() })
            } else {
                try self.setLegacyLaunchAgentEnabled(enabled)
            }
        } catch {
            CodexBarLog.logger(LogCategories.launchAtLogin).error("Failed to update login item: \(error)")
        }
    }

    static func setEnabled(
        _ enabled: Bool,
        status: StatusProvider,
        register: RegistrationAction,
        unregister: RegistrationAction)
    {
        do {
            if enabled {
                switch status() {
                case .enabled, .requiresApproval:
                    return
                case .notRegistered, .notFound:
                    try register()
                }
            } else {
                switch status() {
                case .enabled, .requiresApproval:
                    try unregister()
                case .notRegistered, .notFound:
                    return
                }
            }
        } catch {
            CodexBarLog.logger(LogCategories.launchAtLogin).error("Failed to update login item: \(error)")
        }
    }

    @available(macOS 13, *)
    private static func status(for service: SMAppService) -> LaunchAtLoginStatus {
        switch service.status {
        case .enabled:
            return .enabled
        case .requiresApproval:
            return .requiresApproval
        case .notRegistered:
            return .notRegistered
        case .notFound:
            return .notFound
        @unknown default:
            return .notRegistered
        }
    }

    private static func setLegacyLaunchAgentEnabled(_ enabled: Bool) throws {
        let url = self.legacyLaunchAgentURL
        if enabled {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true)
            try self.legacyLaunchAgentData().write(to: url, options: .atomic)
        } else if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    private static var legacyLaunchAgentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents")
            .appendingPathComponent("\(self.legacyLaunchAgentIdentifier).plist")
    }

    private static var legacyLaunchAgentIdentifier: String {
        "\(Bundle.main.bundleIdentifier ?? "com.steipete.CodexBar").login"
    }

    private static func legacyLaunchAgentData() throws -> Data {
        guard let executableURL = Bundle.main.executableURL else {
            throw CocoaError(.fileNoSuchFile)
        }
        let plist: [String: Any] = [
            "Label": self.legacyLaunchAgentIdentifier,
            "ProgramArguments": [executableURL.path],
            "RunAtLoad": true,
        ]
        return try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
    }
}
