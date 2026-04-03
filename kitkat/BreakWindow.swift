//
//  BreakWindow.swift
//  kitkat
//
//  Created by Richard El-Kadi on 2/23/26.
//


//
//  BreakWindowSwift.swift
//  rte7
//
//  Created by Richard El Kadi on 8/26/24.
//

import Foundation
import SwiftUI

struct BreakWindow: View {
    var window: NSWindow?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(
                    Color.black.opacity(colorScheme == .dark ? 0.28 : 0.12)
                )
                .ignoresSafeArea()

            BreakView {
                window?.close()
            }
            .padding(32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct BreakView: View {
    @StateObject private var viewModel = QuoteViewModel()
    @Environment(\.colorScheme) private var colorScheme
    @State private var didAppear = false
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            Text(viewModel.message)
                .font(.title3)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)

            HStack(spacing: 12) {
                Button("Close", action: onClose)
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                Spacer()

                Button("Get Quote") {
                    viewModel.getQuote()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding(28)
        .frame(maxWidth: 720)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.primary.opacity(colorScheme == .dark ? 0.16 : 0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.35 : 0.16), radius: 24, x: 0, y: 10)
        .onAppear {
            if !didAppear {
                didAppear = true
                viewModel.getQuote()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Break time")
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)

            Text("Take a minute away from the keyboard.")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }
}
