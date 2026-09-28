import SwiftUI
import AppKit

struct ClipboardView: View {
    @ObservedObject var manager = ClipboardManager.shared
    @ObservedObject var quickAI = QuickAIEngine.shared
    @ObservedObject var localization = LocalizationManager.shared
    @State private var copiedId: UUID?
    
    var body: some View {
        ZStack {
            VStack(spacing: 8) {
                // V2 Module Header
                V2ModuleHeader(
                    tab: .clipboard,
                    statusText: "\(manager.filteredItems.count) \(loc("ITEMS", "ЗАПИСЕЙ"))"
                ) {
                    // Quick AI Query Field
                    HStack(spacing: 5) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 9))
                            .foregroundStyle(V2Colors.ice1)
                        TextField(loc("Ask AI...", "Спросить AI..."), text: $quickAI.quickPromptQuery)
                            .textFieldStyle(.plain)
                            .font(.system(size: 9.5, design: .monospaced))
                            .foregroundStyle(V2Colors.milk)
                            .onSubmit {
                                quickAI.submitQuickPrompt()
                            }
                    }
                    .padding(.vertical, 3)
                    .padding(.horizontal, 7)
                    .frame(width: 135)
                    .heroInputBox(cornerRadius: 6)
                    
                    // Search Bar
                    HStack(spacing: 5) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 9.5))
                            .foregroundStyle(V2Colors.faint)
                        
                        TextField(loc("Search...", "Поиск..."), text: $manager.searchQuery)
                            .textFieldStyle(.plain)
                            .font(.system(size: 9.5, design: .monospaced))
                            .foregroundStyle(V2Colors.milk)
                    }
                    .padding(.vertical, 3)
                    .padding(.horizontal, 7)
                    .frame(width: 125)
                    .heroInputBox(cornerRadius: 6)
                    
                    V2GlassButton(title: loc("Clear", "Очистить"), icon: "trash") {
                        withAnimation {
                            manager.clearUnpinned()
                        }
                    }
                }
                
                // Items List
                if manager.filteredItems.isEmpty {
                    VStack(spacing: 6) {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 26))
                            .foregroundStyle(V2Colors.ice.opacity(0.4))
                            .shadow(color: V2Colors.ice.opacity(0.2), radius: 6)
                        
                        Text(loc("Clipboard is empty", "Буфер обмена пуст"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(V2Colors.milk)
                        
                        Text(loc("Copied text and code snippets will appear here automatically", "Скопированный текст и фрагменты кода появятся здесь автоматически"))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(V2Colors.faint)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.bottom, 8)
                } else {
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(spacing: 6) {
                            ForEach(manager.filteredItems) { item in
                                ClipboardRowView(item: item, copiedId: $copiedId)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                    }
                }
            }
            
            // Inline AI Result Modal Overlay
            if quickAI.isPresented {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring) {
                            quickAI.isPresented = false
                        }
                    }
                
                AIResultModalView()
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
            }
        }
    }
}

