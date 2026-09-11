//
//  WeatherLocationSettingsView.swift
//  kitkat
//
//  Created by Richard El-Kadi on 9/9/26.
//

import SwiftUI

/// The "which city" setting for the break window's weather tile. The text is
/// saved as typed; pressing Return or leaving the field confirms the city resolves.
struct WeatherLocationSettingsView: View {
    @AppStorage(WeatherCacheStore.locationQueryKey) private var query = ""
    @StateObject private var model = WeatherLocationSettingsModel()
    @FocusState private var isFocused: Bool

    var body: some View {
        GroupBox("Break Window Weather") {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Label("City", systemImage: "cloud.sun")
                        .foregroundStyle(.secondary)

                    TextField("e.g. Austin", text: $query)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 320)
                        .focused($isFocused)
                        .onSubmit(lookUp)
                        .accessibilityLabel("Weather city")

                    statusView

                    Spacer()
                }

                Text("Current conditions for this city appear on the break window.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .groupBoxStyle(.automatic)
        .onAppear(perform: model.loadInitialStatus)
        .onChange(of: isFocused) { _, focused in
            if !focused { lookUp() }
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch model.status {
        case .idle:
            EmptyView()

        case .checking:
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text("Looking up…")
            }
            .font(.callout)
            .foregroundStyle(.secondary)

        case .found(let name):
            Label(name, systemImage: "checkmark.circle.fill")
                .font(.callout)
                .foregroundStyle(.secondary)
                .symbolRenderingMode(.multicolor)

        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.callout)
                .foregroundStyle(.orange)
                .lineLimit(1)
        }
    }

    private func lookUp() {
        Task { await model.lookUp(query) }
    }
}

#Preview("Weather location setting") {
    WeatherLocationSettingsView()
        .padding()
        .frame(width: 700)
}
