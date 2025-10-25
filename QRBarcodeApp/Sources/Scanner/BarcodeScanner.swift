//
//  BarcodeScanner.swift
//  QRBarcodeApp
//
//  Created by Andrii Padalka on 25.10.2025.
//
import Foundation
import Vision
import CoreImage

final class BarcodeScanner {
    private let context = CIContext(options: nil)

    func decode(from cgImage: CGImage) async throws -> String? {
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr, .ean13, .ean8, .code128, .pdf417, .aztec, .dataMatrix, .upce, .code39]

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
        try handler.perform([request])

        guard let result = request.results?.first as? VNBarcodeObservation else { return nil }
        return result.payloadStringValue
    }
}
