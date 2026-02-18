//
//  View+AppGradientOverlay.swift
//  BloodyDay
//
//  Created by Yunki on 2/18/26.
//

import SwiftUI

enum AppGradientOverlayStyle {
    case `default`
    case red
    case blue
    
    var gradient: LinearGradient {
        switch self {
        case .default:
            return LinearGradient(
                stops: [
                    .init(color: Color.mainRed.opacity(0.00), location: 0.00),
                    .init(color: Color.mainRed.opacity(0.00), location: 0.80),
                    .init(color: Color.mainRed.opacity(0.06), location: 1.00)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .red:
            return LinearGradient(
                stops: [
                    .init(color: Color.mainRed.opacity(0.00), location: 0.00),
                    .init(color: Color.mainRed.opacity(0.00), location: 0.80),
                    .init(color: Color.mainRed.opacity(0.06), location: 1.00)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .blue:
            return LinearGradient(
                stops: [
                    .init(color: Color.subBlue.opacity(0.00), location: 0.00),
                    .init(color: Color.subBlue.opacity(0.00), location: 0.80),
                    .init(color: Color.subBlue.opacity(0.06), location: 1.00)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

private struct AppGradientOverlayModifier: ViewModifier {
    let style: AppGradientOverlayStyle
    
    func body(content: Content) -> some View {
        content
            .overlay {
                style.gradient
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
    }
}

extension View {
    func appGradientOverlay(_ style: AppGradientOverlayStyle = .default) -> some View {
        modifier(AppGradientOverlayModifier(style: style))
    }
}
