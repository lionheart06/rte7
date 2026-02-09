//
//  BreakWindowSwift.swift
//  rte7
//
//  Created by Richard El Kadi on 8/26/24.
//

import Foundation
import SwiftUI

struct BreakWindow: View {
    // @Binding var isPresented: Bool
    var window: NSWindow?
    
    var body: some View {
        ZStack {
            //VisualEffectView()
            Color(.sRGB, red:0.0,green:0.5,blue:0.0,opacity:0.1 )
            .edgesIgnoringSafeArea(.all)
            VStack {
                BreakView().frame(width:600,height:200)
                Button("Close") {
                    window?.close()
                }
            }
        }.frame(maxWidth:.infinity, maxHeight:.infinity)
        
    }
    
}

struct BreakView: View {
    @StateObject private var viewModel = QuoteViewModel()
    @Environment(\.dismiss) var dismiss
    @State private var didAppear = false

    var body: some View {
        VStack {
          
                        Text(viewModel.message)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .multilineTextAlignment(.center)
                        
                        Button("Get Quote") {
                            viewModel.getQuote()
                        }
            /*Button("Close") {
dismiss()
            }*/
                    }
                    .frame(width: 600, height: 200)
                    .onAppear {
                        if !didAppear {
                            didAppear = true
                            viewModel.getQuote()
                        }
                    }
    }
    
}

// not needed for now
struct VisualEffectView:NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        // view.blendingMode = .behindWindow
        view.state = .active
        view.material = .fullScreenUI
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        
    }
}

