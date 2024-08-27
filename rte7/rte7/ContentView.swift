//
//  ContentView.swift
//  rte7
//
//  Created by Richard El Kadi on 5/13/24.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var windowController: WindowController

    var body: some View {
        VStack {
            Text("Hello, world!")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Button("Close Window") {
                windowController.isVisible = false
            }
        }
    }
}

#Preview {
    ContentView().environmentObject(WindowController())
}
