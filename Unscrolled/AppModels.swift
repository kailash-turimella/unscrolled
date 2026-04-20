import SwiftData
import Foundation

// MARK: - Session

@Model
final class SessionItem {
    var id: UUID
    var startTime: Date
    var duration: TimeInterval

    init(startTime: Date, duration: TimeInterval) {
        self.id = UUID()
        self.startTime = startTime
        self.duration = duration
    }

    var formattedDuration: String { duration.formattedTime }
}

// MARK: - Fact Check

@Model
final class FactCheckItem {
    var id: UUID
    var timestamp: Date
    var sessionStartTime: Date?

    // Extracted content
    var contentType: String
    var username: String?
    var topic: String?
    var emotionalTone: String
    var isSponsored: Bool

    // Analysis
    var topicCategory: String
    var biasIndicators: [String]
    var manipulationTechniques: [String]
    var manipulationScore: Int
    var algorithmSignals: [String]
    var analysisSummary: String

    // Fact check
    var overallVerdict: String
    var confidence: String
    var claimsData: Data          // JSON-encoded [ClaimVerdict]

    // Screenshot
    var frameData: Data?

    var claimVerdicts: [ClaimVerdict] {
        (try? JSONDecoder().decode([ClaimVerdict].self, from: claimsData)) ?? []
    }

    init(result: AnalysisResult, sessionStartTime: Date?, frameData: Data?) {
        self.id = UUID()
        self.timestamp = Date()
        self.sessionStartTime = sessionStartTime
        self.contentType = result.extracted.contentType
        self.username = result.extracted.username
        self.topic = result.extracted.topic
        self.emotionalTone = result.extracted.emotionalTone
        self.isSponsored = result.extracted.isSponsored
        self.topicCategory = result.analysis.topicCategory
        self.biasIndicators = result.analysis.biasIndicators
        self.manipulationTechniques = result.analysis.manipulationTechniques
        self.manipulationScore = result.analysis.manipulationScore
        self.algorithmSignals = result.analysis.algorithmSignals
        self.analysisSummary = result.analysis.summary
        self.overallVerdict = result.factCheck.overallVerdict
        self.confidence = result.factCheck.confidence
        self.claimsData = (try? JSONEncoder().encode(result.factCheck.claims)) ?? Data()
        self.frameData = frameData
    }
}

// MARK: - Shared helpers

extension TimeInterval {
    var formattedTime: String {
        let s = Int(self)
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, sec)
            : String(format: "%d:%02d", m, sec)
    }
}
