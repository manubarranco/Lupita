import AppKit
import LupitaCore
import SwiftUI

/// One key of the shortcut, drawn as a keycap in the welcome step.
struct KeyLabel: Hashable {
    let symbol: String
    let name: String
}

extension HotkeyChoice {
    var keys: [KeyLabel] {
        switch self {
        case .controlOptionCommand: [.init(symbol: "⌃", name: "control"), .init(symbol: "⌥", name: "option"), .init(symbol: "⌘", name: "command")]
        case .fnControlOption: [.init(symbol: "fn", name: "fn"), .init(symbol: "⌃", name: "control"), .init(symbol: "⌥", name: "option")]
        }
    }
}

/// The welcome step stages the gesture on a sample note (D56): hold the shortcut, point at a reference, let go over
/// it. It uses the real shortcut, the real underline and the real tooltip, but the references and their definitions
/// are its own, so it needs no folders, no OCR and no Screen Recording permission.
@MainActor
final class WelcomeScene: ObservableObject {
    enum Phase { case idle, marks, over }

    static let holdThreshold: Duration = .milliseconds(250)

    @Published private(set) var phase = Phase.idle
    @Published private(set) var holding = false
    @Published private(set) var hovered: String?
    @Published private(set) var hint: String?
    /// A definition has been shown at least once: the gesture is learned.
    @Published private(set) var learned = false
    /// The user is done with the step (continue or skip).
    var onFinish: (() -> Void)?

    private final class WeakView { weak var view: NSView?; init(_ view: NSView) { self.view = view } }

    private let overlay = HighlightOverlay()
    private let tooltip = TooltipPanel()
    private var anchors: [String: WeakView] = [:]
    private var showTask: Task<Void, Never>?
    private var pollTask: Task<Void, Never>?
    private var marksUp = false
    /// Set when the shortcut goes up, read by the release that follows it (`released`).
    private var releaseTarget: String?
    private var wasMarked = false

    func register(_ id: String, _ view: NSView) { anchors[id] = WeakView(view) }

    func reset() {
        stop()
        phase = .idle
        holding = false
        hovered = nil
        hint = nil
        learned = false
    }

    func finish() {
        stop()
        onFinish?()
    }

    private func stop() {
        showTask?.cancel()
        pollTask?.cancel()
        tooltip.close()
        overlay.hide(animated: false)
        marksUp = false
        releaseTarget = nil
        wasMarked = false
    }

    // MARK: The shortcut

    /// The chord went down (true) or up, or was cancelled (false).
    func holdChanged(_ down: Bool) {
        showTask?.cancel()
        pollTask?.cancel()
        if down {
            tooltip.close()
            hint = nil
            holding = true
            releaseTarget = nil
            marksUp = false
            showTask = Task { [weak self] in
                try? await Task.sleep(for: Self.holdThreshold)
                guard !Task.isCancelled else { return }
                self?.showMarks()
            }
        } else {
            holding = false
            wasMarked = marksUp
            releaseTarget = marksUp ? hovered : nil
            marksUp = false
            hovered = nil
            phase = .idle
            overlay.hide()
        }
    }

    /// The chord was let go whole (not cancelled by another key): show what was pointed at.
    func released() {
        defer { releaseTarget = nil; wasMarked = false }
        guard let id = releaseTarget, let definition = Self.definition(id) else {
            hint = wasMarked ? S.welcomeNoTarget : S.welcomeTooShort
            return
        }
        hint = nil
        learned = true
        tooltip.show(.made(query: id, key: id, definitions: [definition]), at: NSEvent.mouseLocation) { [weak self] _ in
            self?.hint = S.welcomeOpened
        }
    }

    static func definition(_ id: String) -> Definition? {
        guard let text = S.welcomeDefinitions[id] else { return nil }
        return .made(id: id, repo: text.repo, path: "docs/decisions.md", line: 1, rule: .heading, title: text.title, summary: text.summary)
    }

    // MARK: Marks and pointer

