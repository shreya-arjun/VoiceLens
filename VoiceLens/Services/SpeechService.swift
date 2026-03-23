//
//  SpeechService.swift
//  VoiceLens
//
//  Created by Shreya  Arjun  on 3/22/26.
//

import Speech
import AVFoundation
import Foundation
import Observation

@MainActor
@Observable
final class SpeechService {
    private(set) var transcript = ""
    private(set) var isTranscribing = false
    private(set) var errorMessage: String?
    private(set) var authorizationStatus: SFSpeechRecognizerAuthorizationStatus

    private let speechRecognizer: SFSpeechRecognizer?

    private var fileRecognitionTask: SFSpeechRecognitionTask?
    private var liveRecognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var liveRecognitionTask: SFSpeechRecognitionTask?
    private weak var liveAudioEngine: AVAudioEngine?

    init() {
        authorizationStatus = SFSpeechRecognizer.authorizationStatus()
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }

    func clearTranscript() {
        transcript = ""
    }

    nonisolated func requestPermission() {
        SFSpeechRecognizer.requestAuthorization { status in
            Task { @MainActor [weak self] in
                self?.authorizationStatus = status
            }
        }
    }

    func transcribeFile(url: URL) async {
        stopLiveTranscription()
        fileRecognitionTask?.cancel()
        fileRecognitionTask = nil

        transcript = ""
        errorMessage = nil

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            errorMessage = "Speech recognition is not available."
            return
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let lock = NSLock()
            var didResume = false
            let resumeOnce: () -> Void = {
                lock.lock()
                defer { lock.unlock() }
                guard !didResume else { return }
                didResume = true
                continuation.resume()
            }

            fileRecognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor [weak self] in
                    guard let self else {
                        resumeOnce()
                        return
                    }
                    if let error = error {
                        self.errorMessage = error.localizedDescription
                        resumeOnce()
                        return
                    }
                    guard let result = result else {
                        resumeOnce()
                        return
                    }
                    self.transcript = result.bestTranscription.formattedString
                    if result.isFinal {
                        resumeOnce()
                    }
                }
            }
        }

        fileRecognitionTask = nil
    }

    func startLiveTranscription(audioEngine: AVAudioEngine) {
        errorMessage = nil
        stopLiveTranscription()

        transcript = ""

        guard authorizationStatus == .authorized else {
            errorMessage = "Speech recognition is not authorized."
            return
        }

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            errorMessage = "Speech recognition is not available."
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true

        liveRecognitionRequest = request
        liveAudioEngine = audioEngine

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        liveRecognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    self.stopLiveTranscription()
                    return
                }
                guard let result = result else { return }
                self.transcript = result.bestTranscription.formattedString
            }
        }

        isTranscribing = true
    }

    func stopLiveTranscription() {
        if let engine = liveAudioEngine {
            engine.inputNode.removeTap(onBus: 0)
        }
        liveAudioEngine = nil

        liveRecognitionRequest?.endAudio()
        liveRecognitionRequest = nil

        liveRecognitionTask?.cancel()
        liveRecognitionTask = nil

        isTranscribing = false
    }
}
