//
//  RootView.swift
//  QRBarcodeApp
//
//  Created by Andrii Padalka on 25.10.2025.
//
import SwiftUI

struct RootView: View {
    @State private var selection: Int = 0
    @AppStorage("showGenerateBadge") private var showGenerateBadge: Bool = true

    var body: some View {
        TabView(selection: $selection) {
            CameraScannerView()
                .tag(0)
                .tabItem { Label("Scan", systemImage: "camera.viewfinder") }

            QRGeneratorView(goBack: { selection = 0 })
                .tag(1)
                .tabItem { Label("Generate", systemImage: "qrcode") }
                .badge(showGenerateBadge ? "New" : nil)
        }
        .onChange(of: selection, initial: false) {
            if selection == 1 { showGenerateBadge = false }
        }
    }
}

#Preview {
    RootView()
}
