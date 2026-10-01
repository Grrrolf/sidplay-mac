//
//  BreadcrumbBarView.swift
//  SIDPLAY
//
//  Recreating the classic breadcrumb navigation bar from Screenshot 2:
//  < | > navigation buttons, folder icons path trail, and right action buttons.
//

import SwiftUI

public struct BreadcrumbBarView: View {
    @ObservedObject var library: SIDLibraryManager
    @Binding var showSidebar: Bool
    @Binding var showInspector: Bool
    
    @MainActor
    public init(
        library: SIDLibraryManager = .shared,
        showSidebar: Binding<Bool> = .constant(true),
        showInspector: Binding<Bool>
    ) {
        self.library = library
        self._showSidebar = showSidebar
        self._showInspector = showInspector
    }
    
    public var body: some View {
        HStack(spacing: 8) {
            // Collections Sidebar Toggle Button (matching Inspector button on the right)
            Button(action: {
                withAnimation(.easeInOut(duration: 0.15)) {
                    showSidebar.toggle()
                }
            }) {
                Image(systemName: "sidebar.leading")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(showSidebar ? .accentColor : .secondary)
                    .frame(width: 26, height: 20)
                    .background(showSidebar ? Color.accentColor.opacity(0.18) : Color.clear)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(Color.primary.opacity(0.08))
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(showSidebar ? Color.accentColor.opacity(0.4) : Color.primary.opacity(0.12), lineWidth: 1)
            )
            .keyboardShortcut("s", modifiers: [.command, .control])
            .background(
                Group {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            showSidebar.toggle()
                        }
                    }) {
                        EmptyView()
                    }
                    .keyboardShortcut("s", modifiers: [.command, .option])
                    .opacity(0)
                    .accessibilityHidden(true)
                    
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            showSidebar.toggle()
                        }
                    }) {
                        EmptyView()
                    }
                    .keyboardShortcut("0", modifiers: .command)
                    .opacity(0)
                    .accessibilityHidden(true)
                }
            )
            .help(showSidebar ? "Hide Collections Sidebar (⌃⌘S or ⌥⌘S)" : "Show Collections Sidebar (⌃⌘S or ⌥⌘S)")
            
            // Navigation Back / Forward Buttons (< | >)
            HStack(spacing: 0) {
                Button(action: { library.navigateBack() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 20, height: 18)
                }
                .buttonStyle(.plain)
                .disabled(!library.canNavigateBack)
                .keyboardShortcut("[", modifiers: .command)
                .help("Back (⌘[ or Delete)")
                
                Divider()
                    .frame(height: 12)
                
                Button(action: { library.navigateForward() }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 20, height: 18)
                }
                .buttonStyle(.plain)
                .disabled(!library.canNavigateForward)
                .keyboardShortcut("]", modifiers: .command)
                .help("Forward (⌘])")
            }
            .background(Color.primary.opacity(0.08))
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)
            )
            
            if !library.searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                // MARK: - Search Scope Bar (This Folder vs Entire HVSC)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        Text("Search:")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        
                        // Scope Button 1: Current Open Folder
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.12)) {
                                library.setSearchScope(.folder)
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "folder")
                                    .font(.system(size: 9))
                                Text(library.currentFolderName)
                                    .font(.system(size: 11, weight: library.searchScope == .folder ? .semibold : .regular))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .frame(maxWidth: 130)
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(library.searchScope == .folder ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.06))
                            .foregroundColor(library.searchScope == .folder ? .accentColor : .primary)
                            .cornerRadius(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(library.searchScope == .folder ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .fixedSize()
                        .help("Search only inside the open folder: \(library.currentFolderName)")
                        
                        // Scope Button 2: Entire HVSC Archive
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.12)) {
                                library.setSearchScope(.hvsc)
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "globe")
                                    .font(.system(size: 9))
                                Text("Entire HVSC")
                                    .font(.system(size: 11, weight: library.searchScope == .hvsc ? .semibold : .regular))
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(library.searchScope == .hvsc ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.06))
                            .foregroundColor(library.searchScope == .hvsc ? .accentColor : .primary)
                            .cornerRadius(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(library.searchScope == .hvsc ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .fixedSize()
                        .help("Search through all 61,000+ tunes in the full HVSC archive")
                        
                        Text("•")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary.opacity(0.6))
                            .lineLimit(1)
                        
                        let count = library.displayedCount
                        Text(library.isSearchingAllHVSC && count >= 200 ? "200+ found" : "\(count) found")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .fixedSize()
                        
                        if library.isSearchingHVSC {
                            ProgressView()
                                .scaleEffect(0.5)
                                .frame(width: 10, height: 10)
                        }
                    }
                    .padding(.vertical, 1)
                }
            } else {
                // Breadcrumbs with folder icons
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(Array(library.breadcrumbs.enumerated()), id: \.offset) { index, crumb in
                            if index > 0 {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 8))
                                    .foregroundColor(.secondary.opacity(0.7))
                            }
                            
                            Button(action: { library.navigateTo(path: crumb.path) }) {
                                HStack(spacing: 3) {
                                    Image(systemName: iconForCrumb(index: index, name: crumb.name))
                                        .font(.system(size: 10))
                                        .foregroundColor(index == library.breadcrumbs.count - 1 ? .accentColor : .secondary)
                                    
                                    Text(crumb.name)
                                        .font(.system(size: 11, weight: index == library.breadcrumbs.count - 1 ? .semibold : .regular))
                                        .foregroundColor(index == library.breadcrumbs.count - 1 ? .primary : .secondary)
                                }
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(index == library.breadcrumbs.count - 1 ? Color.primary.opacity(0.06) : Color.clear)
                                .cornerRadius(3)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            
            if case .smartPlaylist = library.selectedSidebarItem {
                Button(action: { library.editSelectedSmartPlaylist() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 10))
                        Text("Edit Rules")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.14))
                    .foregroundColor(.accentColor)
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .help("Edit Smart Playlist Rules")
            }
            
            Spacer()
            
            // Action Button on Right: Inspector Panel Toggle
            Button(action: {
                withAnimation(.easeInOut(duration: 0.15)) {
                    showInspector.toggle()
                }
            }) {
                Image(systemName: "sidebar.trailing")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(showInspector ? .accentColor : .secondary)
                    .frame(width: 26, height: 20)
                    .background(showInspector ? Color.accentColor.opacity(0.18) : Color.clear)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(Color.primary.opacity(0.08))
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(showInspector ? Color.accentColor.opacity(0.4) : Color.primary.opacity(0.12), lineWidth: 1)
            )
            .keyboardShortcut("i", modifiers: .command)
            .help("Toggle Info Inspector Panel (⌘I)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .frame(height: 30)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
    }
    
    private func iconForCrumb(index: Int, name: String) -> String {
        if case .smartPlaylist = library.selectedSidebarItem {
            if index == 0 { return "music.note.list" }
            return "gearshape.fill"
        }
        if case .playlist = library.selectedSidebarItem {
            if index == 0 { return "music.note.list" }
            return "music.note"
        }
        if index == 0 { return "house.fill" }
        if name.uppercased() == "MUSIC" || name.uppercased() == "C64MUSIC" { return "music.note" }
        return "folder.fill"
    }
}
