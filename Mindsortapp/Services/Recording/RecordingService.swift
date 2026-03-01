//
//  RecordingService.swift
//  Mindsortapp
//

import AVFoundation
import Foundation

final class RecordingService {
    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var isRecording = false
    private(set) var audioFileURL: URL?

    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func startRecording(onBuffer: @escaping (AVAudioPCMBuffer) -> Void) throws {
        guard !isRecording else { return }
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
        try session.setActive(true)

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else {
            throw NSError(domain: "RecordingService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid input format"])
        }

        // Create a temporary .m4a file for saving audio
        let fileURL = RecordingService.newAudioFileURL()
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: format.channelCount,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        let file = try AVAudioFile(forWriting: fileURL, settings: settings)
        audioFile = file
        audioFileURL = fileURL

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            // Write buffer to file
            try? file.write(from: buffer)
            // Also forward to speech recognizer
            onBuffer(buffer)
        }
        try engine.start()
        audioEngine = engine
        isRecording = true
    }

    func stopRecording() {
        guard isRecording else { return }
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        audioFile = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    var recording: Bool { isRecording }

    // MARK: - Audio file management

    /// Directory where audio recordings are stored locally.
    static var audioDirectory: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Generate a unique file URL for a new recording.
    static func newAudioFileURL() -> URL {
        audioDirectory.appendingPathComponent("\(UUID().uuidString).m4a")
    }

    /// Delete local audio files older than 24 hours.
    static func cleanupOldRecordings() {
        let cutoff = Date().addingTimeInterval(-24 * 60 * 60)
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: audioDirectory, includingPropertiesForKeys: [.creationDateKey]) else { return }
        for file in files {
            guard let attrs = try? file.resourceValues(forKeys: [.creationDateKey]),
                  let created = attrs.creationDate,
                  created < cutoff else { continue }
            try? fm.removeItem(at: file)
        }
    }
}
