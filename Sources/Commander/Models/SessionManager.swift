import Foundation

public enum SessionManager {
  public static func currentSession() -> Session {
    let environment = ProcessInfo.processInfo.environment
    let sshEnv = environment["SSH_CONNECTION"] ?? environment["SSH_CLIENT"]
    let isSSH = sshEnv != nil
    let hostName = Host.current().localizedName ?? hostnameString() ?? "remote"

    let rootPath: String
    if let argRoot = rootArgument() {
      rootPath = NSString(string: argRoot).expandingTildeInPath
    } else if let envRoot = environment["COMMANDER_ROOT"] {
      rootPath = NSString(string: envRoot).expandingTildeInPath
    } else if isSSH {
      rootPath = FileManager.default.currentDirectoryPath
    } else {
      rootPath = FileManager.default.homeDirectoryForCurrentUser.path
    }

    let label: String?
    if isSSH {
      label = "SSH on \(hostName)"
    } else if let envLabel = environment["COMMANDER_SESSION_LABEL"], !envLabel.isEmpty {
      label = envLabel
    } else {
      label = nil
    }

    return Session(label: label, rootURL: URL(fileURLWithPath: rootPath))
  }

  private static func rootArgument() -> String? {
    let args = ProcessInfo.processInfo.arguments
    for (index, arg) in args.enumerated() {
      if arg == "--root" || arg == "-r" {
        let nextIndex = index + 1
        if nextIndex < args.count {
          return args[nextIndex]
        }
      } else if arg.hasPrefix("--root=") {
        return String(arg.dropFirst("--root=".count))
      }
    }
    return nil
  }

  private static func hostnameString() -> String? {
    var nameBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
    if gethostname(&nameBuffer, nameBuffer.count) == 0 {
      let length = nameBuffer.firstIndex(of: 0) ?? nameBuffer.count
      let bytes = Data(bytes: nameBuffer, count: length)
      return String(data: bytes, encoding: .utf8)
    }
    return nil
  }
}
