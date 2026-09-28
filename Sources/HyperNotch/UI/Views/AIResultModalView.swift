import SwiftUI

struct AIResultModalView: View {
    @ObservedObject var ai = QuickAIEngine.shared
    @ObservedObject var localization = LocalizationManager.shared
    @ObservedObject var themeManager = ThemeManager.shared
    @State private var isCopied = false
    @State private var isSavedToNotes = false
    
    var body: some View {
        VStack(spacing: 8) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: ai.activeAction?.icon ?? "sparkles")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(themeManager.currentTheme == .engineeringV2 ? V2Colors.ice1 : Color.white)
                
                Text(ai.activeAction?.localizedTitle ?? loc("AI Response", "AI Ответ"))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(themeManager.currentTheme == .engineeringV2 ? V2Colors.milk : Color.white)
                
                Spacer()
                
                if !ai.resultText.isEmpty {
                    // Copy Button
                    V2GlassButton(
                        title: isCopied ? loc("Copied!", "Скопировано!") : loc("Copy", "Копировать"),
                        icon: isCopied ? "checkmark" : "doc.on.clipboard",
                        isKey: isCopied
                    ) {
                        ai.copyResultToClipboard()
                        isCopied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            isCopied = false
                        }
                    }
                    
                    // Save to Apple Notes Button
                    V2GlassButton(
                        title: isSavedToNotes ? loc("Saved!", "В Заметках!") : loc("To Notes", "В Заметки"),
                        icon: isSavedToNotes ? "checkmark" : "note.text.badge.plus",
                        isKey: isSavedToNotes
                    ) {
                        let actionName = ai.activeAction?.localizedTitle ?? loc("AI Request", "Запрос к AI")
                        let title = "HyperNotch: \(actionName)"
                        let ok = AppleNotesManager.shared.createNote(title: title, content: ai.resultText)
                        if ok {
                            isSavedToNotes = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                                isSavedToNotes = false
                            }
                        }
                    }
                }
                
                Button(action: {
                    withAnimation(.spring) {
                        ai.isPresented = false
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(themeManager.currentTheme == .engineeringV2 ? V2Colors.faint : Color.white.opacity(0.6))
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Color.white.opacity(0.06)))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            
            Divider()
                .background(Color.white.opacity(0.08))
            
            // Content
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 6) {
                    if ai.isGenerating {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text(loc("AI is generating response...", "Нейросеть генерирует ответ..."))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(themeManager.currentTheme == .engineeringV2 ? V2Colors.ice1 : Color.white.opacity(0.8))
                        }
                        .padding(.vertical, 10)
                    } else if let error = ai.errorMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(V2Colors.red)
                                .font(.system(size: 10))
                            Text(error)
                                .font(.system(size: 9.5, design: .monospaced))
                                .foregroundStyle(V2Colors.red)
                        }
                        .padding(8)
                        .background(V2Colors.red.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(V2Colors.red.opacity(0.3), lineWidth: 1))
                    } else {
                        Text(ai.resultText)
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundStyle(themeManager.currentTheme == .engineeringV2 ? V2Colors.milk : Color.white)
                            .textSelection(.enabled)
                            .lineSpacing(3.5)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .heroGlassCard(cornerRadius: 14)
        .padding(8)
    }
}
