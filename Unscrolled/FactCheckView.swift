import SwiftUI
import Photos

struct FactCheckView: View {
    @EnvironmentObject var session: SessionManager
    @Environment(\.dismiss) private var dismiss
    @StateObject private var analyzer = ContentAnalyzer()
    @State private var isSaving = false
    @State private var saveSuccess = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    frameSection

                    switch analyzer.state {
                    case .idle:
                        analyzeButton
                    case .extracting, .analyzing, .factChecking:
                        loadingSection
                    case .done(let result):
                        ResultsView(result: result)
                    case .failed(let message):
                        errorSection(message)
                    }
                }
                .padding(.top)
                .padding(.bottom, 100)
            }
            .navigationTitle("Fact Check")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if case .done = analyzer.state {
                        Button("Reset") { analyzer.reset() }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if case .done(let result) = analyzer.state {
                    saveButton(result: result)
                }
            }
        }
    }

    private func saveButton(result: AnalysisResult) -> some View {
        Button {
            Task { await saveToPhotos(result: result) }
        } label: {
            Group {
                if isSaving {
                    ProgressView().tint(.white)
                } else if saveSuccess {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: "square.and.arrow.down")
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 56, height: 56)
            .background(.blue, in: Circle())
            .shadow(radius: 4, y: 2)
        }
        .disabled(isSaving)
        .padding(.trailing, 20)
        .padding(.bottom, 24)
    }

    @MainActor
    private func saveToPhotos(result: AnalysisResult) async {
        isSaving = true
        defer { isSaving = false }

        let renderer = ImageRenderer(
            content: FactCheckExportView(frame: session.factCheckFrame, result: result)
        )
        renderer.scale = UIScreen.main.scale
        renderer.proposedSize = ProposedViewSize(width: 390, height: nil)

        guard let image = renderer.uiImage else { return }

        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { return }

        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        saveSuccess = true
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        saveSuccess = false
    }

    // MARK: - Frame

    private var frameSection: some View {
        Group {
            if let frame = session.factCheckFrame {
                Image(uiImage: frame)
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(12)
                    .padding(.horizontal)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "photo.slash")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No frame captured")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            }
        }
    }

    // MARK: - States

    private var analyzeButton: some View {
        Button {
            guard let frame = session.factCheckFrame else { return }
            Task { await analyzer.analyze(image: frame) }
        } label: {
            Label("Analyze with Claude", systemImage: "sparkles")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(session.factCheckFrame == nil)
        .padding(.horizontal)
    }

    private var loadingSection: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(analyzer.state.stepLabel)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private func errorSection(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundStyle(.orange)
            Text("Analysis failed")
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Try Again") { analyzer.reset() }
                .buttonStyle(.bordered)
        }
        .padding()
    }
}

// MARK: - Results

struct ResultsView: View {
    let result: AnalysisResult

    var body: some View {
        VStack(spacing: 16) {
            extractedSection
            analysisSection
            factCheckSection
        }
        .padding(.horizontal)
    }

