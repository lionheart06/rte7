//
//  WeatherTileView.swift
//  kitkat
//
//  Created by Richard El-Kadi on 9/9/26.
//

import SwiftUI

/// Owns the view model and kicks off a refresh when the break window appears.
struct WeatherTileView: View {
    @StateObject private var viewModel: WeatherViewModel

    init(viewModel: @autoclosure @escaping () -> WeatherViewModel = WeatherViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel())
    }

    var body: some View {
        WeatherTileContent(state: viewModel.state)
            .task {
                await viewModel.refresh()
            }
    }
}

/// Pure rendering of a weather state. Kept separate from the view model so
/// every state can be previewed and rendered in tests.
struct WeatherTileContent: View {
    let state: WeatherViewModel.State

    var body: some View {
        InfoTile(title: "Weather", systemImage: "cloud.sun") {
            switch state {
            case .needsLocation:
                placeholder(
                    systemImage: "mappin.slash",
                    text: "Add a city in the main window to see the weather here."
                )

            case .loading(previous: nil):
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Checking the sky…")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .frame(minHeight: 44)

            case .failed(let message, previous: nil):
                placeholder(systemImage: "exclamationmark.triangle", text: message)

            case .loading(previous: let snapshot?):
                reading(snapshot)
                footnote {
                    ProgressView()
                        .controlSize(.mini)
                    Text("Updating…")
                }

            case .failed(_, previous: let snapshot?):
                reading(snapshot)
                footnote {
                    Image(systemName: "wifi.exclamationmark")
                    Text("Couldn’t refresh. Last reading \(snapshot.fetchedAt, format: .relative(presentation: .named)).")
                }

            case .loaded(let snapshot):
                reading(snapshot)
            }
        }
    }

    private func reading(_ snapshot: WeatherSnapshot) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: snapshot.condition.systemImage)
                .font(.system(size: 36))
                .symbolRenderingMode(.multicolor)
                .frame(width: 48, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.formattedTemperature())
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)

                Text(snapshot.condition.description)
                    .font(.body)
                    .foregroundStyle(.primary)

                Text(snapshot.locationName)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Weather in \(snapshot.locationName): \(snapshot.formattedTemperature()), \(snapshot.condition.description)"
        )
    }

    private func placeholder(systemImage: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .center)

            Text(text)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(minHeight: 44, alignment: .top)
    }

    private func footnote<Note: View>(@ViewBuilder _ note: () -> Note) -> some View {
        HStack(spacing: 6) {
            note()
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

// MARK: - Previews

private let previewSnapshot = WeatherSnapshot(
    temperatureCelsius: 35.2,
    condition: .from(wmoCode: 3),
    locationName: "Austin, Texas",
    fetchedAt: Date().addingTimeInterval(-25 * 60)
)

#Preview("Weather tile states") {
    VStack(spacing: 12) {
        WeatherTileContent(state: .loaded(previewSnapshot))
        WeatherTileContent(state: .loading(previous: previewSnapshot))
        WeatherTileContent(state: .failed(message: "Network is down", previous: previewSnapshot))
        WeatherTileContent(state: .loading(previous: nil))
        WeatherTileContent(state: .failed(message: OpenMeteoError.locationNotFound("Atlantis").localizedDescription, previous: nil))
        WeatherTileContent(state: .needsLocation)
    }
    .padding()
    .frame(width: 400)
}
