//
//  KeyboardObserver.swift
//  QRBarcodeApp
//
//  Created by Andrii Padalka on 25.10.2025.
//

import SwiftUI
import Combine

final class KeyboardObserver: ObservableObject {
    @Published var currentHeight: CGFloat = 0
    private var cancellables = Set<AnyCancellable>()

    init() {
        let willShow = NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
        let willHide = NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)

        willShow
            .compactMap { $0.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect }
            .map { $0.height }
            .merge(with: willHide.map { _ in CGFloat(0) })
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.currentHeight = $0 }
            .store(in: &cancellables)
    }
}
