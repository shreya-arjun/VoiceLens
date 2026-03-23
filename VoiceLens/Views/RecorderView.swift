//
//  RecorderView.swift
//  VoiceLens
//
//  Created by Shreya  Arjun  on 3/22/26.
//

import AVFoundation
import SwiftUI

struct RecorderView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var audioViewModel = AudioViewModel()

    @State private var recordButtonPulseScale: CGFloat = 1.0

    private let waveformMaxHeight: CGFloat = 60

    var body: some View {
        VStack(spacing: 24) {
            statusSection

            waveformSection
                .frame(height: waveformMaxHeight)

            recordSection

            transcriptSection
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.08))
        .task {
            await requestMicrophonePermissionIfNeeded()
        }
        .onChange(of: audioViewModel.recordingState) { _, newState in
            if newState == .recording {
                recordButtonPulseScale = 1.0
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    recordButtonPulseScale = 1.08
                }
            } else {
                recordButtonPulseScale = 1.0
            }
        }
    }

    private var statusSection: some View {
        Text(statusText(for: audioViewModel.recordingState))
            .font(.title3.weight(.medium))
            .foregroundStyle(.white)
            .animation(.easeInOut, value: audioViewModel.recordingState)
    }

    private func statusText(for state: RecordingState) -> String {
        switch state {
        case .idle: "Tap to speak"
        case .recording: "Listening..."
        case .recorded: "Processing..."
        case .transcribing: "Transcribing..."
        case .done: "Done"
        }
    }

    private var waveformSection: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: audioViewModel.recordingState != .recording)) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate
            let isRecording = audioViewModel.recordingState == .recording
            let level = CGFloat(audioViewModel.audioLevel)

            HStack(spacing: 6) {
                ForEach(0 ..< 20, id: \.self) { index in
                    let pseudoRandom = abs(sin(phase * 3.0 + Double(index) * 1.73 + Double(index) * 0.41))
                    let height: CGFloat = {
                        if isRecording {
                            let base = max(4, level * waveformMaxHeight * CGFloat(0.35 + 0.65 * pseudoRandom))
                            return min(waveformMaxHeight, base)
                        } else {
                            return 4
                        }
                    }()

                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color.accentColor)
                        .frame(height: height)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(maxHeight: waveformMaxHeight, alignment: .bottom)
        }
    }

    private var recordSection: some View {
        VStack(spacing: 12) {
            Button {
                let state = audioViewModel.recordingState
                if state == .idle || state == .done {
                    Task { await audioViewModel.startRecording() }
                } else if state == .recording {
                    Task { await audioViewModel.stopRecording() }
                }
            } label: {
                Circle()
                    .fill(recordButtonFill)
                    .overlay {
                        Circle()
                            .stroke(recordButtonStroke, lineWidth: recordButtonStrokeWidth)
                    }
                    .frame(width: 80, height: 80)
                    .scaleEffect(recordButtonPulseScale)
            }
            .buttonStyle(.plain)
            .disabled(!canTapRecordButton)

            if audioViewModel.recordingState == .done || audioViewModel.recordingState == .recorded {
                Button("Re-record") {
                    audioViewModel.reRecord()
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.85))
            }
        }
    }

    private var canTapRecordButton: Bool {
        let s = audioViewModel.recordingState
        return s == .idle || s == .done || s == .recording
    }

    private var recordButtonFill: Color {
        audioViewModel.recordingState == .recording ? .red : .white
    }

    private var recordButtonStroke: Color {
        audioViewModel.recordingState == .recording ? .clear : .red
    }

    private var recordButtonStrokeWidth: CGFloat {
        audioViewModel.recordingState == .recording ? 0 : 3
    }

    @ViewBuilder
    private var transcriptSection: some View {
        if !audioViewModel.transcript.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Transcript")
                    .font(.caption.smallCaps())
                    .foregroundStyle(.secondary)

                ScrollView {
                    Text(audioViewModel.transcript)
                        .font(.body)
                        .foregroundStyle(Color(white: 0.12))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
                .background(Color(white: 0.88))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Microphone permission

private extension RecorderView {
    func requestMicrophonePermissionIfNeeded() async {
        #if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
        let session = AVAudioSession.sharedInstance()
        let status = session.recordPermission
        switch status {
        case .undetermined:
            await withCheckedContinuation { continuation in
                session.requestRecordPermission { _ in
                    continuation.resume()
                }
            }
        case .denied, .granted:
            break
        @unknown default:
            break
        }
        #elseif os(macOS)
        if #available(macOS 14.0, *) {
            _ = await AVAudioApplication.requestRecordPermission()
        }
        #endif
    }
}

#Preview {
    RecorderView()
        .modelContainer(for: VoiceEntry.self, inMemory: true)
}