    private var extractedSection: some View {
        CardSection(title: "Content", icon: "doc.text.fill") {
            VStack(alignment: .leading, spacing: 8) {
                if let username = result.extracted.username {
                    LabeledRow(label: "Account", value: username)
                }
                LabeledRow(label: "Type", value: result.extracted.contentType.capitalized)
                LabeledRow(label: "Tone", value: result.extracted.emotionalTone.capitalized)
                if let topic = result.extracted.topic {
                    LabeledRow(label: "Topic", value: topic)
                }
                if result.extracted.isSponsored {
                    Label("Sponsored content", systemImage: "dollarsign.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                if !result.extracted.claims.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Claims")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ForEach(result.extracted.claims, id: \.self) { claim in
                            Text("· \(claim)")
                                .font(.caption)
                        }
                    }
                }
            }
        }
    }

    private var analysisSection: some View {
        CardSection(title: "Analysis", icon: "brain.fill") {
            VStack(alignment: .leading, spacing: 10) {
                Text(result.analysis.summary)
                    .font(.subheadline)

                ManipulationMeter(score: result.analysis.manipulationScore)

                if !result.analysis.biasIndicators.isEmpty {
                    TagGroup(label: "Bias", tags: result.analysis.biasIndicators, color: .orange)
                }
                if !result.analysis.manipulationTechniques.isEmpty {
                    TagGroup(label: "Techniques", tags: result.analysis.manipulationTechniques, color: .red)
                }
                if !result.analysis.algorithmSignals.isEmpty {
                    TagGroup(label: "Algorithm signals", tags: result.analysis.algorithmSignals, color: .purple)
                }
            }
        }
    }

    private var factCheckSection: some View {
        CardSection(title: "Fact Check", icon: "checkmark.seal.fill") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VerdictBadge(verdict: result.factCheck.overallVerdict)
                    Spacer()
                    Text("Confidence: \(result.factCheck.confidence)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if result.factCheck.claims.isEmpty {
                    Text("No factual claims to check.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(result.factCheck.claims) { claim in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .top, spacing: 8) {
                                VerdictIcon(verdict: claim.verdict)
                                Text(claim.claim)
                                    .font(.caption.weight(.medium))
                            }
                            Text(claim.explanation)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.leading, 24)
                        }
                        if claim.id != result.factCheck.claims.last?.id {
                            Divider()
                        }
                    }
                }

                if let notes = result.factCheck.notes {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
            }
        }
    }
}

// MARK: - Supporting views

struct CardSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon).font(.headline)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct LabeledRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .leading)
            Text(value)
                .font(.caption)
        }
    }
}

struct TagGroup: View {
    let label: String
    let tags: [String]
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            FlowLayout(tags: tags, color: color)
        }
    }
}

struct FlowLayout: View {
    let tags: [String]
    let color: Color

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), alignment: .leading)], spacing: 4) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.system(size: 10))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(color.opacity(0.15), in: Capsule())
                    .foregroundStyle(color)
                    .lineLimit(2)
            }
        }
    }
}

struct ManipulationMeter: View {
    let score: Int

    private var color: Color {
        switch score {
        case 0...3: return .green
        case 4...6: return .orange
        default:    return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Manipulation score: \(score)/10")
                .font(.caption)
                .foregroundStyle(.secondary)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.secondary.opacity(0.2)).frame(height: 6)
                    Capsule().fill(color)
                        .frame(width: geo.size.width * CGFloat(score) / 10, height: 6)
                }
            }
            .frame(height: 6)
        }
    }
}

struct VerdictBadge: View {
    let verdict: String

    private var color: Color {
        switch verdict {
        case "accurate":         return .green
        case "mostly accurate":  return .blue
        case "misleading":       return .orange
        case "false":            return .red
        default:                 return .secondary
        }
    }

    var body: some View {
        Text(verdict.capitalized)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}

struct VerdictIcon: View {
    let verdict: String

    var body: some View {
        switch verdict {
        case "true":
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case "false":
            Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        case "misleading":
            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
        default:
            Image(systemName: "questionmark.circle.fill").foregroundStyle(.secondary)
        }
    }
}

// MARK: - Export layout (rendered to image for Photos save)

struct FactCheckExportView: View {
    let frame: UIImage?
    let result: AnalysisResult

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "eye.slash.fill")
                    .foregroundStyle(.red)
                Text("Unscrolled")
                    .font(.headline.weight(.semibold))
                Spacer()
                Text(Date(), style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            // Screenshot
            if let frame {
                Image(uiImage: frame)
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(12)
                    .padding(.horizontal)
            }

            // Results
            ResultsView(result: result)
                .padding(.bottom, 8)
        }
        .padding(.vertical, 20)
        .background(Color(UIColor.systemBackground))
    }
}
