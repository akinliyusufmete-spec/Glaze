import SwiftUI

struct NotepadView: View {
    @Bindable var model: NotepadModel
    let settings: ToolSettings
    var onClose: () -> Void = {}
    var onColor: () -> Void = {}

    private static let paper = Color(red: 0.99, green: 0.97, blue: 0.91)
    private static let typeEntry = ToolbarEntry(
        id: "note.type", title: "Type", symbol: "text.cursor", fallbackSymbol: "character.cursor.ibeam")
    private static let clearEntry = ToolbarEntry(
        id: "note.clear", kind: .action, title: "Clear ink", symbol: "scribble.variable", fallbackSymbol: "trash")
    private static let drawTools: [ToolbarEntry] = [ToolID.pen, .marker, .highlighter, .eraser].compactMap { id in
        ToolbarEntry.defaults.first { $0.id == id.rawValue }
    }
    private static let undoEntry = ToolbarEntry.defaults.first { $0.id == ToolbarActionID.undo }!
    private static let redoEntry = ToolbarEntry.defaults.first { $0.id == ToolbarActionID.redo }!

    var body: some View {
        let page = model.currentPage
        VStack(spacing: 8) {
            header(page)
            toolRow
            paper(page)
            pageBar
        }
        .padding(10)
        .frame(width: NotepadWindow.size.width, height: NotepadWindow.size.height)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(0.12)))
    }

    // MARK: Pieces

    private func header(_ page: NotePage) -> some View {
        HStack {
            WindowDragHandle()
                .frame(height: 22)
                .overlay(
                    HStack(spacing: 6) {
                        Image(systemName: "line.3.horizontal").font(.system(size: 9)).opacity(0.4)
                        Text("Notepad").font(.system(size: 12, weight: .semibold)).opacity(0.75)
                    }
                    .allowsHitTesting(false)
                )
            Button(action: onClose) { Image(systemName: "xmark").font(.system(size: 11, weight: .bold)) }
                .buttonStyle(.plain)
                .help("Close (⌥⌘N)")
        }
    }

    private var toolRow: some View {
        HStack(spacing: 2) {
            ToolbarButton(entry: Self.typeEntry, isSelected: model.mode == .type, isEnabled: true) {
                model.mode = .type
            }
            ForEach(Self.drawTools) { entry in
                ToolbarButton(entry: entry, isSelected: model.mode.tool?.rawValue == entry.id, isEnabled: true) {
                    if let tool = ToolID(rawValue: entry.id) { model.mode = .draw(tool) }
                }
            }
            Divider().frame(height: 18).padding(.horizontal, 3)
            ToolbarButton(entry: Self.undoEntry, isSelected: false, isEnabled: model.canUndoInk, action: model.undoInk)
            ToolbarButton(entry: Self.redoEntry, isSelected: false, isEnabled: model.canRedoInk, action: model.redoInk)
            ToolbarButton(entry: Self.clearEntry, isSelected: false, isEnabled: model.canUndoInk || !model.currentPage.strokes.isEmpty,
                          action: model.clearInk)
            Spacer(minLength: 0)
            Button(action: onColor) {
                Circle()
                    .fill(settings.strokeColor.swiftUIColor)
                    .overlay(Circle().strokeBorder(Color.primary.opacity(0.35), lineWidth: 1))
                    .frame(width: 20, height: 20)
                    .padding(5)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Ink color")
        }
    }

    private func paper(_ page: NotePage) -> some View {
        ZStack {
            Self.paper
            NoteTextView(initialText: page.text, wantsKeyboard: model.mode == .type) { text in
                model.setText(text, forPage: page.id)
            }
            .id(page.id)
            NoteInkView(store: model.inkStore(for: page.id), registry: model.registry, tool: model.mode.tool)
                .id(page.id)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.black.opacity(0.15)))
    }

    private var pageBar: some View {
        HStack(spacing: 10) {
            Button { model.goPrevious() } label: { Image(systemName: "chevron.left") }
                .disabled(!model.notebook.canGoPrevious)
                .help("Previous page")
            Text("Page \(model.notebook.selectedIndex + 1) of \(model.notebook.pageCount)")
                .font(.system(size: 12)).monospacedDigit().frame(minWidth: 90)
            Button { model.goNext() } label: { Image(systemName: "chevron.right") }
                .disabled(!model.notebook.canGoNext)
                .help("Next page")
            Spacer(minLength: 0)
            Button { model.addPage() } label: { Image(systemName: "plus") }
                .help("New page")
            Button { model.deleteCurrentPage() } label: { Image(systemName: "trash") }
                .help(model.notebook.pageCount == 1 ? "Clear this page" : "Delete this page")
        }
        .buttonStyle(.plain)
    }
}
