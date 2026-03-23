//
//  VoiceEntry.swift
//  VoiceLens
//
//  Created by Shreya  Arjun  on 3/22/26.
//

import SwiftData
import Foundation

@Model
final class VoiceEntry {
    var id: UUID
    var timestamp: Date
    var transcript: String
    var aiResponse: String
    var audioFileName: String

    init(transcript: String, aiResponse: String, audioFileName: String) {
        self.id = UUID()
        self.timestamp = Date()
        self.transcript = transcript
        self.aiResponse = aiResponse
        self.audioFileName = audioFileName
    }
}
