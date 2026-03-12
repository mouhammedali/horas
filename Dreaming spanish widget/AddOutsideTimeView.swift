//
//  AddOutsideTimeView.swift
//  Dreaming spanis widget
//
//  Created by Mohamed Ali on 10/03/2026.
//
//  Sheet for logging study time done outside Dreaming Spanish
//  (e.g. Spanish movies, books, podcasts). Resets each day.

import SwiftUI

struct AddOutsideTimeView: View {
    @Environment(\.dismiss) private var dismiss
    let store: ProgressStore

    @State private var hours = 0
    @State private var minutes = 0

    private var totalMinutes: Int { hours * 60 + minutes }

    var body: some View {
        NavigationStack {
            Form {
                Section("Time to add") {
                    Stepper("Hours: \(hours)", value: $hours, in: 0...12)
                    Stepper("Minutes: \(minutes)", value: $minutes, in: 0...55, step: 5)
                }

                Section {
                    if totalMinutes > 0 {
                        Label(
                            "Adds \(totalMinutes) min to today's progress",
                            systemImage: "plus.circle.fill"
                        )
                        .foregroundStyle(.green)
                    } else {
                        Text("Select the time you studied outside Dreaming Spanish — books, movies, podcasts, etc.")
                            .foregroundStyle(.secondary)
                            .font(.footnote)
                    }
                }

                if store.data.outsideMinutesToday > 0 {
                    Section("Already logged today") {
                        Label(
                            "\(store.data.outsideMinutesToday) min outside DS",
                            systemImage: "clock.badge.checkmark"
                        )
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Add Outside Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if totalMinutes > 0 {
                            store.addOutsideTime(minutes: totalMinutes)
                        }
                        dismiss()
                    }
                    .disabled(totalMinutes == 0)
                }
            }
        }
    }
}