    /// Underline every reference of the note, with the same line and animation the real hold draws.
    private func showMarks() {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        var marks: [(box: CGRect, onDark: Bool, kind: HighlightPicker.Kind)] = []
        for (_, id, _) in S.welcomeNote {
            guard let view = anchors[id]?.view, let rect = screenRect(of: id) else { continue }
            let box = CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
            let dark = view.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            marks.append((box, dark, .id))
        }
        overlay.show(marks)
        marksUp = true
        phase = .marks
        updateHover()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(40))
                self?.updateHover()
            }
        }
    }

    private func screenRect(of id: String) -> NSRect? {
        guard let view = anchors[id]?.view, let window = view.window, view.bounds.width > 0 else { return nil }
        return window.convertToScreen(view.convert(view.bounds, to: nil))
    }

    private func updateHover() {
        guard marksUp else { return }
        let mouse = NSEvent.mouseLocation
        let hit = S.welcomeNote.map(\.id).first { screenRect(of: $0)?.insetBy(dx: -6, dy: -5).contains(mouse) == true }
        guard hit != hovered else { return }
        hovered = hit
        phase = hit == nil ? .marks : .over
    }
}

// MARK: - View

struct WelcomeStep: View {
    @ObservedObject var scene: WelcomeScene
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text(S.welcomeTitle).font(.title2.weight(.semibold))
                Text(S.welcomeIntro).font(.callout).foregroundStyle(.secondary)
            }
            note
            Spacer(minLength: 0)
            callToAction.frame(maxWidth: .infinity)
            Spacer(minLength: 0)
            HStack {
                if !scene.learned { Button(S.welcomeSkip) { scene.finish() }.buttonStyle(.link) }
                Spacer()
                if scene.learned { Button(S.continueLabel) { scene.finish() }.keyboardShortcut(.defaultAction) }
            }
            .frame(minHeight: 28)
        }
    }

    private var note: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(S.welcomeNoteFile).font(.caption.monospaced()).foregroundStyle(.secondary)
            ForEach(Array(S.welcomeNote.enumerated()), id: \.offset) { _, line in
                HStack(spacing: 0) {
                    Text(line.before)
                    Text(line.id).fontWeight(.medium)
                        .background(Anchor(id: line.id, scene: scene))
                        .padding(.horizontal, 3)
                        .background(RoundedRectangle(cornerRadius: 4).fill(Color.accentColor.opacity(scene.hovered == line.id ? 0.22 : 0)))
                        .accessibilityLabel(line.id)
                    Text(line.after)
                }
                .font(.body)
                .lineLimit(1)
                .fixedSize()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }

    /// The call to action is text, bigger than anything else: it changes as the user does each part of the gesture.
    private var callToAction: some View {
        let (headline, sub, caps): (String, String?, Bool) = {
            if scene.learned { return (S.welcomeDone, scene.hint ?? S.welcomeDoneSub, false) }
            switch scene.phase {
            case .idle: return (S.welcomeHold, scene.hint ?? S.welcomeHoldSub, true)
            case .marks: return (S.welcomePoint, scene.hint ?? S.welcomePointSub, true)
            case .over: return (S.welcomeRelease, nil, true)
            }
        }()
        return VStack(spacing: 14) {
            Text(headline).font(.title.weight(.semibold)).multilineTextAlignment(.center)
            if caps { KeyCaps(held: scene.holding) }
            Text(sub ?? " ").font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(minHeight: 170, alignment: .top)
        .id(scene.learned ? "done" : "\(scene.phase)")
        .transition(.opacity)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: scene.phase)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: scene.learned)
        .accessibilityElement(children: .combine)
    }
}

private struct KeyCaps: View {
    let held: Bool

    var body: some View {
        HStack(spacing: 8) {
            ForEach(HotkeyChoice.current.keys, id: \.self) { key in
                VStack(spacing: 2) {
                    Text(key.symbol).font(.system(size: 26, weight: .medium))
                    Text(key.name).font(.caption2)
                }
                .frame(width: 66, height: 58)
                .foregroundStyle(held ? Color.white : Color.primary)
                .background(RoundedRectangle(cornerRadius: 10).fill(held ? Color.accentColor : Color.primary.opacity(0.08)))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.primary.opacity(held ? 0 : 0.15)))
            }
        }
        .animation(.easeOut(duration: 0.1), value: held)
        .accessibilityHidden(true)
    }
}

/// Reports where its reference is on screen: the scene asks for the frame when it needs it, so a moved window is no problem.
private struct Anchor: NSViewRepresentable {
    let id: String
    let scene: WelcomeScene

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        scene.register(id, view)
        return view
    }

    func updateNSView(_ view: NSView, context: Context) { scene.register(id, view) }
}
