import Darwin
import Foundation
import UserNotifications

// MARK: - Models

struct NotificationSpec: Sendable {
    let message: String
    let title: String
    let subtitle: String?
    let sound: String?
    let groupID: String?
}

struct DeliveredItem: Sendable {
    let identifier: String
    let groupID: String?
    let title: String?
    let subtitle: String?
    let message: String?
    let deliveredAt: Date?
}

// MARK: - Errors

enum NotifierError: Error, Sendable {
    case permissionDenied
    case permissionNotDetermined
    case deliveryFailed(String)
}

extension NotifierError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Notification permission denied. Enable in System Settings > Notifications."
        case .permissionNotDetermined:
            return "Notification permission not granted. Run once interactively to grant access."
        case .deliveryFailed(let reason):
            return "Notification delivery failed: \(reason)"
        }
    }
}

// MARK: - Notifier

actor Notifier {

    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func requestAuthorization() async throws {
        let options: UNAuthorizationOptions = [.alert, .sound, .badge]
        do {
            let granted = try await center.requestAuthorization(options: options)
            if !granted { throw NotifierError.permissionDenied }
        } catch let error as NotifierError {
            throw error
        } catch {
            throw NotifierError.permissionDenied
        }
    }

    func deliver(_ spec: NotificationSpec) async throws {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .denied:
            throw NotifierError.permissionDenied
        case .notDetermined:
            try await requestAuthorization()
        default:
            break
        }

        let content = UNMutableNotificationContent()
        content.title = spec.title
        content.body = spec.message
        if let subtitle = spec.subtitle { content.subtitle = subtitle }
        if let sound = spec.sound {
            content.sound = sound == "default"
                ? .default
                : UNNotificationSound(named: UNNotificationSoundName(rawValue: sound))
        }
        if let groupID = spec.groupID {
            content.threadIdentifier = groupID
        }

        // Replace existing notification with the same group ID
        if let groupID = spec.groupID {
            let existing = await center.deliveredNotifications()
            let toRemove = existing
                .filter { $0.request.content.threadIdentifier == groupID }
                .map { $0.request.identifier }
            if !toRemove.isEmpty {
                center.removeDeliveredNotifications(withIdentifiers: toRemove)
            }
        }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let identifier = spec.groupID ?? UUID().uuidString
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await center.add(request)
        } catch {
            throw NotifierError.deliveryFailed(error.localizedDescription)
        }

        // Wait for delivery — UNUserNotificationCenter has no didDeliver callback
        try? await Task.sleep(nanoseconds: 900_000_000)
    }

    func remove(groupID: String) async {
        if groupID == "ALL" {
            center.removeAllDeliveredNotifications()
        } else {
            let delivered = await center.deliveredNotifications()
            let identifiers = delivered
                .filter {
                    $0.request.identifier == groupID ||
                    $0.request.content.threadIdentifier == groupID
                }
                .map { $0.request.identifier }
            if !identifiers.isEmpty {
                center.removeDeliveredNotifications(withIdentifiers: identifiers)
            }
        }
    }

    func list(groupID: String) async -> [DeliveredItem] {
        let delivered = await center.deliveredNotifications()
        let filtered = groupID == "ALL"
            ? delivered
            : delivered.filter {
                $0.request.identifier == groupID ||
                $0.request.content.threadIdentifier == groupID
            }
        return filtered.map { notification in
            let c = notification.request.content
            return DeliveredItem(
                identifier: notification.request.identifier,
                groupID: c.threadIdentifier.isEmpty ? nil : c.threadIdentifier,
                title: c.title.isEmpty ? nil : c.title,
                subtitle: c.subtitle.isEmpty ? nil : c.subtitle,
                message: c.body.isEmpty ? nil : c.body,
                deliveredAt: notification.date
            )
        }
    }
}

// MARK: - Terminal Emulator

enum TerminalEmulator {
    case iterm2, warp, kitty, wezterm, unknown

    static func detect() -> TerminalEmulator {
        let env = ProcessInfo.processInfo.environment
        if env["ITERM_SESSION_ID"] != nil || env["TERM_PROGRAM"] == "iTerm.app" { return .iterm2 }
        if env["TERM_PROGRAM"] == "WarpTerminal" { return .warp }
        if env["TERM"] == "xterm-kitty" { return .kitty }
        if env["WEZTERM_EXECUTABLE"] != nil { return .wezterm }
        return .unknown
    }
}

// MARK: - Terminal Alert

enum TerminalAlert {

    static func flash(color: String = "red") {
        guard isatty(STDOUT_FILENO) != 0 else { return }
        switch TerminalEmulator.detect() {
        case .iterm2:           flashiTerm2(color: color)
        case .warp, .wezterm:  emitOSC9(message: "⚡ notification")
        case .kitty:            emitOSC99(title: "notification", body: "")
        case .unknown:          flashANSIReverseVideo()
        }
    }

