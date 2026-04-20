import Foundation
import UIKit

@MainActor
final class ContentAnalyzer: ObservableObject {

    enum State {
        case idle
        case extracting
        case analyzing
        case factChecking
        case done(AnalysisResult)
        case failed(String)

        var isLoading: Bool {
            switch self { case .extracting, .analyzing, .factChecking: return true; default: return false }
        }

        var isDone: Bool {
            if case .done = self { return true }
            return false
        }

        var stepLabel: String {
            switch self {
            case .extracting:   return "Reading content…"
            case .analyzing:    return "Analyzing patterns…"
            case .factChecking: return "Checking facts…"
            default:            return ""
            }
        }
    }

    @Published var state: State = .idle

    private let client = AnthropicClient()

    func analyze(image: UIImage) async {
        guard let jpeg = image.jpegData(compressionQuality: 0.8) else {
            state = .failed("Could not encode image")
            return
        }
        let base64 = jpeg.base64EncodedString()

        do {
            state = .extracting
            let extracted = try await extractContent(base64: base64)

            state = .analyzing
            let analysis = try await analyzeContent(extracted)

            state = .factChecking
            let factCheck = try await factCheckClaims(extracted)

            state = .done(AnalysisResult(extracted: extracted, analysis: analysis, factCheck: factCheck))
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func reset() { state = .idle }

    // MARK: - Step 1: Extract structured content from screenshot

    private func extractContent(base64: String) async throws -> ExtractedContent {
        let response = try await client.send(
            system: "You are a media literacy assistant. Extract content from social media screenshots accurately and without judgment.",
            messages: [[
                "role": "user",
                "content": [
                    ["type": "image", "source": [
                        "type": "base64",
                        "media_type": "image/jpeg",
                        "data": base64
                    ]],
                    ["type": "text", "text": "Extract all structured content from this screenshot."]
                ]
            ]],
            tools: [ExtractedContent.extractTool],
            toolName: "extract_content",
            maxTokens: 1024
        )
        return try client.decode(ExtractedContent.self, from: response)
    }

    // MARK: - Step 2: Analyze patterns and manipulation in extracted content

    private func analyzeContent(_ content: ExtractedContent) async throws -> ContentAnalysis {
        let contentJson = (try? String(data: JSONEncoder().encode(content), encoding: .utf8)) ?? "{}"

        let response = try await client.send(
            system: "You are a critical media literacy expert. Analyze social media content for cognitive bias, emotional manipulation techniques, and what the content reveals about the viewer's algorithmic profile. Be specific and direct.",
            messages: [[
                "role": "user",
                "content": "Analyze this extracted social media content:\n\n\(contentJson)"
            ]],
            tools: [ContentAnalysis.analyzeTool],
            toolName: "analyze_content",
            maxTokens: 1024
        )
        return try client.decode(ContentAnalysis.self, from: response)
    }

    // MARK: - Step 3: Fact-check the claims

    private func factCheckClaims(_ content: ExtractedContent) async throws -> FactCheck {
        let claimsText: String
        if content.claims.isEmpty {
            claimsText = "No explicit factual claims were identified in this content."
        } else {
            claimsText = content.claims.enumerated()
                .map { "\($0.offset + 1). \($0.element)" }
                .joined(separator: "\n")
        }

        let response = try await client.send(
            system: "You are a fact-checker. Assess each claim based on your training knowledge. Use 'unverifiable' when you cannot reliably assess a claim rather than guessing. Never fabricate sources or statistics.",
            messages: [[
                "role": "user",
                "content": "Fact-check these claims from a \(content.topic ?? "social media") post:\n\n\(claimsText)"
            ]],
            tools: [FactCheck.factCheckTool],
            toolName: "fact_check",
            maxTokens: 1024
        )
        return try client.decode(FactCheck.self, from: response)
    }
}