struct ClipboardRowView: View {
    let item: ClipboardItem
    @Binding var copiedId: UUID?
    @ObservedObject var manager = ClipboardManager.shared
    @ObservedObject var localization = LocalizationManager.shared
    @State private var isHovered = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Icon
            Image(systemName: item.isPinned ? "pin.fill" : (item.isCodeSnippet ? "curlybraces" : "text.alignleft"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(item.isPinned ? Color.orange : (item.isCodeSnippet ? Color.cyan : Color.white.opacity(0.8)))
                .shadow(color: (item.isPinned ? Color.orange : (item.isCodeSnippet ? Color.cyan : Color.white)).opacity(0.3), radius: 4)
                .padding(.top, 2)
            
            // Text Preview
            VStack(alignment: .leading, spacing: 2) {
                Text(item.preview)
                    .font(.system(size: 11, design: item.isCodeSnippet ? .monospaced : .default))
                    .lineLimit(2)
                    .foregroundStyle(.white)
                
                HStack(spacing: 5) {
                    Text(item.timestamp, style: .time)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(V2Colors.faint)
                    
                    if item.isCodeSnippet {
                        V2Chip("Code", style: .ice)
                    }
                }
            }
            
            Spacer()
            
            // 1-Click AI actions & Quick buttons
            HStack(spacing: 5) {
                if item.isCodeSnippet {
                    Button(action: {
                        QuickAIEngine.shared.executeAction(.explain, on: item.content)
                    }) {
                        HStack(spacing: 2) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 8))
                            Text(loc("Explain", "Объяснить"))
                                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        }
                        .padding(.vertical, 3)
                        .padding(.horizontal, 6)
                        .background(V2Colors.ice.opacity(0.16))
                        .foregroundStyle(V2Colors.ice1)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help(loc("Explain this code with AI", "Объяснить этот код с помощью AI"))
                } else {
                    Button(action: {
                        QuickAIEngine.shared.executeAction(.summarize, on: item.content)
                    }) {
                        HStack(spacing: 2) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 8))
                            Text(loc("Summary", "Саммари"))
                                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        }
                        .padding(.vertical, 3)
                        .padding(.horizontal, 6)
                        .background(Color.white.opacity(0.08))
                        .foregroundStyle(V2Colors.milk)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help(loc("Summarize text with AI", "Сделать саммари текста"))
                    
                    Button(action: {
                        QuickAIEngine.shared.executeAction(.translate, on: item.content)
                    }) {
                        Text("RU↔EN")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .padding(.vertical, 3)
                            .padding(.horizontal, 5)
                            .background(Color.white.opacity(0.06))
                            .foregroundStyle(V2Colors.dim)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help(loc("Quick RU ↔ EN translation", "Быстрый перевод RU ↔ EN"))
                }
                
                // Save to Apple Notes
                Button(action: {
                    let firstLine = item.content.components(separatedBy: .newlines).first ?? loc("Note", "Заметка")
                    let title = String(firstLine.prefix(45))
                    AppleNotesManager.shared.createNote(title: title, content: item.content)
                }) {
                    Image(systemName: "note.text.badge.plus")
                        .font(.system(size: 9.5))
                        .foregroundStyle(V2Colors.amber)
                        .padding(4)
                        .background(Circle().fill(V2Colors.amber.opacity(0.12)))
                }
                .buttonStyle(.plain)
                .help(loc("Save snippet to macOS Notes", "Сохранить сниппет в Заметки macOS"))
                
                Button(action: {
                    manager.togglePin(item: item)
                }) {
                    Image(systemName: item.isPinned ? "pin.slash" : "pin")
                        .font(.system(size: 10))
                        .foregroundStyle(item.isPinned ? V2Colors.amber : V2Colors.faint)
                        .padding(4)
                        .background(Circle().fill(item.isPinned ? V2Colors.amber.opacity(0.15) : Color.white.opacity(0.04)))
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    manager.copyToPasteboard(item: item)
                    copiedId = item.id
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        if copiedId == item.id {
                            copiedId = nil
                        }
                    }
                }) {
                    Text(copiedId == item.id ? loc("Copied!", "Скопировано!") : loc("Paste", "Вставить"))
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(copiedId == item.id ? Color.green : V2Colors.milk)
                        .padding(.vertical, 3)
                        .padding(.horizontal, 7)
                        .background(Color.white.opacity(copiedId == item.id ? 0.2 : 0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    withAnimation {
                        manager.remove(item: item)
                    }
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundStyle(V2Colors.faint)
                        .padding(4)
                }
                .buttonStyle(.plain)
            }
            .opacity(isHovered || item.isPinned || copiedId == item.id ? 1.0 : 0.35)
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 10)
        .heroGlassCard(cornerRadius: 10, isHovered: isHovered)
        .onHover { isHovered = $0 }
    }
}
