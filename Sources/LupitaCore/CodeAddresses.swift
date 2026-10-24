import Foundation

extension CodeRefs {
    /// Local addresses (D29, type 2): `localhost:8130`, `http://127.0.0.1:8131/x.html`. Which repo serves
    /// it, which page, and whether it is on. The repo comes from the process listening on the port, then
    /// from the `.claude/launch.json` that declares it. No HTTP request is ever made.
    enum Addresses {
        struct Listener: Sendable {
            let pid: Int
            let command: String
            let cwd: String?
        }

        /// Who listens on a TCP port. Replaceable so tests do not depend on what runs on the Mac.
        nonisolated(unsafe) static var listener: @Sendable (Int) -> Listener? = lsofListener

        static let shape = try! NSRegularExpression(
            pattern: #"^(?:https?://)?(?:localhost|127\.0\.0\.1|0\.0\.0\.0|\[::1\]):(\d{2,5})(/[^\s?#]*)?(?:[?#]\S*)?$"#)

        struct Config {
            let owner: Repo
            let name: String
            let file: String
            /// Absolute paths found in the command, to tell which checkout it starts.
            let paths: [String]
        }

        static func resolve(_ text: Text, repos: [Repo], preferredRepo: String?) -> [Definition]? {
            guard let g = groups(shape, text.text), let port = Int(g[1]), (1...65535).contains(port) else { return nil }
            let route = g[2].isEmpty ? "/" : g[2]
            let places = places(of: repos)
            let configs = configs(forPort: port, repos: repos)
            let live = listener(port)

            // Which checkout serves it: the process's folder, then a path in the launch command, then the declaring repo.
            var served: (label: String, root: String)?
            if let cwd = live?.cwd.map(RepoDiscovery.realPath) { served = place(containing: cwd, in: places) }
            var config = configs.first
            if served == nil {
                for c in configs {
                    if let p = c.paths.lazy.compactMap({ place(containing: RepoDiscovery.realPath($0), in: places) }).first {
                        served = p; config = c; break
                    }
                }
            }
            if served == nil, let c = configs.first { served = (c.owner.name, c.owner.path) }
            if served != nil, let live, let cwd = live.cwd.map(RepoDiscovery.realPath), let p = place(containing: cwd, in: places),
               let match = configs.first(where: { $0.paths.contains { place(containing: RepoDiscovery.realPath($0), in: places)?.root == p.root } }) {
                config = match
            }

            let title = config.map { S.servedByConfig($0.name) } ?? live.map { S.servedByProcess($0.command) } ?? S.addressUnknown
            let state = live.map { S.running(pid: $0.pid) } ?? S.notRunning
            let pageText = route == "/" ? S.homePage : S.page(route)
            var path = "", absolute = served?.root ?? config?.file ?? ""
            if let served, let file = page(route, in: served.root) {
                path = String(file.dropFirst(served.root.count + 1))
                absolute = file
            } else if let config {
                // The launch file may belong to another repo than the checkout that serves the page.
                let relative = String(config.file.dropFirst(config.owner.path.count + 1))
                path = served == nil || served?.label == config.owner.name ? relative : config.owner.name + "/" + relative
                absolute = config.file
            }
            let id = "localhost:\(port)"
            return [Definition(id: id, key: id, repo: served?.label ?? "", path: path, line: 1, rule: .address, title: title,
                               summary: [pageText, state].joined(separator: " · "), absolutePath: absolute)]
        }

        // MARK: Launch configurations

        static func configs(forPort port: Int, repos: [Repo]) -> [Config] {
            var out: [Config] = []
            for repo in repos {
                let file = repo.path + "/.claude/launch.json"
                guard let data = FileManager.default.contents(atPath: file),
                      let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                      let list = json["configurations"] as? [[String: Any]] else { continue }
                for c in list {
                    let declared = (c["port"] as? Int) ?? (c["url"] as? String).flatMap(urlPort)
                    guard declared == port, let name = c["name"] as? String else { continue }
                    let args = ((c["runtimeArgs"] as? [String]) ?? []) + [(c["runtimeExecutable"] as? String) ?? ""]
                    let paths = args.flatMap { $0.components(separatedBy: "=") }.filter { $0.hasPrefix("/") }
                    out.append(Config(owner: repo, name: name, file: file, paths: paths))
                }
            }
            return out
        }

        static func urlPort(_ url: String) -> Int? {
            URL(string: url)?.port
        }

        // MARK: Checkouts

        /// Repos and their linked worktrees, longest path first so the most specific folder wins.
        static func places(of repos: [Repo]) -> [(label: String, root: String)] {
            var all: [(label: String, root: String)] = repos.map { ($0.name, RepoDiscovery.realPath($0.path)) }
            for repo in repos {
                all += Symbols.worktrees(of: repo).map { ("\(repo.name) · \(($0 as NSString).lastPathComponent)", $0) }
            }
            return all.sorted { $0.root.count > $1.root.count }
        }

        static func place(containing path: String, in places: [(label: String, root: String)]) -> (label: String, root: String)? {
            places.first { path == $0.root || path.hasPrefix($0.root + "/") }
        }

        /// The HTML file a route names inside a checkout: `/` is `index.html`; `/a.html` is found at the root or deeper.
        static func page(_ route: String, in root: String) -> String? {
            let relative = route == "/" ? "index.html" : String(route.dropFirst())
            let direct = root + "/" + relative
            if FileManager.default.fileExists(atPath: direct) { return direct }
            guard (relative as NSString).pathExtension.lowercased().hasPrefix("htm") else { return nil }
            return Symbols.sourceFiles(in: root, extensions: ["html", "htm"]).first { $0.hasSuffix("/" + relative) }
        }

        // MARK: lsof

        @Sendable static func lsofListener(_ port: Int) -> Listener? {
            guard let out = run("/usr/sbin/lsof", ["-nP", "-iTCP:\(port)", "-sTCP:LISTEN", "-Fpc"]) else { return nil }
            var pid: Int?, command = ""
            for line in out.split(separator: "\n") {
                if line.hasPrefix("p"), pid == nil { pid = Int(line.dropFirst()) }
                if line.hasPrefix("c"), command.isEmpty { command = String(line.dropFirst()) }
            }
            guard let pid else { return nil }
            let cwd = run("/usr/sbin/lsof", ["-a", "-p", "\(pid)", "-d", "cwd", "-Fn"])?
                .split(separator: "\n").first { $0.hasPrefix("n") }.map { String($0.dropFirst()) }
            return Listener(pid: pid, command: command, cwd: cwd)
        }

        private static func run(_ executable: String, _ args: [String]) -> String? {
            guard FileManager.default.isExecutableFile(atPath: executable) else { return nil }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = args
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice
            do { try process.run() } catch { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return process.terminationStatus == 0 ? String(decoding: data, as: UTF8.self) : nil
        }
    }
}
