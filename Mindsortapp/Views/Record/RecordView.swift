//
//  RecordView.swift
//  Mindsortapp
//

import SwiftUI
import SwiftData

struct RecordView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store
    @Environment(\.modelContext) private var modelContext
    @Environment(\.syncService) private var syncService

    @State private var selectedLocale = "en-US"
    @State private var isRecording = false
    @State private var recordingStartDate: Date?
    @State private var saved = false
    @State private var permissionDenied = false
    @State private var errorMessage: String?
    @State private var transcriptionService = TranscriptionService()

    private let recordingService = RecordingService()
    private let categoryId: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.xl) {
                if saved {
                    savedView
                } else {
                    recordingContentView
                }
            }
            .padding(Theme.Spacing.lg)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.Colors.background)
            .navigationTitle("New thought")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !saved {
                        Menu {
                            ForEach(TranscriptionService.supportedLocales, id: \.0) { code, name in
                                Button(name) { selectedLocale = code }
                            }
                        } label: {
                            Text(localeName(for: selectedLocale))
                                .font(Theme.Typography.bodySmall())
                        }
                        .disabled(isRecording)
                        .accessibilityLabel("Recording language: \(localeName(for: selectedLocale))")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if !saved {
                        Button("Close") {
                            if isRecording {
                                recordingService.stopRecording()
                                transcriptionService.stopRecognition()
                            }
                            dismiss()
                        }
                    }
                }
            }
            .alert("Permission needed", isPresented: $permissionDenied) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) { dismiss() }
            } message: {
                Text("Microphone and speech recognition are required to record thoughts. Enable them in Settings.")
            }
            .alert("Error", isPresented: .init(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                if let msg = errorMessage { Text(msg) }
            }
            .task {
                await startRecordingIfAllowed()
            }
        }
    }

    // MARK: - Subviews

    private var savedView: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(Theme.Colors.success)
            Text("Thought saved!")
                .font(Theme.Typography.h2())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            dismiss()
        }
    }

    private var recordingContentView: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            if isRecording, let start = recordingStartDate {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(timeString(from: start, now: context.date))
                        .font(.system(size: 48, weight: .light, design: .monospaced))
                        .foregroundStyle(Theme.Colors.text)
                }

                Text("Recording…")
                    .font(Theme.Typography.body())
                    .foregroundStyle(Theme.Colors.textSecondary)
            } else {
                Text("Preparing…")
                    .font(Theme.Typography.h2())
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            Spacer()

            RecordButton(isRecording: isRecording) {
                if isRecording {
                    stopAndSave()
                }
            }
            .padding(.bottom, Theme.Spacing.xxl)
        }
    }

    // MARK: - Init

    init(categoryId: String? = nil) {
        self.categoryId = (categoryId == "__inbox__" || categoryId?.isEmpty == true) ? nil : categoryId
    }

    // MARK: - Helpers

    private func localeName(for code: String) -> String {
        TranscriptionService.supportedLocales.first { $0.0 == code }?.1 ?? code
    }

    private func timeString(from start: Date, now: Date = Date()) -> String {
        let elapsed = Int(now.timeIntervalSince(start))
        let m = elapsed / 60
        let s = elapsed % 60
        return String(format: "%02d:%02d", m, s)
    }

    // MARK: - Recording

    private func startRecordingIfAllowed() async {
        let micOK = await recordingService.requestPermission()
        let speechOK = await transcriptionService.requestPermission()
        guard micOK, speechOK else {
            permissionDenied = true
            return
        }
        startRecording()
    }

    private func startRecording() {
        transcriptionService.onError = { _ in }
        do {
            try transcriptionService.startRecognition(localeIdentifier: selectedLocale)
            try recordingService.startRecording { buffer in
                Task { @MainActor in
                    transcriptionService.append(buffer: buffer)
                }
            }
            isRecording = true
            recordingStartDate = Date()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func stopAndSave() {
        recordingService.stopRecording()
        transcriptionService.stopRecognition()
        isRecording = false

        let transcript = transcriptionService.assembleTranscript()
        let audioPath = recordingService.audioFileURL?.lastPathComponent

        guard let uid = store.userId else {
            errorMessage = "Not signed in."
            return
        }

        // Save even if transcript is empty — the audio file will be re-transcribed by Whisper on the server.
        do {
            let db = DatabaseService(modelContext: modelContext)
            _ = try db.createEntry(
                userID: uid,
                transcript: transcript,
                title: nil,
                categoryID: categoryId,
                locale: selectedLocale,
                audioLocalPath: audioPath
            )
            store.refreshInboxCount((try? db.inboxCount(userID: uid)) ?? 0)
            syncService?.requestSync(userID: uid)
            saved = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    RecordView()
        .environment(AppStore())
}
