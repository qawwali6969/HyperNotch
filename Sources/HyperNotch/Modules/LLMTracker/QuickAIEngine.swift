import Foundation
import SwiftUI
import AppKit

enum AIActionType: String, Identifiable {
    case explain = "Объяснить"
    case summarize = "Саммари"
    case translate = "Перевести"
    case fix = "Исправить"
    case custom = "Запрос"
    
    var id: String { rawValue }
    
    @MainActor
    var localizedTitle: String {
        switch self {
        case .explain: return loc("Explain", "Объяснить")
        case .summarize: return loc("Summarize", "Саммари")
        case .translate: return loc("Translate", "Перевести")
        case .fix: return loc("Fix", "Исправить")
        case .custom: return loc("Prompt", "Запрос")
        }
    }
    
    var icon: String {
        switch self {
        case .explain: return "questionmark.circle"
        case .summarize: return "text.badge.checkmark"
        case .translate: return "character.book.closed"
        case .fix: return "wand.and.stars"
        case .custom: return "sparkles"
        }
    }
}

enum QuickAIProvider: String, CaseIterable, Identifiable {
    case auto = "Автовыбор"
    case gemini = "Google Gemini"
    case zai = "Z.ai (GLM)"
    
    var id: String { rawValue }
    
    @MainActor
    var localizedName: String {
        switch self {
        case .auto: return loc("Auto-Select", "Автовыбор")
        case .gemini: return "Google Gemini"
        case .zai: return "Z.ai (GLM)"
        }
    }
    
    @MainActor
    var localizedSubtitle: String {
        switch self {
        case .auto: return loc("Gemini 2.0 Flash first, fallback to Z.ai", "Сначала Gemini 2.0 Flash, при ошибке Z.ai")
        case .gemini: return loc("Gemini 2.0 Flash (fast, free tier)", "Gemini 2.0 Flash (быстрый, бесплатный)")
        case .zai: return "GLM-4-Flash (Z.ai / BigModel)"
        }
    }
    
    @MainActor
    var subtitle: String {
        localizedSubtitle
    }
}

@MainActor
class QuickAIEngine: ObservableObject {
    static let shared = QuickAIEngine()
    
    @Published var isGenerating: Bool = false
    @Published var activeAction: AIActionType? = nil
    @Published var resultText: String = ""
    @Published var sourceText: String = ""
    @Published var errorMessage: String? = nil
    @Published var isPresented: Bool = false
    
    // Quick Prompt Bar in Notch
    @Published var quickPromptQuery: String = ""
    
    // Selected Provider
    @Published var selectedProvider: QuickAIProvider = {
        if let raw = UserDefaults.standard.string(forKey: "QuickAIProvider"),
           let p = QuickAIProvider(rawValue: raw) {
            return p
        }
        return .auto
    }() {
        didSet {
            UserDefaults.standard.set(selectedProvider.rawValue, forKey: "QuickAIProvider")
        }
    }
    
    func executeAction(_ action: AIActionType, on text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        self.sourceText = trimmed
        self.activeAction = action
        self.resultText = ""
        self.errorMessage = nil
        self.isGenerating = true
        self.isPresented = true
        
        let prompt: String
        switch action {
        case .explain:
            prompt = "Объясни кратко и по сути следующий фрагмент (выдели назначение и логику):\n\n\(trimmed)"
        case .summarize:
            prompt = "Сделай краткое структурированное саммари (тезисно, самое главное) следующего текста:\n\n\(trimmed)"
        case .translate:
            prompt = "Переведи следующий текст. Если он на русском — переведи на английский. Если он на английском или другом языке — переведи на русский. Выдай только качественный перевод без лишних вводных слов:\n\n\(trimmed)"
        case .fix:
            prompt = "Исправь возможные ошибки/опечатки или улучши формулировку следующего текста/кода, сохранив смысл:\n\n\(trimmed)"
        case .custom:
            prompt = trimmed
        }
        
        Task {
            await self.sendPrompt(prompt)
        }
    }
    
    func submitQuickPrompt() {
        let q = quickPromptQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        quickPromptQuery = ""
        executeAction(.custom, on: q)
    }
    
    private func sendPrompt(_ prompt: String) async {
        let tracker = LLMTrackerManager.shared
        let geminiKey = tracker.geminiApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let zaiKey = tracker.zaiApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        
        switch selectedProvider {
        case .gemini:
            if !geminiKey.isEmpty {
                if await callGemini(key: geminiKey, prompt: prompt) { return }
            } else {
                self.isGenerating = false
                self.errorMessage = "Google Gemini API ключ не задан. Добавьте его в настройках."
                return
            }
        case .zai:
            if !zaiKey.isEmpty {
                if await callZai(key: zaiKey, prompt: prompt) { return }
            } else {
                self.isGenerating = false
                self.errorMessage = "Z.ai API ключ не задан. Добавьте его в настройках."
                return
            }
        case .auto:
            if !geminiKey.isEmpty {
                if await callGemini(key: geminiKey, prompt: prompt) { return }
            }
            if !zaiKey.isEmpty {
                if await callZai(key: zaiKey, prompt: prompt) { return }
            }
        }
        
        // If failed
        self.isGenerating = false
        if self.errorMessage == nil {
            self.errorMessage = "Не удалось получить ответ. Проверьте API ключи Gemini или Z.ai в настройках."
        }
    }
    
    private func callGemini(key: String, prompt: String) async -> Bool {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=\(key)") else {
            return false
        }
        
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 20
        
        let payload: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ]
        ]
        
        guard let httpBody = try? JSONSerialization.data(withJSONObject: payload) else { return false }
        req.httpBody = httpBody
        
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return false
            }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let candidates = json["candidates"] as? [[String: Any]],
               let firstCandidate = candidates.first,
               let content = firstCandidate["content"] as? [String: Any],
               let parts = content["parts"] as? [[String: Any]],
               let text = parts.first?["text"] as? String {
                self.resultText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                self.isGenerating = false
                return true
            }
        } catch {
            return false
        }
        return false
    }
    
    private func callZai(key: String, prompt: String) async -> Bool {
        let host = key.contains(".") ? "https://open.bigmodel.cn" : "https://api.z.ai"
        guard let url = URL(string: "\(host)/api/paas/v4/chat/completions") else { return false }
        
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 20
        
        let payload: [String: Any] = [
            "model": "glm-4-flash",
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]
        
        guard let httpBody = try? JSONSerialization.data(withJSONObject: payload) else { return false }
        req.httpBody = httpBody
        
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return false
            }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let firstChoice = choices.first,
               let message = firstChoice["message"] as? [String: Any],
               let text = message["content"] as? String {
                self.resultText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                self.isGenerating = false
                return true
            }
        } catch {
            return false
        }
        return false
    }
    
    func copyResultToClipboard() {
        guard !resultText.isEmpty else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(resultText, forType: .string)
        ClipboardManager.shared.addManualEntry(text: resultText)
    }
}
