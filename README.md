
# QRBarcodeApp (SwiftUI, iOS 18.0)
Minimal 2‑screen app:
1) **Scanner** — live camera preview, white round button to decode QR/Barcodes on demand, torch toggle (top‑right), decoded text shown at the top.
2) **QR Generator** — text field (top third), blue round button (bottom), generated QR shown between them. Keyboard avoidance + tap‑to‑dismiss + reset behavior on second tap.

## Quick setup
1. In Xcode, create **iOS > App** named `QRBarcodeApp` (Interface: SwiftUI, Language: Swift, Min iOS: 18.0).
2. Replace generated files with the ones in `Sources/`:
   - `QRBarcodeApp.swift`
   - `RootView.swift`
   - `Scanner/CameraScannerView.swift`
   - `Scanner/BarcodeScanner.swift`
   - `Generator/QRGeneratorView.swift`
   - `Shared/KeyboardObserver.swift`
3. **Info.plist**: add the key
   - `Privacy - Camera Usage Description` (`NSCameraUsageDescription`) → “We use the camera to scan QR and barcodes.”
4. Run on a real device (camera required). Torch works only on devices with flash.
5. Swipe horizontally to switch between screens (page‑style TabView).

## Notes
- The scanner uses `AVCaptureSession` + `AVCaptureVideoDataOutput` and runs a `VNDetectBarcodesRequest` only when you press the shutter.
- The generator uses Core Image `CIQRCodeGenerator`.
- The blue button lifts above the keyboard; tapping anywhere outside the text field dismisses the keyboard.
