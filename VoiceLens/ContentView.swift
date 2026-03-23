//
//  ContentView.swift
//  VoiceLens
//
//  Created by Shreya  Arjun  on 3/22/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \VoiceEntry.timestamp, order: .reverse) private var entries: [VoiceEntry]

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(entries) { entry in
                    NavigationLink {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(entry.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
                            Text(entry.transcript)
                            Text(entry.aiResponse)
                            Text(entry.audioFileName)
                        }
                    } label: {
                        Text(entry.transcript.isEmpty ? entry.timestamp.formatted() : entry.transcript)
                    }
                }
                .onDelete(perform: deleteEntries)
            }
#if os(macOS)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
#endif
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
#endif
                ToolbarItem {
                    Button(action: addEntry) {
                        Label("Add Entry", systemImage: "plus")
                    }
                }
            }
        } detail: {
            Text("Select an entry")
        }
    }

    private func addEntry() {
        withAnimation {
            let entry = VoiceEntry(transcript: "", aiResponse: "", audioFileName: "")
            modelContext.insert(entry)
        }
    }

    private func deleteEntries(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(entries[index])
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: VoiceEntry.self, inMemory: true)
}
