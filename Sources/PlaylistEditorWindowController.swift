import AppKit
import Observation
import SwiftUI

@MainActor
final class PlaylistEditorWindowController: NSWindowController {

    let state = PlaylistEditorState()

    private let actions = PlaylistEditorActionBridge()

    var onAddVideos: (() -> Void)? {
        get { actions.onAddVideos }
        set { actions.onAddVideos = newValue }
    }

    var onDeleteItem: ((PlaylistItem.ID) -> Void)? {
        get { actions.onDeleteItem }
        set { actions.onDeleteItem = newValue }
    }

    var onMoveItem: ((PlaylistItem.ID, Int) -> Void)? {
        get { actions.onMoveItem }
        set { actions.onMoveItem = newValue }
    }

    var onSetCurrentItem: ((PlaylistItem.ID) -> Void)? {
        get { actions.onSetCurrentItem }
        set { actions.onSetCurrentItem = newValue }
    }

    var onDisplayNameChanged: ((PlaylistItem.ID, String) -> Void)? {
        get { actions.onDisplayNameChanged }
        set { actions.onDisplayNameChanged = newValue }
    }

    var onUseFullVideoChanged: ((PlaylistItem.ID, Bool) -> Void)? {
        get { actions.onUseFullVideoChanged }
        set { actions.onUseFullVideoChanged = newValue }
    }

    var onStartTimeChanged: ((PlaylistItem.ID, Double?) -> Void)? {
        get { actions.onStartTimeChanged }
        set { actions.onStartTimeChanged = newValue }
    }

    var onEndTimeChanged: ((PlaylistItem.ID, Double?) -> Void)? {
        get { actions.onEndTimeChanged }
        set { actions.onEndTimeChanged = newValue }
    }

    var onTimeRangeChanged: ((PlaylistItem.ID, Double?, Double?) -> Void)? {
        get { actions.onTimeRangeChanged }
        set { actions.onTimeRangeChanged = newValue }
    }

    var validateTimeRange: ((PlaylistItem.ID, Double?, Double?, Bool) -> String?)? {
        get { actions.validateTimeRange }
        set { actions.validateTimeRange = newValue }
    }

    init() {
        let hostingController = NSHostingController(
            rootView: PlaylistEditorRootView(state: state, actions: actions)
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 920, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = hostingController
        window.title = String(localized: "playlist_editor.title")
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 920, height: 560))
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func reload(items: [PlaylistItem], currentItemID: PlaylistItem.ID?) {
        state.items = items
        state.currentItemID = currentItemID

        if let selection = state.selection,
           items.contains(where: { $0.id == selection }) {
            return
        }

        state.selection = currentItemID ?? items.first?.id
        state.validationMessage = nil
    }

    func showEditor() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@MainActor
@Observable
final class PlaylistEditorState {
    var items: [PlaylistItem] = []
    var currentItemID: PlaylistItem.ID?
    var selection: PlaylistItem.ID?
    var validationMessage: String?

    var selectedItem: PlaylistItem? {
        guard let selection else { return nil }
        return items.first(where: { $0.id == selection })
    }
}

@MainActor
final class PlaylistEditorActionBridge {

    var onAddVideos: (() -> Void)?
    var onDeleteItem: ((PlaylistItem.ID) -> Void)?
    var onMoveItem: ((PlaylistItem.ID, Int) -> Void)?
    var onSetCurrentItem: ((PlaylistItem.ID) -> Void)?
    var onDisplayNameChanged: ((PlaylistItem.ID, String) -> Void)?
    var onUseFullVideoChanged: ((PlaylistItem.ID, Bool) -> Void)?
    var onStartTimeChanged: ((PlaylistItem.ID, Double?) -> Void)?
    var onEndTimeChanged: ((PlaylistItem.ID, Double?) -> Void)?
    var onTimeRangeChanged: ((PlaylistItem.ID, Double?, Double?) -> Void)?
    var validateTimeRange: ((PlaylistItem.ID, Double?, Double?, Bool) -> String?)?
}

private struct PlaylistEditorRootView: View {

    @Bindable var state: PlaylistEditorState
    let actions: PlaylistEditorActionBridge

    var body: some View {
        NavigationSplitView {
            PlaylistSidebarView(state: state, actions: actions)
                .navigationTitle(String(localized: "playlist_editor.title"))
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            actions.onAddVideos?()
                        } label: {
                            Label(
                                String(localized: "playlist_editor.add_videos"),
                                systemImage: "plus"
                            )
                        }
                    }
                }
        } detail: {
            if let selectedItem = state.selectedItem {
                PlaylistDetailView(state: state, item: selectedItem, actions: actions)
            } else {
                ContentUnavailableView(
                    String(localized: "playlist_editor.empty_state"),
                    systemImage: "music.note.list",
                    description: Text(String(localized: "playlist_editor.empty_state.description"))
                )
            }
        }
    }
}

private struct PlaylistSidebarView: View {

    @Bindable var state: PlaylistEditorState
    let actions: PlaylistEditorActionBridge

    var body: some View {
        List(selection: $state.selection) {
            ForEach(Array(state.items.enumerated()), id: \.element.id) { index, item in
                PlaylistSidebarRow(
                    item: item,
                    index: index,
                    isCurrent: item.id == state.currentItemID
                )
                .tag(item.id)
            }
        }
        .overlay {
            if state.items.isEmpty {
                ContentUnavailableView(
                    String(localized: "playlist_editor.empty_state"),
                    systemImage: "music.note.list"
                )
            }
        }
    }
}