    static func emitNotification(title: String, body: String) {
        guard isatty(STDOUT_FILENO) != 0 else { return }
        switch TerminalEmulator.detect() {
        case .iterm2, .warp, .wezterm: emitOSC9(message: "\(title): \(body)")
        case .kitty:                   emitOSC99(title: title, body: body)
        case .unknown:                 break
        }
    }

    private static func flashiTerm2(color: String) {
        let (r, g, b) = rgbValues(for: color)
        print("\u{1B}]6;1;bg;red;brightness;\(r)\u{07}", terminator: "")
        print("\u{1B}]6;1;bg;green;brightness;\(g)\u{07}", terminator: "")
        print("\u{1B}]6;1;bg;blue;brightness;\(b)\u{07}", terminator: "")
        fflush(stdout)
        usleep(300_000)
        print("\u{1B}]6;1;bg;*;default\u{07}", terminator: "")
        fflush(stdout)
    }

    private static func flashANSIReverseVideo() {
        print("\u{1B}[7m", terminator: "")
        fflush(stdout)
        usleep(300_000)
        print("\u{1B}[27m", terminator: "")
        fflush(stdout)
    }

    private static func emitOSC9(message: String) {
        print("\u{1B}]9;\(message)\u{07}", terminator: "")
        fflush(stdout)
    }

    private static func emitOSC99(title: String, body: String) {
        print("\u{1B}]99;i=terminal-notifier-next:p=title;\(title)\u{1B}\\", terminator: "")
        print("\u{1B}]99;i=terminal-notifier-next:p=body;\(body)\u{1B}\\", terminator: "")
        fflush(stdout)
    }

    private static func rgbValues(for colorName: String) -> (Int, Int, Int) {
        switch colorName.lowercased() {
        case "red":    return (255, 30, 30)
        case "green":  return (30, 200, 30)
        case "blue":   return (30, 30, 255)
        case "yellow": return (255, 200, 0)
        case "orange": return (255, 128, 0)
        case "purple": return (128, 0, 200)
        case "cyan":   return (0, 200, 200)
        default:       return (255, 30, 30)
        }
    }
}

// MARK: - NotifierArgs

struct NotifierArgs {
    var message: String? = nil
    var title: String = "Terminal"
    var subtitle: String? = nil
    var sound: String? = nil
    var group: String? = nil
    var remove: String? = nil
    var list: String? = nil
    var terminalAlert: Bool = false
    var terminalAlertColor: String = "red"

    static func parse(_ args: [String]) -> NotifierArgs {
        var opts = NotifierArgs()
        var i = 0
        while i < args.count {
            let arg = args[i]
            switch arg {
            case "--help", "-h":
                printHelp()
                exit(0)
            case "--version":
                let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "3.0.0"
                print(v)
                exit(0)
            case "--message":
                i += 1; guard i < args.count else { missing(arg) }
                opts.message = args[i]
            case "--title":
                i += 1; guard i < args.count else { missing(arg) }
                opts.title = args[i]
            case "--subtitle":
                i += 1; guard i < args.count else { missing(arg) }
                opts.subtitle = args[i]
            case "--sound":
                i += 1; guard i < args.count else { missing(arg) }
                opts.sound = args[i]
            case "--group":
                i += 1; guard i < args.count else { missing(arg) }
                opts.group = args[i]
            case "--remove":
                i += 1; guard i < args.count else { missing(arg) }
                opts.remove = args[i]
            case "--list":
                i += 1; guard i < args.count else { missing(arg) }
                opts.list = args[i]
            case "--terminal-alert":
                opts.terminalAlert = true
            case "--terminal-alert-color":
                i += 1; guard i < args.count else { missing(arg) }
                opts.terminalAlertColor = args[i]
            default:
                fputs("terminal-notifier-next: unknown option '\(arg)'\n", stderr)
                fputs("Run with --help for usage.\n", stderr)
                exit(1)
            }
            i += 1
        }
        return opts
    }

