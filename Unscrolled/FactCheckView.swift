import SwiftUI

struct FactCheckView: View {
    @EnvironmentObject var session: SessionManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    frameSection
                    analysisSection
                }
                .padding(.top)
            }
            .navigationTitle("Fact Check")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

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
                    Text("No frame captured yet")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            }
        }
    }

    private var analysisSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Analysis", systemImage: "checkmark.seal.fill")
                .font(.headline)

            Text("AI-powered fact checking coming soon. The frame captured from your screen will be analyzed for misinformation, bias, and accuracy.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
}
