//
//  TranscriptionService.swift
//  Mindsortapp
//

import AVFoundation
import Speech
import Foundation

@MainActor
final class TranscriptionService {
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var locale: Locale = Locale(identifier: "en-US")

    /// Accumulated final transcript segments from auto-restarted recognition tasks.
    private var segments: [String] = []
    /// The latest interim (partial) result from the current recognition task.
    private var currentInterim: String = ""
    /// Whether we are actively recognizing (caller sets this via start/stop).
    private var active = false

    var onError: ((Error) -> Void)?

    static let supportedLocales: [(String, String)] = [
        ("en-US", "English"),
        ("de-DE", "Deutsch"),
        ("fr-FR", "Français"),
        ("es-ES", "Español")
    ]

    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    func startRecognition(localeIdentifier: String) throws {
        stopRecognition()
        locale = Locale(identifier: localeIdentifier)
        segments = []
        currentInterim = ""
        active = true
        try beginRecognitionTask()
    }

    func append(buffer: AVAudioPCMBuffer) {
        request?.append(buffer)
    }

    /// Stop recognition and deliver the final assembled transcript.
    func stopRecognition() {
        active = false
        request?.endAudio()
        request = nil
        task?.cancel()
        task = nil
    }

    /// Assemble the full transcript from all segments + any trailing interim text.
    func assembleTranscript() -> String {
        var parts = segments
        if !currentInterim.isEmpty {
            parts.append(currentInterim)
        }
        return parts.joined(separator: " ").trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Private

    private func beginRecognitionTask() throws {
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            throw NSError(domain: "TranscriptionService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Speech recognizer not available for \(locale.identifier)"])
        }
        self.recognizer = recognizer
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        req.requiresOnDeviceRecognition = true
        request = req

        task = recognizer.recognitionTask(with: req) { [weak self] result, err in
            Task { @MainActor in
                guard let self = self else { return }

                if let result = result {
                    if result.isFinal {
                        // Task ended naturally (e.g. 1-minute limit or silence).
                        // Save the final text and auto-restart if still active.
                        let text = result.bestTranscription.formattedString
                        if !text.trimmingCharacters(in: .whitespaces).isEmpty {
                            self.segments.append(text)
                        }
                        self.currentInterim = ""
                        if self.active {
                            try? self.beginRecognitionTask()
                        }
                    } else {
                        self.currentInterim = result.bestTranscription.formattedString
                    }
                } else if let err = err {
                    // Recognition error — auto-restart if still active.
                    let nsErr = err as NSError
                    let recoverable = nsErr.domain == "kAFAssistantErrorDomain" && (nsErr.code == 1110 || nsErr.code == 216 || nsErr.code == 1)
                    if self.active && recoverable {
                        try? self.beginRecognitionTask()
                    } else if self.active {
                        self.onError?(err)
                    }
                }
            }
        }
    }
}
