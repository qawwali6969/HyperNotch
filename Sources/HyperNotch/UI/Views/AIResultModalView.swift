import SwiftUI

struct AIResultModalView: View {
    @ObservedObject var ai = QuickAIEngine.shared
    @ObservedObject var localization = LocalizationManager.shared
    @State private var isCopied = false
    @State private var isSavedToNotes = false
    
    var body: some View {
        VStack(spacing: 8) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: ai.activeAction?.icon ?? "sparkles")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.cyan)
                
                Text(ai.activeAction?.localizedTitle ?? loc("AI Response", "AI Ответ"))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                
                Spacer()
                
                if !ai.resultText.isEmpty {
                    // Copy Button
                    Button(action: {
                        ai.copyResultToClipboard()
                        isCopied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            isCopied = false
                        }
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: isCopied ? "checkmark" : "doc.on.clipboard")
                                .font(.system(size: 8.5))
                            Text(isCopied ? loc("Copied!", "Скопировано!") : loc("Copy", "Копировать"))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(isCopied ? Color.green.opacity(0.25) : Color.white.opacity(0.12))
                        .foregroundStyle(isCopied ? Color.green : Color.white)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    
                    // Save to Apple Notes Button
                    Button(action: {
                        let actionName = ai.activeAction?.localizedTitle ?? loc("AI Request", "Запрос к AI")
                        let title = "HyperNotch: \(actionName)"
                        let ok = AppleNotesManager.shared.createNote(title: title, content: ai.resultText)
                        if ok {
                            isSavedToNotes = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                                isSavedToNotes = false
                            }
                        }
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: isSavedToNotes ? "checkmark" : "note.text.badge.plus")
                                .font(.system(size: 8.5))
                            Text(isSavedToNotes ? loc("Saved!", "В Заметках!") : loc("To Notes", "В Заметки"))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(isSavedToNotes ? Color.yellow.opacity(0.3) : Color.yellow.opacity(0.15))
                        .foregroundStyle(isSavedToNotes ? Color.green : Color.yellow)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help(loc("Save response to macOS Notes", "Сохранить этот ответ в системные Заметки macOS"))
                }
                
                Button(action: {
                    withAnimation(.spring) {
                        ai.isPresented = false
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(4)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.top, 6)
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Content
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 6) {
                    if ai.isGenerating {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                            Text(loc("AI is generating response...", "Нейросеть генерирует ответ..."))
                                .font(.system(size: 9.5, design: .monospaced))
                                .foregroundStyle(Color.cyan)
                        }
                        .padding(.vertical, 8)
                    } else if let error = ai.errorMessage {
                        HStack(spacing: 5) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                                .font(.system(size: 10))
                            Text(error)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.red.opacity(0.9))
                        }
                        .padding(6)
                        .background(Color.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    } else {
                        Text(ai.resultText)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.white)
                            .textSelection(.enabled)
                            .lineSpacing(3)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .heroGlassCard(cornerRadius: 12)
        .padding(8)
    }
}
