//
//  StretchSuggestion.swift
//  kitkat
//
//  Created by Richard El-Kadi on 9/3/26.
//

import Foundation

struct StretchSuggestion: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let systemImage: String
}

extension StretchSuggestion {
    static let catalog: [StretchSuggestion] = [
        StretchSuggestion(
            id: "stand",
            title: "Stand up and walk",
            detail: "One lap around the room is enough.",
            systemImage: "figure.walk"
        ),
        StretchSuggestion(
            id: "eyes",
            title: "Look 20 feet away",
            detail: "Hold it for 20 seconds to reset your focus.",
            systemImage: "eye"
        ),
        StretchSuggestion(
            id: "shoulders",
            title: "Roll your shoulders",
            detail: "Five slow circles back, then five forward.",
            systemImage: "figure.arms.open"
        ),
        StretchSuggestion(
            id: "water",
            title: "Drink some water",
            detail: "Refill the glass while you are up.",
            systemImage: "drop"
        ),
        StretchSuggestion(
            id: "neck",
            title: "Stretch your neck",
            detail: "Ear toward each shoulder, ten seconds a side.",
            systemImage: "figure.cooldown"
        ),
        StretchSuggestion(
            id: "wrists",
            title: "Loosen your wrists",
            detail: "Circle each wrist, then spread your fingers wide.",
            systemImage: "hand.raised"
        ),
        StretchSuggestion(
            id: "breathe",
            title: "Take four deep breaths",
            detail: "In for four counts, out for six.",
            systemImage: "wind"
        ),
        StretchSuggestion(
            id: "posture",
            title: "Reset your posture",
            detail: "Feet flat, back tall, screen at eye level.",
            systemImage: "figure.stand"
        )
    ]

    /// Walks a sliding window across the catalog so back-to-back breaks suggest
    /// different things instead of repeating the same list every 30 minutes.
    static func rotation(
        count: Int = 4,
        breakIndex: Int,
        from catalog: [StretchSuggestion] = catalog
    ) -> [StretchSuggestion] {
        guard !catalog.isEmpty, count > 0 else { return [] }

        let windowSize = min(count, catalog.count)
        let offset = (breakIndex % catalog.count + catalog.count) % catalog.count
        return (0..<windowSize).map { catalog[(offset + $0) % catalog.count] }
    }
}