private struct PlaylistSidebarRow: View {

    let item: PlaylistItem
    let index: Int
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text("\(index + 1)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .trailing)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.effectiveDisplayName)
                    .lineLimit(1)
                Text(item.url.lastPathComponent)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if isCurrent {
                Image(systemName: "play.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct PlaylistDetailView: View {

    @Bindable var state: PlaylistEditorState
    let item: PlaylistItem
    let actions: PlaylistEditorActionBridge

    @State private var displayName = ""
    @State private var startTime = ""
    @State private var endTime = ""
    @State private var useFullVideo = true
    @State private var isSyncingDrafts = false

    var body: some View {
        Form {
            Section {
                if let validationMessage = state.validationMessage {
                    Text(validationMessage)
                        .foregroundStyle(.red)
                }

                TextField(
                    String(localized: "playlist_editor.display_name"),
                    text: $displayName
                )

                Toggle(
                    String(localized: "playlist_editor.use_full_video"),
                    isOn: $useFullVideo
                )
            }

            Section(String(localized: "playlist_editor.range_section")) {
                TextField(
                    String(localized: "playlist_editor.start_time"),
                    text: $startTime
                )
                .disabled(useFullVideo)

                TextField(
                    String(localized: "playlist_editor.end_time"),
                    text: $endTime
                )
                .disabled(useFullVideo)

                Text(String(localized: "playlist_editor.range_hint"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    Button(String(localized: "playlist_editor.set_current")) {
                        commitPendingEdits()
                        actions.onSetCurrentItem?(item.id)
                    }

                    Button(String(localized: "playlist_editor.move_up")) {
                        commitPendingEdits()
                        actions.onMoveItem?(item.id, -1)
                    }
                    .disabled(isFirstItem)

                    Button(String(localized: "playlist_editor.move_down")) {
                        commitPendingEdits()
                        actions.onMoveItem?(item.id, 1)
                    }
                    .disabled(isLastItem)

                    Spacer()

                    Button(String(localized: "playlist_editor.delete"), role: .destructive) {
                        commitPendingEdits()
                        actions.onDeleteItem?(item.id)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            syncDrafts(from: item)
        }
        .onChange(of: item) {
            syncDrafts(from: item)
        }
        .onChange(of: displayName) {
            guard !isSyncingDrafts else { return }
            actions.onDisplayNameChanged?(item.id, displayName)
        }
        .onChange(of: useFullVideo) {
            guard !isSyncingDrafts else { return }
            state.validationMessage = nil
            actions.onUseFullVideoChanged?(item.id, useFullVideo)
            if !useFullVideo {
                commitPendingEdits()
            }
        }
        .onChange(of: startTime) {
            guard !isSyncingDrafts else { return }
            commitPendingEdits()
        }
        .onChange(of: endTime) {
            guard !isSyncingDrafts else { return }
            commitPendingEdits()
        }
    }

    private var isFirstItem: Bool {
        state.items.firstIndex(where: { $0.id == item.id }) == 0
    }

    private var isLastItem: Bool {
        guard let index = state.items.firstIndex(where: { $0.id == item.id }) else { return true }
        return index == state.items.count - 1
    }

    private func syncDrafts(from item: PlaylistItem) {
        isSyncingDrafts = true
        defer { isSyncingDrafts = false }

        displayName = item.displayName
        useFullVideo = item.useFullVideo
        startTime = item.startTime.map { Self.secondsFormatter.string(from: NSNumber(value: $0)) ?? "" } ?? ""
        endTime = item.endTime.map { Self.secondsFormatter.string(from: NSNumber(value: $0)) ?? "" } ?? ""
        state.validationMessage = nil
    }

    private func commitPendingEdits() {
        let rangeUpdate = actions.onTimeRangeChanged
        PlaylistEditorTimeRangeCommitter.commit(.init(
            itemID: item.id,
            startText: startTime,
            endText: endTime,
            useFullVideo: useFullVideo,
            validateTimeRange: actions.validateTimeRange,
            setValidationMessage: { state.validationMessage = $0 },
            applyTimeRange: { itemID, start, end in
                if let rangeUpdate {
                    rangeUpdate(itemID, start, end)
                } else {
                    actions.onStartTimeChanged?(itemID, start)
                    actions.onEndTimeChanged?(itemID, end)
                }
            }
        ))
    }

    private static let secondsFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 3
        return formatter
    }()

}

enum PlaylistEditorTimeRangeCommitter {
    struct CommitRequest {
        let itemID: PlaylistItem.ID
        let startText: String
        let endText: String
        let useFullVideo: Bool
        let validateTimeRange: ((PlaylistItem.ID, Double?, Double?, Bool) -> String?)?
        let setValidationMessage: (String?) -> Void
        let applyTimeRange: (PlaylistItem.ID, Double?, Double?) -> Void
    }

    static func commit(_ request: CommitRequest) {
        guard !request.useFullVideo else {
            request.setValidationMessage(nil)
            request.applyTimeRange(request.itemID, nil, nil)
            return
        }

        let trimmedStart = request.startText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEnd = request.endText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let start = Double(trimmedStart),
              let end = Double(trimmedEnd) else {
            request.setValidationMessage(nil)
            return
        }

        if let validationMessage = request.validateTimeRange?(
            request.itemID,
            start,
            end,
            request.useFullVideo
        ) {
            request.setValidationMessage(validationMessage)
            return
        }

        request.setValidationMessage(nil)
        request.applyTimeRange(request.itemID, start, end)
    }
}
