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

    var onInterim: ((String) -> Void)?
    var onFinal: ((String) -> Void)?
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
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            throw NSError(domain: "TranscriptionService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Speech recognizer not available for \(localeIdentifier)"])
        }
        self.recognizer = recognizer
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        req.requiresOnDeviceRecognition = false
        request = req
        task = recognizer.recognitionTask(with: req) { [weak self] result, err in
            Task { @MainActor in
                if let err = err {
                    self?.onError?(err)
                    return
                }
                guard let result = result else { return }
                if result.isFinal {
                    self?.onFinal?(result.bestTranscription.formattedString)
                } else {
                    self?.onInterim?(result.bestTranscription.formattedString)
                }
            }
        }
    }

    func append(buffer: AVAudioPCMBuffer) {
        request?.append(buffer)
    }

    func stopRecognition() {
        request?.endAudio()
        request = nil
        task?.cancel()
        task = nil
    }
}
