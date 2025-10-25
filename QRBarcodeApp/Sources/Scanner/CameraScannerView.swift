//
//  CameraScannerView.swift
//  QRBarcodeApp
//
//  Created by Andrii Padalka on 25.10.2025.
//

import SwiftUI
import AVFoundation
import Vision
import Combine
import Foundation

// Thread-safe storage for the latest frame
actor FrameStore {
    private var image: CGImage? = nil
    func set(_ newImage: CGImage) { image = newImage }
    func get() -> CGImage? { image }
}

// MARK: - Camera session manager

final class CameraSessionManager: NSObject, ObservableObject {
    let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    @Published var isTorchOn: Bool = false
    private let videoDataQueue = DispatchQueue(label: "camera.video.queue")
    private let frameStore = FrameStore()

    override init() {
        super.init()
        configureSession()
    }

    private func configureSession() {
        sessionQueue.async {
            self.session.beginConfiguration()
            self.session.sessionPreset = .high

            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: device),
                  self.session.canAddInput(input) else {
                print("Camera input unavailable")
                self.session.commitConfiguration()
                return
            }
            self.session.addInput(input)

            if self.session.canAddOutput(self.videoOutput) {
                self.videoOutput.alwaysDiscardsLateVideoFrames = true
                self.videoOutput.setSampleBufferDelegate(self, queue: self.videoDataQueue)
                self.session.addOutput(self.videoOutput)
                self.videoOutput.connections.first?.videoRotationAngle = 90
            }

            self.session.commitConfiguration()
            self.session.startRunning()
        }
    }

    func toggleTorch() {
        guard let device = (session.inputs.first as? AVCaptureDeviceInput)?.device,
              device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = device.isTorchActive ? .off : .on
            device.unlockForConfiguration()
            DispatchQueue.main.async {
                self.isTorchOn = device.isTorchActive
            }
        } catch {
            print("Torch error: \(error)")
        }
    }

    /// Returns the most recent CGImage from the camera stream
    func snapshotCGImage() async -> CGImage? {
        await frameStore.get()
    }
}

extension CameraSessionManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer).oriented(.right)
        if let cg = CIContext().createCGImage(ciImage, from: ciImage.extent) {
            Task { await frameStore.set(cg) }
        }
    }
}

// MARK: - Camera preview view

struct CameraPreviewView: UIViewRepresentable {
    @ObservedObject var manager: CameraSessionManager

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black

        let layer = AVCaptureVideoPreviewLayer(session: manager.session)
        layer.videoGravity = .resizeAspectFill
        layer.connection?.videoRotationAngle = 90
        view.layer.addSublayer(layer)
        context.coordinator.previewLayer = layer
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.previewLayer?.frame = uiView.bounds
    }

    func makeCoordinator() -> Coordinator { Coordinator() }
    final class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}

// MARK: - SwiftUI screen

struct CameraScannerView: View {
    @Environment(\.openURL) private var openURL
    @StateObject private var manager = CameraSessionManager()
    @State private var decodedText: String? = nil
    @State private var isScanning: Bool = false
    private let scanner = BarcodeScanner()

    var body: some View {
        ZStack {
            CameraPreviewView(manager: manager)
                .ignoresSafeArea()

            // Top overlay with decoded result
            VStack {
                if let t = decodedText, !t.isEmpty {
                    let url = urlFromString(t)

                    Group {
                        if let url {
                            Button {
                                openURL(url)
                            } label: {
                                Text(t)
                                    .underline()
                                    .foregroundStyle(.blue)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button {
                                copyDecodedText()
                            } label: {
                                Text(t)
                                    .foregroundStyle(.yellow)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .font(.headline)
                    .multilineTextAlignment(.leading)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 12)
                    .padding(.horizontal, 16)
                    .contextMenu {
                        Button("Copy") { copyDecodedText() }
                    }
                    .transition(.opacity)
                } else {
                    Spacer().frame(height: 44) // reserve space
                }
                Spacer()
            }

            // Torch button (top-right)
            VStack {
                HStack {
                    Spacer()
                    Button {
                        manager.toggleTorch()
                    } label: {
                        Image(systemName: manager.isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(Color.black.opacity(0.35), in: Circle())
                    }
                    .padding(.top, 12)
                    .padding(.trailing, 16)
                }
                Spacer()
            }

            // Shutter
            VStack {
                Spacer()
                Button {
                    Task {
                        await decodeLatestFrame()
                    }
                } label: {
                    Circle()
                        .fill(.white)
                        .frame(width: 78, height: 78)
                        .overlay(Circle().stroke(Color.white.opacity(0.6), lineWidth: 2))
                        .shadow(radius: 8)
                }
                .padding(.bottom, 30)
            }
        }
    }

    @MainActor
    private func decodeLatestFrame() async {
        guard !isScanning else { return }
        isScanning = true
        defer { isScanning = false }

        guard let cg = await manager.snapshotCGImage() else {
            decodedText = "No frame."
            return
        }
        do {
            if let payload = try await scanner.decode(from: cg) {
                withAnimation { decodedText = payload }
            } else {
                withAnimation { decodedText = "No barcode found." }
            }
        } catch {
            withAnimation { decodedText = "Error: \(error.localizedDescription)" }
        }
    }

    // MARK: - Helpers

    private func urlFromString(_ text: String) -> URL? {
        let s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: s),
           let scheme = url.scheme?.lowercased(),
           ["http", "https"].contains(scheme) {
            return url
        }
        if let url = URL(string: "https://" + s), url.host != nil {
            return url
        }
        return nil
    }

    private func copyDecodedText() {
        guard let t = decodedText, !t.isEmpty else { return }
        UIPasteboard.general.string = t
    }
}

