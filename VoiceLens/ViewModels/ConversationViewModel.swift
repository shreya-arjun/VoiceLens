//
//  ConversationViewModel.swift
//  VoiceLens
//
//  Created by Shreya  Arjun  on 3/22/26.
//

import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class ConversationViewModel {
    private let ai: AIService

    var conversationHistory: [VoiceEntry] = []
    var isProcessing = false
    var errorMessage: String?
    /// Mirrors `ai.responseText` during streaming and after completion.
    var currentResponse = ""

    private var streamTimer: Timer?

    init() {
        ai = AIService(apiKey: OpenAIConfig.apiKey)
    }

    func processTranscript(transcript: String, modelContext: ModelContext) async {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isProcessing = true
        defer { isProcessing = false }

        currentResponse = ""
        errorMessage = nil

        startStreamTimer()
        defer { stopStreamTimer() }

        await ai.sendMessage(transcript: trimmed)

        currentResponse = ai.responseText

        let entry = VoiceEntry(
            transcript: trimmed,
            aiResponse: ai.responseText,
            audioFileName: "recording.m4a"
        )
        modelContext.insert(entry)
        do {
            try modelContext.save()
            conversationHistory.append(entry)
        } catch {
            errorMessage = error.localizedDescription
        }

        ai.speakResponse()

        if let aiErr = ai.errorMessage {
            errorMessage = [errorMessage, aiErr].compactMap { $0 }.joined(separator: "\n")
        }
    }

    func clearError() {
        errorMessage = nil
    }

    func stopSpeaking() {
        ai.stopSpeaking()
    }

    private func startStreamTimer() {
        stopStreamTimer()
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.currentResponse = self.ai.responseText
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        streamTimer = timer
    }

    private func stopStreamTimer() {
        streamTimer?.invalidate()
        streamTimer = nil
    }
}
