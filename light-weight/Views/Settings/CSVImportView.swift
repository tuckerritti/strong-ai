import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct CSVImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var exercises: [Exercise]
    @Query private var workoutLogs: [WorkoutLog]

    @State private var headers: [String] = []
    @State private var rows: [[String]] = []
    @State private var mapping: [CSVColumnRole] = []
    @State private var showFilePicker = true
    @State private var importedCount = 0
    @State private var classifiedCount = 0
    @State private var step: ImportStep = .mapColumns
    @State private var errorMessage: String?

    private enum ImportStep { case mapColumns, classifying, done }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch step {
            case .mapColumns:
                mapColumnsView
            case .classifying:
                classifyingView
            case .done:
                doneView
            }
        }
        .navigationTitle("Import CSV")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.commaSeparatedText]) { result in
            handleFile(result)
        }
        .onChange(of: showFilePicker) { _, isPresented in
            if !isPresented && headers.isEmpty {
                dismiss()
            }
        }
        .onChange(of: mapping) { (old: [CSVColumnRole], new: [CSVColumnRole]) in
            for i in new.indices {
                guard new[i] != .skip, new[i] != old[i] else { continue }
                for j in new.indices where j != i && mapping[j] == new[i] {
                    mapping[j] = .skip
                }
            }
        }
    }

    private var mapColumnsView: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 14))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if !headers.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("MAP COLUMNS")
                            .font(.system(size: 13, weight: .semibold))
                            .tracking(0.5)
                            .foregroundStyle(Color.textSecondary)

                        VStack(spacing: 0) {
                            ForEach(headers.indices, id: \.self) { i in
                                VStack(spacing: 4) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(headers[i])
                                                .font(.system(size: 15, weight: .medium))
                                                .foregroundStyle(Color.textPrimary)

                                            if let sample = sampleValues(column: i) {
                                                Text(sample)
                                                    .font(.system(size: 12))
                                                    .foregroundStyle(Color.textSecondary)
                                                    .lineLimit(1)
                                            }
                                        }

                                        Spacer()

                                        Picker("", selection: $mapping[i]) {
                                            ForEach(CSVColumnRole.allCases) { role in
                                                Text(role.rawValue).tag(role)
                                            }
                                        }
                                        .tint(mapping[i] == .skip ? Color.textSecondary : Color.accent)
                                    }
                                    .padding(.vertical, 10)
                                }

                                if i < headers.count - 1 {
                                    Divider()
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .background(Color.appSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Text("\(rows.count) rows found")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textSecondary)

                    Button {
                        doImport()
                    } label: {
                        Text("Import")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color(hex: 0x0A0A0A))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(!mapping.contains(.exerciseName) || !mapping.contains(.date))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
    }

    private var classifyingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .controlSize(.large)
            Text("Classifying \(classifiedCount) exercises...")
                .font(.custom("SpaceGrotesk-Bold", size: 20))
                .foregroundStyle(Color.textPrimary)
            Text("Using AI to identify muscle groups")
                .font(.system(size: 14))
                .foregroundStyle(Color.textSecondary)
            Spacer()
        }
    }

    private var doneView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.accent)
            Text("Imported \(importedCount) workouts")
                .font(.custom("SpaceGrotesk-Bold", size: 24))
                .foregroundStyle(Color.textPrimary)
            if classifiedCount > 0 {
                Text("Classified \(classifiedCount) exercises")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.textSecondary)
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x0A0A0A))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Actions

    private func handleFile(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Could not access file."
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let text = try String(contentsOf: url, encoding: .utf8)
                let parsed = CSVImportService.parse(text)
                guard !parsed.headers.isEmpty, !parsed.rows.isEmpty else {
                    errorMessage = "CSV file is empty or has no data rows."
                    return
                }
                headers = parsed.headers
                rows = parsed.rows
                mapping = CSVImportService.suggestMapping(headers: parsed.headers)
            } catch {
                errorMessage = "Failed to read file: \(error.localizedDescription)"
            }

        case .failure(let error):
            errorMessage = "File picker error: \(error.localizedDescription)"
        }
    }

    private func doImport() {
        guard mapping.contains(.exerciseName), mapping.contains(.date) else {
            errorMessage = "Map at least the Exercise Name and Date columns."
            return
        }

        // Clear existing library and history — CSV import replaces all data
        try? modelContext.delete(model: Exercise.self)
        try? modelContext.delete(model: WorkoutLog.self)

        let result = CSVImportService.importWorkouts(
            rows: rows,
            mapping: mapping,
            existingExercises: [],
            modelContext: modelContext
        )
        importedCount = result.workoutCount

        let apiKey = UserProfileService.loadAPIKey()
        if !result.unclassifiedExerciseNames.isEmpty && !apiKey.isEmpty {
            classifiedCount = result.unclassifiedExerciseNames.count
            step = .classifying
            Task {
                do {
                    try await CSVImportService.classifyExercises(
                        names: result.unclassifiedExerciseNames,
                        apiKey: apiKey,
                        exercises: exercises,
                        workoutLogs: workoutLogs,
                        modelContext: modelContext
                    )
                } catch {
                    classifiedCount = 0
                }
                step = .done
            }
        } else {
            step = .done
        }
    }

    private func sampleValues(column: Int) -> String? {
        let samples = rows.prefix(3).compactMap { row in
            column < row.count ? row[column] : nil
        }.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !samples.isEmpty else { return nil }
        return samples.joined(separator: " · ")
    }
}