    static func printHelp() {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "3.0.0"
        print("""
        terminal-notifier-next \(v)
        Send macOS User Notifications from the command line.

        USAGE
          terminal-notifier-next --message <text> [options]
          terminal-notifier-next --remove <groupID|ALL>
          terminal-notifier-next --list <groupID|ALL>
          echo "msg" | terminal-notifier-next [options]

        CONTENT
          --message <text>           The notification body (required unless piped, --remove, or --list)
          --title <text>             Title (default: Terminal)
          --subtitle <text>          Subtitle
          --sound <name>             Sound name (e.g., Glass) or 'default'. See /System/Library/Sounds.

        GROUPING
          --group <id>               Notifications with the same ID replace each other

        OPERATIONS
          --remove <groupID|ALL>     Remove delivered notification(s)
          --list <groupID|ALL>       List delivered notifications as JSON

        TERMINAL
          --terminal-alert           Flash the calling terminal window
          --terminal-alert-color <c> Color: red, green, blue, yellow, orange, purple, cyan (default: red)

        GENERAL
          --help                     Show this help
          --version                  Show version

        EXIT CODES
          0   Success
          1   Error (missing args, permission denied, delivery failed)

        EXAMPLES
          terminal-notifier-next --message "Build done" --title "CI" --sound default
          terminal-notifier-next --group myapp --message "Task complete"
          terminal-notifier-next --remove ALL
          terminal-notifier-next --list ALL
          echo "Done" | terminal-notifier-next --title "Pipeline"
        """)
    }

    private static func missing(_ flag: String) -> Never {
        fputs("terminal-notifier-next: \(flag) requires a value\n", stderr)
        exit(1)
    }
}

// MARK: - MainFlow

enum MainFlow {

    static func run() async {
        var args = Array(CommandLine.arguments.dropFirst())

        // Inject piped stdin as --message if not already set.
        // Skip when we already have a mode flag or a help/version flag.
        if isatty(STDIN_FILENO) == 0,
           !args.contains("--message"),
           !args.contains("--remove"),
           !args.contains("--list"),
           !args.contains("--help"),
           !args.contains("-h"),
           !args.contains("--version") {
            if let stdinMessage = readStdin() {
                args += ["--message", stdinMessage]
            }
        }

        if args.isEmpty {
            NotifierArgs.printHelp()
            exit(1)
        }

        let options = NotifierArgs.parse(args)

        do {
            try await execute(options: options)
        } catch let error as NotifierError {
            fputs("terminal-notifier-next: \(error.localizedDescription)\n", stderr)
            exit(1)
        } catch {
            fputs("terminal-notifier-next: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }

    // MARK: - Private

    private static func execute(options: NotifierArgs) async throws {
        let notifier = Notifier()

        // List mode
        if let groupID = options.list {
            let items = await notifier.list(groupID: groupID)
            outputList(items)
            exit(0)
        }

        // Remove mode
        if let groupID = options.remove {
            await notifier.remove(groupID: groupID)
            exit(0)
        }

        // Deliver mode — message required
        guard let message = options.message else {
            NotifierArgs.printHelp()
            exit(1)
        }

        if options.terminalAlert {
            TerminalAlert.flash(color: options.terminalAlertColor)
        }

        let spec = NotificationSpec(
            message: message,
            title: options.title,
            subtitle: options.subtitle,
            sound: options.sound,
            groupID: options.group
        )

        try await notifier.requestAuthorization()
        try await notifier.deliver(spec)
        exit(0)
    }

    // MARK: - Output helpers

    private static func outputList(_ items: [DeliveredItem]) {
        guard !items.isEmpty else {
            print("[]")
            fflush(stdout)
            return
        }

        let formatter = ISO8601DateFormatter()
        var jsonItems: [[String: Any]] = []
        for item in items {
            var dict: [String: Any] = ["identifier": item.identifier]
            if let v = item.groupID { dict["groupID"] = v } else { dict["groupID"] = NSNull() }
            if let v = item.title { dict["title"] = v } else { dict["title"] = NSNull() }
            if let v = item.subtitle { dict["subtitle"] = v } else { dict["subtitle"] = NSNull() }
            if let v = item.message { dict["message"] = v } else { dict["message"] = NSNull() }
            if let d = item.deliveredAt {
                dict["deliveredAt"] = formatter.string(from: d)
            } else {
                dict["deliveredAt"] = NSNull()
            }
            jsonItems.append(dict)
        }

        if let data = try? JSONSerialization.data(withJSONObject: jsonItems, options: [.prettyPrinted]),
           let json = String(data: data, encoding: .utf8) {
            print(json)
        } else {
            print("[]")
        }
        fflush(stdout)
    }

    private static func readStdin() -> String? {
        // Check if stdin has data ready RIGHT NOW using poll() with zero timeout.
        // This avoids blocking on pipes whose write-end is still open but empty
        // (the common case when invoked by a shell that keeps its own script pipe
        // open). We also avoid reading past the piped content into the shell's
        // remaining script by using readDataToEndOfFile() — which only returns
        // when the write-end of the pipe is closed (i.e., the piping process, like
        // echo or printf, has exited and given us a genuine EOF).
        var pfd = pollfd(fd: STDIN_FILENO, events: Int16(POLLIN), revents: 0)
        guard poll(&pfd, 1, 0) > 0 else { return nil }  // no data available right now

        let data = FileHandle.standardInput.readDataToEndOfFile()
        guard !data.isEmpty,
              let text = String(data: data, encoding: .utf8) else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
