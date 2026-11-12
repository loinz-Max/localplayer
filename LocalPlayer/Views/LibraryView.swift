import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

// MARK: - 长按锚点

private struct CardTarget: Equatable {
    let item: VideoItem
    let rect: CGRect
}

private struct FolderTarget: Equatable {
    let path: String
    let rect: CGRect
}

private enum LibraryPopup: Equatable {
    case importing
    case more
}

private struct CardFrameKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

private struct FolderFrameKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

// MARK: - 资料库

struct LibraryView: View {
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var progress: ProgressStore
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.scenePhase) private var scenePhase

    @State private var playingItem: VideoItem?
    /// 进播放页那一刻的列表顺序：冻结下来，切集时列表就不会把当前视频甩到末尾
    @State private var playingQueue: [VideoItem] = []
    /// 多选模式：由「⋯」菜单里的「全选」进入
    @State private var selecting = false
    @State private var selection: Set<String> = []
    @State private var confirmBatchDelete = false
    @State private var batchMoving = false
    @State private var showFileImporter = false
    @State private var showPhotoPicker = false
    @State private var showSettings = false
    @State private var showNewFolder = false
    @State private var newFolderName = ""

    /// 搜索态：顶栏变输入框，结果跨整个资料库
    @State private var searching = false
    @State private var searchText = ""
    @FocusState private var searchFocused: Bool

    @State private var popup: LibraryPopup?
    @State private var target: CardTarget?
    @State private var folderTarget: FolderTarget?
    /// 长按刚触发时，同一串手势不要再被当成「点空白关闭」
    @State private var menuGuard = Date.distantPast
    @State private var cardFrames: [String: CGRect] = [:]
    @State private var folderFrames: [String: CGRect] = [:]
    /// 刷新缩略图时递增，用来强制 LazyVGrid 重建、重新生成缩略图
    @State private var refreshToken = 0

    @State private var renaming: VideoItem?
    @State private var renameText = ""
    @State private var deleting: VideoItem?

    @State private var renamingFolder: String?
    @State private var folderRenameText = ""
    @State private var deletingFolder: String?
    @State private var movingItem: VideoItem?

    @State private var toastText: String?
    @State private var toastToken = 0

    private let sidePadding: CGFloat = 16
    /// 长按浮起时的放大比例：原位置留空 + 轻微放大 + 投影，读作「这张被拎起来了」
    private static let liftScale: CGFloat = 1.09

    /// 浮层是按中心放大的，视觉边缘比原始 frame 各大出 (scale-1)/2，
    /// 菜单要按这个放大后的边缘让位，否则会贴在卡片上
    private func liftedRect(_ rect: CGRect) -> CGRect {
        let growth = (Self.liftScale - 1) / 2
        return rect.insetBy(dx: -rect.width * growth, dy: -rect.height * growth)
    }
    private let columnSpacing: CGFloat = 12
    private let rowSpacing: CGFloat = 18

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                backgroundLayer

                VStack(spacing: 0) {
                    topBar
                    if library.currentFolder != nil && !searching { breadcrumb }
                    content
                }

                if popup != nil || target != nil || folderTarget != nil {
                    scrim
                }

                if let target {
                    floatingCard(target)
                    cardMenu(target, screen: proxy.size)
                }

                if let folderTarget {
                    floatingFolder(folderTarget)
                    folderMenu(folderTarget, screen: proxy.size)
                }

                if let currentPopup = popup {
                    switch currentPopup {
                    case .importing:
                        ImportMenu(
                            onPhoto: { popup = nil; showPhotoPicker = true },
                            onFile: { popup = nil; showFileImporter = true }
                        )
                        .padding(.top, 60)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.trailing, sidePadding)
                        .transition(.opacity)

                    case .more:
                        MoreMenu(
                            viewMode: settings.libraryView,
                            sortKey: settings.sortKey,
                            ascending: settings.sortAscending,
                            onSelectAll: {
                                popup = nil
                                enterSelectAll()
                            },
                            onCreateFolder: {
                                popup = nil
                                newFolderName = ""
                                showNewFolder = true
                            },
                            onViewMode: { mode in
                                settings.libraryView = mode
                                popup = nil
                            },
                            onNameSort: {
                                popup = nil
                                if settings.sortKey == .name {
                                    settings.sortAscending.toggle()
                                } else {
                                    settings.sortKey = .name
                                    settings.sortAscending = true
                                }
                            },
                            onDateSort: {
                                popup = nil
                                settings.sortKey = .added
                                settings.sortAscending = false
                            }
                        )
                        .padding(.top, 60)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.trailing, sidePadding)
                        .transition(.opacity)
                    }
                }

                toastView
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .coordinateSpace(name: "root")
            .animation(.easeOut(duration: 0.16), value: popup)
            // 长按浮层用带一点回弹的弹簧：卡片「被拎起来」再落定，比纯淡入更有实感
            .animation(.spring(response: 0.30, dampingFraction: 0.86), value: target)
            .animation(.spring(response: 0.30, dampingFraction: 0.86), value: folderTarget)
        }
        // 播放页走同层覆盖而不是 fullScreenCover：
        // 模态控制器会绕开 AppDelegate 的方向掩码，导致「只有播放页能转」。
        .overlay {
            if let item = playingItem {
                PlayerScreen(item: item, queue: playingQueue) {
                    withAnimation(.easeOut(duration: 0.18)) { playingItem = nil }
                }
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .animation(.easeOut(duration: 0.18), value: playingItem?.id)
        // 导入进度贴在底部，不铺遮罩：导入期间照样能滑、能点开视频。
        // 位置和 toast 一致，导入结束的汇总提示正好接在同一处。
        .overlay(alignment: .bottom) {
            if let importProgress = library.importProgress {
                ImportProgressHUD(progress: importProgress)
                    .padding(.bottom, 28)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(20)
            }
        }
        .animation(.easeOut(duration: 0.22), value: library.importProgress == nil)
        .overlay(alignment: .bottom) {
            if selecting {
                selectionBar
            }
        }
        .onAppear {
            library.reload()
            progress.refresh()
            applyDebugRoute()
        }
        .onChange(of: scenePhase) { _, phase in
            // 从爱思助手 / 文件 App / iCloud 拷完文件切回来，重新扫一遍
            guard phase == .active else { return }
            library.reload()
            progress.refresh()
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.movie, .video, .item],
            allowsMultipleSelection: true
        ) { result in
            handleFileImport(result)
        }
        .sheet(isPresented: $showPhotoPicker) {
            // 用 PHPicker 才能拿到相册里的原文件名
            PhotoPickerSheet { movies in
                showPhotoPicker = false
                guard !movies.isEmpty else { return }
                importMovies(movies)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .alert("新建文件夹", isPresented: $showNewFolder) {
            TextField("文件夹名称", text: $newFolderName)
            Button("取消", role: .cancel) { newFolderName = "" }
            Button("创建") {
                library.createFolder(newFolderName)
                newFolderName = ""
                toast("已创建文件夹")
            }
        }
        .alert("重命名", isPresented: renameBinding) {
            TextField("文件名", text: $renameText)
            Button("取消", role: .cancel) { renaming = nil }
            Button("保存") { commitRename() }
        } message: {
            Text("会同时改磁盘上的文件名，扩展名保留")
        }
        .alert(
            "删除「\(deleting?.displayName ?? "")」？",
            isPresented: deleteBinding,
            presenting: deleting
        ) { item in
            Button("取消", role: .cancel) { deleting = nil }
            Button("删除", role: .destructive) {
                progress.forget(id: item.id)
                library.delete(item)
                deleting = nil
                toast("已删除")
            }
        } message: { _ in
            Text("文件会从本机移除，这个操作不能撤销。")
        }
        .alert("重命名文件夹", isPresented: folderRenameBinding) {
            TextField("显示名称", text: $folderRenameText)
            Button("取消", role: .cancel) { renamingFolder = nil }
            Button("保存") { commitFolderRename() }
        } message: {
            Text("只改显示名，磁盘上的目录名不变，里面的视频不受影响。")
        }
        .alert(
            "删除文件夹「\(deletingFolderName)」？",
            isPresented: folderDeleteBinding,
            presenting: deletingFolder
        ) { path in
            Button("取消", role: .cancel) { deletingFolder = nil }
            Button("删除", role: .destructive) { deleteSelectedFolder(path) }
        } message: { path in
            Text("文件夹里的 \(library.itemsInside(path).count) 个视频会一起从本机移除，这个操作不能撤销。")
        }
        .sheet(item: $movingItem) { item in
            MoveFolderSheet(
                subtitle: item.name,
                currentFolder: item.folder,
                choices: library.folderChoices
            ) { path in
                moveItem(item, to: path)
            }
        }
        .sheet(isPresented: $batchMoving) {
            MoveFolderSheet(
                subtitle: "已选 \(selection.count) 个视频",
                currentFolder: library.currentFolder ?? "",
                choices: library.folderChoices
            ) { path in
                batchMoving = false
                batchMove(to: path)
            }
        }
        .alert("删除选中的 \(selection.count) 个视频？", isPresented: $confirmBatchDelete) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) { batchDelete() }
        } message: {
            Text("文件会从本机移除，这个操作不能撤销。")
        }
    }

    // MARK: - 顶栏

    private var topBar: some View {
        Group {
            if searching {
                searchBar
            } else {
                // 标题单独占一层固定在屏幕正中，不随两侧按钮数量偏移
                ZStack {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Palette.text)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.horizontal, 92)

                    HStack(spacing: 8) {
                        GlassIconButton(systemName: "magnifyingglass", size: 36, iconSize: 17) {
                            beginSearch()
                        }
                        GlassIconButton(systemName: "gearshape", size: 36, iconSize: 17) {
                            showSettings = true
                        }

                        Spacer(minLength: 0)

                        GlassIconButton(systemName: "arrow.down.doc", size: 36, iconSize: 17) {
                            popup = popup == .importing ? nil : .importing
                        }
                        GlassIconButton(systemName: "ellipsis", size: 36, iconSize: 17) {
                            popup = popup == .more ? nil : .more
                        }
                    }
                }
            }
        }
        .padding(.horizontal, sidePadding)
        .frame(height: 54)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Palette.tertiaryText)

                TextField("搜索全部视频", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .foregroundStyle(Palette.text)
                    .tint(Palette.accent)
                    .focused($searchFocused)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Palette.tertiaryText)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            }

            Button {
                endSearch()
            } label: {
                Text("取消")
                    .font(.system(size: 15))
                    .foregroundStyle(Palette.accent)
            }
            .buttonStyle(.plain)
        }
    }

    private var title: String {
        if selecting { return "已选 \(selection.count) 个" }
        guard let folder = library.currentFolder else { return "Interlude" }
        return library.displayName(forFolder: folder)
    }

    private var breadcrumb: some View {
        HStack(spacing: 4) {
            Button {
                library.currentFolder = nil
            } label: {
                HStack(spacing: 2) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Interlude")
                        .font(.system(size: 14))
                }
                .foregroundStyle(Palette.accent)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, sidePadding)
        .padding(.bottom, 8)
    }

    // MARK: - 网格

    private var content: some View {
        Group {
            if searching {
                searchContent
            } else if library.subfolders.isEmpty && sortedVideos.isEmpty {
                emptyState
            } else if settings.libraryView == .list {
                videoList
            } else {
                grid
            }
        }
        .onPreferenceChange(CardFrameKey.self) { cardFrames = $0 }
        .onPreferenceChange(FolderFrameKey.self) { folderFrames = $0 }
    }

    /// 搜索态下的三种结果：还没输入 / 没有匹配 / 有结果
    private var searchContent: some View {
        Group {
            if trimmedQuery.isEmpty {
                searchHint
            } else if searchResults.isEmpty {
                searchNoResults
            } else if settings.libraryView == .list {
                videoList
            } else {
                grid
            }
        }
    }

    /// 搜索时跨整个资料库，平时只看当前目录
    private var activeVideos: [VideoItem] {
        searching ? searchResults : sortedVideos
    }

    private var activeFolders: [String] {
        searching ? [] : library.subfolders
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: columnSpacing),
                    GridItem(.flexible(), spacing: columnSpacing)
                ],
                alignment: .leading,
                spacing: rowSpacing
            ) {
                ForEach(activeFolders, id: \.self) { folder in
                    FolderCard(
                        name: library.displayName(forFolder: folder),
                        count: count(in: folder)
                    )
                    .background {
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: FolderFrameKey.self,
                                value: [folder: geo.frame(in: .named("root"))]
                            )
                        }
                    }
                    .onTapGesture {
                        if folderTarget != nil || target != nil {
                            if Date().timeIntervalSince(menuGuard) > 0.35 { closeMenus() }
                        } else {
                            library.currentFolder = folder
                        }
                    }
                    .onLongPressGesture(minimumDuration: 0.38) {
                        openFolderMenu(folder)
                    }
                    .opacity(folderTarget?.path == folder ? 0 : 1)
                }

                ForEach(activeVideos) { item in
                    card(item)
                }
            }
            .id(refreshToken)
            .padding(.horizontal, sidePadding)
            .padding(.top, 14)
            .padding(.bottom, 40)
        }
        .scrollDismissesKeyboard(.immediately)
        .refreshable {
            // 下拉兜底：文件系统监听万一没收到事件，手动也能拉一次
            library.reload()
            progress.refresh()
        }
    }

    private func card(_ item: VideoItem) -> some View {
        VideoCard(
            item: item,
            fraction: progress.progressFraction(for: item.id),
            watched: progress.isWatched(item.id),
            active: target?.item.id == item.id,
            selected: selection.contains(item.id),
            folderName: searching ? folderLabel(for: item) : nil
        )
        .background {
            GeometryReader { geo in
                Color.clear.preference(
                    key: CardFrameKey.self,
                    value: [item.id: geo.frame(in: .named("root"))]
                )
            }
        }
        .onTapGesture {
            if selecting {
                toggleSelection(item.id)
                return
            }
            if target != nil || folderTarget != nil {
                if Date().timeIntervalSince(menuGuard) > 0.35 { closeMenus() }
            } else {
                playingQueue = activeVideos
                withAnimation(.easeOut(duration: 0.18)) { playingItem = item }
            }
        }
        .onLongPressGesture(minimumDuration: 0.38) {
            if selecting {
                toggleSelection(item.id)
            } else {
                openCardMenu(item)
            }
        }
        // 浮层已经替代了它，原位留空，避免两张卡叠在一起露出错位边缘
        .opacity(target?.item.id == item.id ? 0 : 1)
    }

    // MARK: - 列表视图

    private var videoList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(activeFolders, id: \.self) { folder in
                    folderRow(folder)
                    Rectangle()
                        .fill(Palette.hairline)
                        .frame(height: 0.5)
                        .padding(.leading, sidePadding + 108)
                }

                ForEach(activeVideos) { item in
                    listRow(item)
                    Rectangle()
                        .fill(Palette.hairline)
                        .frame(height: 0.5)
                        .padding(.leading, sidePadding + 108)
                }
            }
            .padding(.horizontal, sidePadding)
            .padding(.top, 8)
            .padding(.bottom, selecting ? 96 : 40)
        }
        .scrollDismissesKeyboard(.immediately)
        .refreshable {
            library.reload()
            progress.refresh()
        }
    }

    private func folderRow(_ folder: String) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Palette.accent.opacity(0.9))
                }
                .frame(width: 96, height: 54)

            VStack(alignment: .leading, spacing: 3) {
                Text(library.displayName(forFolder: folder))
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(Palette.text)
                    .lineLimit(1)
                Text("\(count(in: folder)) 个视频")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.secondaryText)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.tertiaryText)
        }
        .padding(.vertical, 7)
        .contentShape(Rectangle())
        .onTapGesture {
            if folderTarget != nil || target != nil {
                if Date().timeIntervalSince(menuGuard) > 0.35 { closeMenus() }
            } else {
                library.currentFolder = folder
            }
        }
        .onLongPressGesture(minimumDuration: 0.38) {
            openFolderMenu(folder)
        }
        .opacity(folderTarget?.path == folder ? 0 : 1)
    }

    private func listRow(_ item: VideoItem) -> some View {
        VideoRow(
            item: item,
            fraction: progress.progressFraction(for: item.id),
            watched: progress.isWatched(item.id),
            selected: selection.contains(item.id),
            folderName: searching ? folderLabel(for: item) : nil
        )
        .background {
            GeometryReader { geo in
                Color.clear.preference(
                    key: CardFrameKey.self,
                    value: [item.id: geo.frame(in: .named("root"))]
                )
            }
        }
        .onTapGesture {
            if selecting {
                toggleSelection(item.id)
                return
            }
            if target != nil || folderTarget != nil {
                if Date().timeIntervalSince(menuGuard) > 0.35 { closeMenus() }
            } else {
                playingQueue = activeVideos
                withAnimation(.easeOut(duration: 0.18)) { playingItem = item }
            }
        }
        .onLongPressGesture(minimumDuration: 0.38) {
            if selecting {
                toggleSelection(item.id)
            } else {
                openCardMenu(item)
            }
        }
        // 浮层已经替代了它，原位留空，避免两张卡叠在一起露出错位边缘
        .opacity(target?.item.id == item.id ? 0 : 1)
    }

    // MARK: - 多选

    private var selectionBar: some View {
        HStack(spacing: 10) {
            Button {
                toggleSelectAll()
            } label: {
                Text(selection.count == sortedVideos.count ? "取消全选" : "全选")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Palette.text)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .glass(Capsule())
            }
            .buttonStyle(.plain)

            Button {
                guard !selection.isEmpty else { return }
                batchMoving = true
            } label: {
                Text("移动")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Palette.text)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .glass(Capsule())
            }
            .buttonStyle(.plain)

            Button {
                guard !selection.isEmpty else { return }
                confirmBatchDelete = true
            } label: {
                Text("删除")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.danger)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .glass(Capsule())
            }
            .buttonStyle(.plain)

            Button {
                exitSelection()
            } label: {
                Text("完成")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Palette.accent, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, sidePadding)
        .padding(.bottom, 24)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func enterSelectAll() {
        withAnimation(.easeOut(duration: 0.16)) {
            selecting = true
            selection = Set(sortedVideos.map(\.id))
        }
    }

    private func exitSelection() {
        withAnimation(.easeOut(duration: 0.16)) {
            selecting = false
            selection.removeAll()
        }
    }

    private func toggleSelection(_ id: String) {
        if selection.contains(id) {
            selection.remove(id)
        } else {
            selection.insert(id)
        }
    }

    private func toggleSelectAll() {
        if selection.count == sortedVideos.count {
            selection.removeAll()
        } else {
            selection = Set(sortedVideos.map(\.id))
        }
    }

    private func batchDelete() {
        let victims = selection
        for id in victims { progress.forget(id: id) }
        let removed = library.deleteMany(ids: victims)
        exitSelection()
        toast(removed > 0 ? "已删除 \(removed) 个视频" : "删除失败")
    }

    private func batchMove(to path: String) {
        var moved = 0
        for id in selection {
            guard let item = library.allItems.first(where: { $0.id == id }) else { continue }
            let oldID = item.id
            if let newItem = library.move(item, to: path) {
                progress.renamePath(from: oldID, to: newItem.id)
                moved += 1
            }
        }
        exitSelection()
        let name = path.isEmpty ? "资料库" : library.displayName(forFolder: path)
        toast(moved > 0 ? "已移动 \(moved) 个视频到「\(name)」" : "没有移动任何文件")
    }

    private func count(in folder: String) -> Int {
        library.allItems.filter { $0.folder == folder || $0.folder.hasPrefix(folder + "/") }.count
    }

    // MARK: - 搜索

    private var trimmedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 跨整个资料库的按名搜索，结果按名称自然序
    private var searchResults: [VideoItem] {
        let q = trimmedQuery
        guard !q.isEmpty else { return [] }
        return library.allItems
            .filter {
                $0.displayName.localizedCaseInsensitiveContains(q)
                    || $0.relativePath.localizedCaseInsensitiveContains(q)
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func folderLabel(for item: VideoItem) -> String {
        item.folder.isEmpty ? "根目录" : library.displayName(forFolder: item.folder)
    }

    private func beginSearch() {
        popup = nil
        closeMenus()
        if selecting { exitSelection() }
        withAnimation(.easeOut(duration: 0.16)) { searching = true }
        // 等顶栏换成输入框之后再抢焦点，否则焦点会落在已经消失的视图上
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { searchFocused = true }
    }

    private func endSearch() {
        searchFocused = false
        withAnimation(.easeOut(duration: 0.16)) {
            searching = false
            searchText = ""
        }
    }

    private var searchHint: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Palette.tertiaryText)

            Text("搜索全部视频")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.text)
                .padding(.top, 2)

            Text("资料库里共 \(library.allItems.count) 个视频\n按文件名搜索，不受当前文件夹限制")
                .font(.system(size: 12.5))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .foregroundStyle(Palette.tertiaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
        .padding(.bottom, 80)
    }

    private var searchNoResults: some View {
        VStack(spacing: 10) {
            Image(systemName: "questionmark.folder")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(Palette.tertiaryText)

            Text("没有匹配的视频")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.text)
                .padding(.top, 2)

            Text("「\(trimmedQuery)」在 \(library.allItems.count) 个视频里都没找到\n换个关键词试试")
                .font(.system(size: 12.5))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .foregroundStyle(Palette.tertiaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
        .padding(.bottom, 80)
    }

    /// 文件夹排在前面，视频按当前排序规则
    private var sortedVideos: [VideoItem] {        let list = library.items
        let key = settings.sortKey
        let asc = settings.sortAscending

        return list.sorted { a, b in
            let forward: Bool
            switch key {
            case .recent:
                let ra = progress.recencyRank(a.id)
                let rb = progress.recencyRank(b.id)
                if ra != rb {
                    forward = ra < rb
                } else {
                    forward = a.modified > b.modified
                }
            case .name:
                forward = a.name.localizedStandardCompare(b.name) == .orderedAscending
            case .added:
                forward = a.modified > b.modified
            case .size:
                if a.fileSize != b.fileSize {
                    forward = a.fileSize < b.fileSize
                } else {
                    forward = a.name.localizedStandardCompare(b.name) == .orderedAscending
                }
            }
            return asc ? forward : !forward
        }
    }

    // MARK: - 长按菜单

    private var scrim: some View {
        Color.black.opacity(0.38)
            .ignoresSafeArea()
            .transition(.opacity)
            .onTapGesture {
                guard Date().timeIntervalSince(menuGuard) > 0.35 else { return }
                closeMenus()
                popup = nil
            }
    }

    /// 被长按的卡片浮在遮罩之上，保持清晰
    /// 被长按的卡片浮在遮罩之上：原位置留空，浮层从原尺寸放大到 1.06 并带投影
    private func floatingCard(_ target: CardTarget) -> some View {
        VideoCard(
            item: target.item,
            fraction: progress.progressFraction(for: target.item.id),
            watched: progress.isWatched(target.item.id),
            active: true,
            lifted: true
        )
        .frame(width: target.rect.width, alignment: .top)
        .scaleEffect(Self.liftScale)
        .position(x: target.rect.midX, y: target.rect.midY)
        .allowsHitTesting(false)
        .transition(.scale(scale: 1 / Self.liftScale).combined(with: .opacity))
    }

    private func floatingFolder(_ target: FolderTarget) -> some View {
        FolderCard(
            name: library.displayName(forFolder: target.path),
            count: count(in: target.path),
            lifted: true
        )
        .frame(width: target.rect.width, alignment: .top)
        .scaleEffect(Self.liftScale)
        .position(x: target.rect.midX, y: target.rect.midY)
        .allowsHitTesting(false)
        .transition(.scale(scale: 1 / Self.liftScale).combined(with: .opacity))
    }

    private func cardMenu(_ target: CardTarget, screen: CGSize) -> some View {
        let width = CardMenu.width
        let height = CardMenu.estimatedHeight
        let rect = liftedRect(target.rect)
        let x = min(max(sidePadding, rect.minX), max(sidePadding, screen.width - sidePadding - width))
        var y = rect.maxY + 8
        if y + height > screen.height - 16 {
            y = rect.minY - height - 8
        }
        y = max(16, y)

        return CardMenu(
            item: target.item,
            watched: progress.isWatched(target.item.id),
            onMarkWatched: {
                progress.setWatched(target.item.id, !progress.isWatched(target.item.id))
                closeCardMenu()
            },
            onRename: {
                renameText = target.item.displayName
                renaming = target.item
                closeCardMenu()
            },
            onMove: {
                movingItem = target.item
                closeCardMenu()
            },
            onDelete: {
                deleting = target.item
                closeCardMenu()
            }
        )
        .position(x: x + width / 2, y: y + height / 2)
        .transition(.opacity)
    }

    private func folderMenu(_ target: FolderTarget, screen: CGSize) -> some View {
        let width = FolderMenu.width
        let height = FolderMenu.estimatedHeight
        let rect = liftedRect(target.rect)
        let x = min(max(sidePadding, rect.minX), max(sidePadding, screen.width - sidePadding - width))
        var y = rect.maxY + 8
        if y + height > screen.height - 16 {
            y = rect.minY - height - 8
        }
        y = max(16, y)

        return FolderMenu(
            name: library.displayName(forFolder: target.path),
            onRename: {
                folderRenameText = library.displayName(forFolder: target.path)
                renamingFolder = target.path
                closeMenus()
            },
            onDelete: {
                deletingFolder = target.path
                closeMenus()
            }
        )
        .position(x: x + width / 2, y: y + height / 2)
        .transition(.opacity)
    }

    private func openCardMenu(_ item: VideoItem) {
        popup = nil
        folderTarget = nil
        menuGuard = Date()
        let rect = cardFrames[item.id] ?? .zero
        withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
            target = CardTarget(item: item, rect: rect)
        }
    }

    private func openFolderMenu(_ path: String) {
        popup = nil
        target = nil
        menuGuard = Date()
        let rect = folderFrames[path] ?? .zero
        withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
            folderTarget = FolderTarget(path: path, rect: rect)
        }
    }

    private func closeCardMenu() {
        withAnimation(.easeOut(duration: 0.14)) { target = nil }
    }

    private func closeMenus() {
        withAnimation(.easeOut(duration: 0.14)) {
            target = nil
            folderTarget = nil
        }
    }

    // MARK: - 空状态

    private var emptyState: some View {
        VStack(spacing: 10) {
            if library.currentFolder != nil {
                Text("这个文件夹里还没有视频")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Palette.text)

                Text("点右上角的导入按钮\n导入的视频会放进这个文件夹")
                    .font(.system(size: 12.5))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .foregroundStyle(Palette.tertiaryText)
            } else {
                Text("还没有视频")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Palette.text)

                Text("点右上角的导入按钮\n视频只存在本机，不联网、不上传")
                    .font(.system(size: 12.5))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .foregroundStyle(Palette.tertiaryText)
            }
        }
        // 不套卡片框，也不放任何按钮：空目录只用一句话说清楚
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }

    // MARK: - 背景

    /// 纯黑背景上玻璃永远是黑的 —— 没有东西可透，材质就看不出层次。
    /// 顶部压一层极淡的白雾（2.8%），控件下面才有底色可模糊，整页也不至于死黑。
    private var backgroundLayer: some View {
        Palette.background
            .overlay {
                LinearGradient(
                    colors: [Color.white.opacity(0.028), .clear],
                    startPoint: .top,
                    endPoint: .init(x: 0.5, y: 0.42)
                )
            }
            .ignoresSafeArea()
    }

    // MARK: - 浮层

    @ViewBuilder
    private var toastView: some View {
        if let toastText {
            HUDLabel(text: toastText)
                .padding(.bottom, 28)
                .transition(.opacity)
                .allowsHitTesting(false)
        }
    }

    // MARK: - 绑定

    private var renameBinding: Binding<Bool> {
        Binding(
            get: { renaming != nil },
            set: { if !$0 { renaming = nil } }
        )
    }

    private var deleteBinding: Binding<Bool> {
        Binding(
            get: { deleting != nil },
            set: { if !$0 { deleting = nil } }
        )
    }

    private var folderRenameBinding: Binding<Bool> {
        Binding(
            get: { renamingFolder != nil },
            set: { if !$0 { renamingFolder = nil } }
        )
    }

    private var folderDeleteBinding: Binding<Bool> {
        Binding(
            get: { deletingFolder != nil },
            set: { if !$0 { deletingFolder = nil } }
        )
    }

    private var deletingFolderName: String {
        guard let path = deletingFolder else { return "" }
        return library.displayName(forFolder: path)
    }

    // MARK: - 动作

    private func commitRename() {
        guard let item = renaming else { return }
        let oldID = item.id
        renaming = nil
        guard let renamed = library.rename(item, to: renameText) else {
            toast("重命名失败，可能有同名文件")
            return
        }
        progress.renamePath(from: oldID, to: renamed.id)
        toast("已重命名")
    }

    private func commitFolderRename() {
        guard let path = renamingFolder else { return }
        renamingFolder = nil
        library.renameFolder(path, to: folderRenameText)
        toast("已重命名")
    }

    private func deleteSelectedFolder(_ path: String) {
        let victims = library.itemsInside(path)
        for item in victims { progress.forget(id: item.id) }
        let removed = library.deleteFolder(path)
        if library.currentFolder == path { library.currentFolder = nil }
        deletingFolder = nil
        toast(removed > 0 ? "已删除文件夹（含 \(removed) 个视频）" : "已删除空文件夹")
    }

    private func moveItem(_ item: VideoItem, to path: String) {
        guard path != item.folder else { return }
        let oldID = item.id
        guard let moved = library.move(item, to: path) else {
            toast("移动失败，目标里可能有同名文件")
            return
        }
        progress.renamePath(from: oldID, to: moved.id)
        let name = path.isEmpty ? "资料库" : library.displayName(forFolder: path)
        toast("已移到「\(name)」")
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard !urls.isEmpty else { return }
            Task {
                let outcome = await library.importItems(urls.map { ImportItem(url: $0) })
                toast(outcome.summary)
            }
        case .failure:
            toast("导入失败")
        }
    }

    private func importMovies(_ movies: [PickedMovie]) {
        guard !movies.isEmpty else { return }
        Task {
            let outcome = await library.importItems(
                movies.map { ImportItem(url: $0.url, preferredName: $0.name, moving: true) }
            )
            toast(outcome.summary)
        }
    }

    private func toast(_ text: String) {
        toastToken += 1
        let token = toastToken
        withAnimation(.easeOut(duration: 0.15)) { toastText = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            if toastToken == token {
                withAnimation(.easeIn(duration: 0.2)) { toastText = nil }
            }
        }
    }

    // MARK: - 调试直达

    #if DEBUG
    /// 截图用：给前几个视频写一点进度，用来核对角标
    private func seedDebugProgressIfNeeded() {
        guard DebugSeed.argument(after: "-seedProgress") == "1" else { return }
        let items = library.allItems.filter { $0.folder.isEmpty }
        guard items.count >= 3 else { return }
        progress.update(id: items[0].id, time: 3.4, total: 8)
        progress.update(id: items[1].id, time: 6.2, total: 8)
        progress.setWatched(items[2].id, true)
    }
    #endif

    private func applyDebugRoute() {
        #if DEBUG
        seedDebugProgressIfNeeded()
        guard let route = DebugSeed.argument(after: "-screen") else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            switch route {
            case "player":
                if let first = library.allItems.first {
                    if !first.folder.isEmpty { library.currentFolder = first.folder }
                    playingQueue = sortedVideos
                    playingItem = first
                }
            case "folder":
                if let first = library.subfolders.first { library.currentFolder = first }
            case "settings":
                showSettings = true
            case "search":
                searchText = DebugSeed.argument(after: "-query") ?? "示例"
                beginSearch()
            case "foldermenu":
                // 等卡片布局完成、folderFrames 有值之后再弹菜单，否则锚点是 .zero
                if let first = library.subfolders.first {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        openFolderMenu(first)
                    }
                }
            case "cardmenu":
                // 视频卡片的长按菜单（缩略图浮起的另一种形态）
                if let first = library.allItems.first {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        openCardMenu(first)
                    }
                }
            case "list":
                settings.libraryView = .list
            case "select":
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { enterSelectAll() }
            case "more":
                popup = .more
            case "move":
                if let first = library.allItems.first {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        movingItem = first
                    }
                }
            default:
                break
            }
        }
        #endif
    }
}
