//
//  AIService.swift
//  VoiceLens
//
//  Created by Shreya  Arjun  on 3/22/26.
//

import AVFoundation
import Foundation
import Observation

struct OpenAIConfig {
    static let apiKey = "YOUR_API_KEY_HERE"
}

@MainActor
@Observable
final class AIService {
    private(set) var responseText = ""
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let apiKey: String
    private let systemPrompt = "You are a helpful voice assistant similar to Siri. Give concise, conversational responses optimized for being read aloud. Keep responses under 3 sentences unless the user explicitly asks for more detail."

    private let speechSynthesizer = AVSpeechSynthesizer()

    private static let chatCompletionsURL = URL(string: "https://api.openai.com/v1/chat/completions")!

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func sendMessage(transcript: String) async {
        isLoading = true
        responseText = ""
        errorMessage = nil

        defer { isLoading = false }

        let body: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": transcript],
            ],
            "stream": true as Bool,
        ]

        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else {
            errorMessage = "Could not encode request."
            return
        }

        var request = URLRequest(url: Self.chatCompletionsURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = httpBody

        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                errorMessage = "Invalid response."
                return
            }

            guard (200 ... 299).contains(httpResponse.statusCode) else {
                var data = Data()
                for try await byte in bytes {
                    data.append(byte)
                }
                let text = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
                errorMessage = text
                return
            }

            for try await line in bytes.lines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty { continue }

                let dataPrefix = "data: "
                guard trimmed.hasPrefix(dataPrefix) else { continue }

                let payload = String(trimmed.dropFirst(dataPrefix.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if payload == "[DONE]" {
                    break
                }

                guard let chunkData = payload.data(using: .utf8) else { continue }

                if let streamError = try? JSONDecoder().decode(OpenAIStreamError.self, from: chunkData),
                   let message = streamError.error?.message
                {
                    errorMessage = message
                    return
                }

                guard let chunk = try? JSONDecoder().decode(ChatCompletionChunk.self, from: chunkData) else {
                    continue
                }

                for choice in chunk.choices ?? [] {
                    if let content = choice.delta?.content, !content.isEmpty {
                        responseText += content
                    }
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func speakResponse() {
        speechSynthesizer.stopSpeaking(at: .immediate)

        let utterance = AVSpeechUtterance(string: responseText)
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        speechSynthesizer.speak(utterance)
    }
}

// MARK: - OpenAI streaming payloads

private struct ChatCompletionChunk: Decodable {
    struct Choice: Decodable {
        struct Delta: Decodable {
            let content: String?
        }

        let delta: Delta?
    }

    let choices: [Choice]?
}

private struct OpenAIStreamError: Decodable {
    struct ErrorBody: Decodable {
        let message: String?
    }

    let error: ErrorBody?
}
