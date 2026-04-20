import Foundation

// MARK: - Step 1: Raw extraction from screenshot

struct ExtractedContent: Codable {
    let contentType: String       // "reel", "post", "story", "ad", "unknown"
    let username: String?
    let caption: String?
    let visibleText: [String]     // all readable text in frame
    let claims: [String]          // factual or quasi-factual assertions
    let emotionalTone: String     // e.g. "outrage", "fear", "humor", "neutral"
    let isSponsored: Bool
    let topic: String?

    static let extractTool: [String: Any] = [
        "name": "extract_content",
        "description": "Extract structured content from a social media screenshot.",
        "input_schema": [
            "type": "object",
            "properties": [
                "contentType": [
                    "type": "string",
                    "enum": ["reel", "post", "story", "ad", "unknown"]
                ],
                "username":    ["type": "string"],
                "caption":     ["type": "string"],
                "visibleText": ["type": "array", "items": ["type": "string"],
                                "description": "Every piece of text visible in the screenshot"],
                "claims": [
                    "type": "array", "items": ["type": "string"],
                    "description": "Factual or quasi-factual assertions made in the content"
                ],
                "emotionalTone": ["type": "string"],
                "isSponsored":   ["type": "boolean"],
                "topic":         ["type": "string"]
            ],
            "required": ["contentType", "visibleText", "claims", "emotionalTone", "isSponsored"]
        ]
    ]
}

// MARK: - Step 2: Analysis of extracted content

struct ContentAnalysis: Codable {
    let summary: String
    let topicCategory: String
    let biasIndicators: [String]
    let manipulationTechniques: [String]
    let manipulationScore: Int    // 0–10
    let algorithmSignals: [String]

    static let analyzeTool: [String: Any] = [
        "name": "analyze_content",
        "description": "Analyze extracted social media content for bias, manipulation, and algorithmic signals.",
        "input_schema": [
            "type": "object",
            "properties": [
                "summary":        ["type": "string"],
                "topicCategory":  ["type": "string"],
                "biasIndicators": ["type": "array", "items": ["type": "string"]],
                "manipulationTechniques": [
                    "type": "array", "items": ["type": "string"],
                    "description": "e.g. appeal to fear, false urgency, outrage bait"
                ],
                "manipulationScore": [
                    "type": "integer", "minimum": 0, "maximum": 10,
                    "description": "0 = benign, 10 = highly manipulative"
                ],
                "algorithmSignals": [
                    "type": "array", "items": ["type": "string"],
                    "description": "What this content reveals about the viewer's algorithmic profile"
                ]
            ],
            "required": ["summary", "topicCategory", "biasIndicators",
                         "manipulationTechniques", "manipulationScore", "algorithmSignals"]
        ]
    ]
}

// MARK: - Step 3: Fact check of claims

struct FactCheck: Codable {
    let claims: [ClaimVerdict]
    let overallVerdict: String    // "accurate", "mostly accurate", "misleading", "false", "unverifiable"
    let confidence: String        // "high", "medium", "low"
    let notes: String?

    static let factCheckTool: [String: Any] = [
        "name": "fact_check",
        "description": "Fact-check specific claims extracted from social media content.",
        "input_schema": [
            "type": "object",
            "properties": [
                "claims": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "properties": [
                            "claim":       ["type": "string"],
                            "verdict":     ["type": "string",
                                           "enum": ["true", "false", "misleading", "unverifiable"]],
                            "explanation": ["type": "string"]
                        ],
                        "required": ["claim", "verdict", "explanation"]
                    ]
                ],
                "overallVerdict": [
                    "type": "string",
                    "enum": ["accurate", "mostly accurate", "misleading", "false", "unverifiable"]
                ],
                "confidence": ["type": "string", "enum": ["high", "medium", "low"]],
                "notes":      ["type": "string"]
            ],
            "required": ["claims", "overallVerdict", "confidence"]
        ]
    ]
}

struct ClaimVerdict: Codable, Identifiable {
    var id: String { claim }
    let claim: String
    let verdict: String
    let explanation: String
}

// MARK: - Combined result

struct AnalysisResult {
    let extracted: ExtractedContent
    let analysis: ContentAnalysis
    let factCheck: FactCheck
}
