//
//  AudioViewModel.swift
//  VoiceLens
//
//  Created by Shreya  Arjun  on 3/22/26.
//

import Foundation
import Observation

enum RecordingState {
    case idle
    case recording
    case recorded
    case transcribing
    case done
}

@MainActor
@Observable
final class AudioViewModel {
    private let recorder: AudioRecorderService
    private let speech: SpeechService

    var recordingState: RecordingState = .idle
    /// Set from file transcription after recording stops.
    private(set) var transcript: String = ""
    var audioLevel: Float = 0

    private var levelTimer: Timer?

    var errorMessage: String?

    init() {
        recorder = AudioRecorderService()
        speech = SpeechService()
        speech.requestPermission()
    }

    func startRecording() {
        recordingState = .recording
        errorMessage = nil
        transcript = ""
        speech.clearTranscript()
        audioLevel = 0

        recorder.startRecording()
        if let err = recorder.errorMessage {
            errorMessage = err
            recordingState = .idle
            return
        }

        startLevelTimer()
    }

    func stopRecording() async {
        stopLevelTimer()

        recorder.stopRecording()

        recordingState = .transcribing

        if let url = recorder.recordingURL {
            await speech.transcribeFile(url: url)
            transcript = speech.transcript
            if let err = speech.errorMessage {
                errorMessage = err
            }
        } else {
            transcript = speech.transcript
            errorMessage = "No recording file available."
        }

        recordingState = .done
        audioLevel = 0
    }

    func reRecord() {
        stopLevelTimer()
        recorder.deleteRecording()
        speech.clearTranscript()
        transcript = ""
        recordingState = .idle
        audioLevel = 0
        errorMessage = nil
    }

    private func startLevelTimer() {
        stopLevelTimer()
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.audioLevel = Float.random(in: 0.2 ... 0.8)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        levelTimer = timer
    }

    private func stopLevelTimer() {
        levelTimer?.invalidate()
        levelTimer = nil
    }
}
