import AppKit
import LupitaCore
import SwiftUI

/// The ID report (D40): shows every row in plain language, lets the user remove any, then save
/// the file or prepare an email with it attached. Lupita sends nothing itself (D26).
@MainActor
final class IDReportModel: ObservableObject {
    @Published var rows: [IDReportRow] = []
    @Published var isBuilding = false
    private var savedURL: URL?
    private static let address = "mbarranco+lupita@gmail.com"

    func build(from index: RefIndex?) {
        guard let index else { rows = []; return }
        isBuilding = true
        rows = []
        savedURL = nil
        Task {
            let built = await Task.detached(priority: .userInitiated) { IDReport.build(index: index) }.value
            rows = built
            isBuilding = false
        }
    }

    func remove(_ row: IDReportRow) { rows.removeAll { $0.id == row.id } }

    private var markdown: String { IDReport.markdown(rows: rows, version: Updater.installedVersion) }

    @discardableResult
    func save() -> URL? {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "lupita-id-report.md"
        panel.allowedContentTypes = [.init(filenameExtension: "md") ?? .plainText]
        NSApp.activate()
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return write(to: url)
    }

    private func write(to url: URL) -> URL? {
        do {
            try markdown.write(to: url, atomically: true, encoding: .utf8)
            savedURL = url
            return url
        } catch {
            let alert = NSAlert()
            alert.messageText = S.idReportSaveFailed
            alert.runModal()
            return nil
        }
    }

    /// A new email in the user's mail app with the file attached. If the mail app cannot do that,
    /// a `mailto:` with the subject filled in, and the file shown in Finder to drag into it.
    func prepareEmail() {
        let url: URL
        if let savedURL, FileManager.default.fileExists(atPath: savedURL.path) {
            guard let again = write(to: savedURL) else { return }  // the user may have removed rows since
            url = again
        } else {
            let temp = FileManager.default.temporaryDirectory.appendingPathComponent("lupita-id-report.md")
            guard let written = write(to: temp) else { return }
            url = written
        }
        if let service = NSSharingService(named: .composeEmail), service.canPerform(withItems: [url]) {
            service.recipients = [Self.address]
            service.subject = S.idReportSubject
            service.perform(withItems: [url])
            return
        }
        var parts = URLComponents()
        parts.scheme = "mailto"
        parts.path = Self.address
        parts.queryItems = [URLQueryItem(name: "subject", value: S.idReportSubject)]
        if let mailto = parts.url?.absoluteString.replacingOccurrences(of: "+", with: "%2B"),
           let link = URL(string: mailto) { NSWorkspace.shared.open(link) }
        NSWorkspace.shared.activateFileViewerSelecting([url])
        let hint = NSAlert()
        hint.messageText = S.idReportDrag
        hint.runModal()
    }
}

struct IDReportView: View {
    @ObservedObject var model: IDReportModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(S.idReportIntro).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if model.isBuilding {
                ProgressView(S.idReportBuilding).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if model.rows.isEmpty {
                Text(S.idReportEmpty).foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(model.rows) { row in
                    HStack(alignment: .top) {
                        Text(S.idReportRow(shape: row.shape, prefix: row.prefix, place: S.place(row.place.rawValue),
                                           file: row.fileName, repo: row.repo, ids: row.ids, mentions: row.mentions,
                                           recognised: row.recognised, resolved: row.resolved))
                            .font(.callout).fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 8)
                        Button { model.remove(row) } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.borderless).help(S.idReportRemove)
                            .accessibilityLabel(S.idReportRemove)
                    }
                }
            }
            HStack {
                Text(S.idReportRows(model.rows.count)).foregroundStyle(.secondary)
                Spacer()
                Button(S.idReportSave) { model.save() }.disabled(model.rows.isEmpty)
                Button(S.idReportPrepareEmail) { model.prepareEmail() }
                    .keyboardShortcut(.defaultAction).disabled(model.rows.isEmpty)
            }
        }
        .padding(16)
    }
}

@MainActor
final class IDReportWindow {
    private var window: NSWindow?
    private let model = IDReportModel()

    func show(index: RefIndex?) {
        model.build(from: index)
        if window == nil {
            let host = NSHostingController(rootView: IDReportView(model: model))
            host.sizingOptions = []
            let w = NSWindow(contentViewController: host)
            w.title = S.idReportTitle
            w.styleMask = [.titled, .closable, .resizable]
            w.setContentSize(NSSize(width: 640, height: 600))
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
    }
}
