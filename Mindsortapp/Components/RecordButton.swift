//
//  RecordButton.swift
//  Mindsortapp
//

import SwiftUI

struct RecordButton: View {
    let isRecording: Bool
    let size: CGFloat
    let onTap: () -> Void

    init(isRecording: Bool = false, size: CGFloat = 72, onTap: @escaping () -> Void) {
        self.isRecording = isRecording
        self.size = size
        self.onTap = onTap
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(isRecording ? Theme.Colors.record : Theme.Colors.accent)
                    .frame(width: size, height: size)
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: size * 0.4))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isRecording ? "Stop recording" : "Start recording")
        .accessibilityHint(isRecording ? "Stops and saves your thought" : "Begins voice recording")
    }
}
