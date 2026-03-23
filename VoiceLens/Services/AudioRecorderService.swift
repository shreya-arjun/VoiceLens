//
//  AudioRecorderService.swift
//  VoiceLens
//
//  Created by Shreya  Arjun  on 3/22/26.
//

import AVFoundation
import Foundation
import Observation

@Observable
final class AudioRecorderService {
    private(set) var isRecording = false
    private(set) var recordingURL: URL?
    private(set) var errorMessage: String?

    private var recorder: AVAudioRecorder?

    private static var outputFileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("recording.m4a", isDirectory: false)
    }

    private static var recordingSettings: [String: Any] {
        [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]
    }

    func startRecording() {
        errorMessage = nil

        if isRecording {
            stopRecording()
        }
        recordingURL = nil

        let url = Self.outputFileURL

        if FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                errorMessage = error.localizedDescription
                return
            }
        }

        #if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        #endif

        do {
            let newRecorder = try AVAudioRecorder(url: url, settings: Self.recordingSettings)
            newRecorder.prepareToRecord()
            guard newRecorder.record() else {
                errorMessage = "Could not start audio recording."
                recorder = nil
                deactivateSession()
                return
            }
            recorder = newRecorder
            isRecording = true
        } catch {
            errorMessage = error.localizedDescription
            recorder = nil
            deactivateSession()
        }
    }

    func stopRecording() {
        guard isRecording else { return }

        recorder?.stop()
        recorder = nil
        isRecording = false

        deactivateSession()

        recordingURL = Self.outputFileURL
    }

    func deleteRecording() {
        errorMessage = nil

        guard let url = recordingURL else { return }

        do {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
            recordingURL = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deactivateSession() {
        #if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = error.localizedDescription
        }
        #endif
    }
}
