//
//  QRGeneratorView.swift
//  QRBarcodeApp
//
//  Created by Andrii Padalka on 25.10.2025.
//
import SwiftUI
import CoreImage.CIFilterBuiltins

struct QRGeneratorView: View {
    @State private var inputText: String = ""
    @State private var qrImage: UIImage? = nil
    @FocusState private var isFocused: Bool
    @StateObject private var keyboard = KeyboardObserver()

    var goBack: () -> Void

    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea() // PrimaryBackgroundColor

            VStack(spacing: 16) {
                // Text field area (top third)
                VStack {
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $inputText)
                            .focused($isFocused)
                            .padding(12)
                            .frame(maxWidth: .infinity)
                            .frame(height: UIScreen.main.bounds.height / 3.2)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.3)))
                            .onTapGesture { isFocused = true }

                        if inputText.isEmpty && !isFocused {
                            Text("Your text here")
                                .foregroundStyle(.gray)
                                .padding(.top, 18)
                                .padding(.leading, 18)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                // Generated QR image
                Group {
                    if let ui = qrImage {
                        Image(uiImage: ui)
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                            .frame(maxWidth: 320, maxHeight: 320)
                            .transition(.opacity)
                    } else {
                        Spacer().frame(height: 40)
                    }
                }
                .frame(maxHeight: .infinity)

                // Bottom button (blue) - lifts with keyboard
                Button {
                    if qrImage == nil {
                        // Generate
                        generateQR(from: inputText.trimmingCharacters(in: .whitespacesAndNewlines))
                        hideKeyboard()
                    } else {
                        // Reset and focus
                        inputText = ""
                        qrImage = nil
                        isFocused = true
                    }
                } label: {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 74, height: 74)
                        .overlay(
                            Image(systemName: qrImage == nil ? "qrcode" : "arrow.counterclockwise")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(.white)
                        )
                        .shadow(radius: 6)
                }
                .padding(.bottom, max(20, keyboard.currentHeight + 12))
                .animation(.easeInOut(duration: 0.25), value: keyboard.currentHeight)
            }
        }
        // Tap anywhere to dismiss keyboard
        .contentShape(Rectangle())
        .onTapGesture {
            if isFocused { hideKeyboard() }
        }
        // Swipe right to go back
        .gesture(DragGesture(minimumDistance: 24, coordinateSpace: .local)
            .onEnded { value in
                if value.translation.width > 60 && abs(value.translation.height) < 40 {
                    goBack()
                }
            }
        )
    }

    private func generateQR(from text: String) {
        guard !text.isEmpty else { return }
        let data = Data(text.utf8)
        filter.setValue(data, forKey: "inputMessage")
        filter.correctionLevel = "M"
        if let output = filter.outputImage {
            let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
            if let cg = context.createCGImage(scaled, from: scaled.extent) {
                qrImage = UIImage(cgImage: cg)
            }
        }
    }

    private func hideKeyboard() {
        isFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
