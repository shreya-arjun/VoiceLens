//
//  AudioViewModel.swift
//  VoiceLens
//
//  Created by Shreya  Arjun  on 3/22/26.
//

import AVFoundation
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
    /// Mirrors `speech.transcript`, updated while recording (timer) and after file transcription.
    private(set) var transcript: String = ""
    var audioLevel: Float = 0

    private var audioEngine = AVAudioEngine()
    private var levelTimer: Timer?

    var errorMessage: String?

    init() {
        recorder = AudioRecorderService()
        speech = SpeechService()
        speech.requestPermission()
    }

    func startRecording() async {
        recordingState = .recording
        errorMessage = nil
        transcript = ""
        speech.clearTranscript()
        audioLevel = 0

        audioEngine.prepare()

        recorder.startRecording()
        if let err = recorder.errorMessage {
            errorMessage = err
            recordingState = .idle
            return
        }

        speech.startLiveTranscription(audioEngine: audioEngine)
        if let err = speech.errorMessage {
            recorder.stopRecording()
            errorMessage = err
            recordingState = .idle
            return
        }

        do {
            try audioEngine.start()
        } catch {
            speech.stopLiveTranscription()
            recorder.stopRecording()
            errorMessage = error.localizedDescription
            recordingState = .idle
            return
        }

        startLevelTimer()
    }

    func stopRecording() async {
        stopLevelTimer()

        speech.stopLiveTranscription()

        recorder.stopRecording()

        if audioEngine.isRunning {
            audioEngine.stop()
        }

        recordingState = .recorded
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
    }

    func reRecord() {
        stopLevelTimer()
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        speech.stopLiveTranscription()
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
                self.audioLevel = self.recorder.normalizedMeterLevel()
                self.transcript = self.speech.transcript
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
