//
//  IconButton.swift
//  SwiftTransfer
//
//  Created by Irtaza Fiaz on 16/08/2025.
//


import SwiftUI

public struct IconButton: View {
    public enum Variant { case bordered, filled, subtle, plain }
    public enum Size { case xs, sm, md, lg }

    private let systemName: String
    private let variant: Variant
    private let size: Size
    private let role: ButtonRole?
    private let tint: Color?
    private let isLoading: Bool
    private let isDisabled: Bool
    private let accessibilityLabel: String
    private let haptics: Bool
    private let action: () -> Void

    public init(
        _ systemName: String,
        variant: Variant = .bordered,
        size: Size = .md,
        role: ButtonRole? = nil,
        tint: Color? = nil,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        accessibilityLabel: String,
        haptics: Bool = true,
        action: @escaping () -> Void
    ) {
        self.systemName = systemName
        self.variant = variant
        self.size = size
        self.role = role
        self.tint = tint
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.accessibilityLabel = accessibilityLabel
        self.haptics = haptics
        self.action = action
    }

    public var body: some View {
        Button(role: role) {
            #if os(iOS)
            if haptics { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
            #endif
            if !isLoading { action() }
        } label: {
            ZStack {
                background
                if isLoading {
                    ProgressView()
                        .scaleEffect(progressScale)
                } else {
                    Image(systemName: systemName)
                        .font(.system(size: iconSize, weight: .semibold))
                        .foregroundStyle(effectiveTint)
                }
            }
            .frame(width: buttonEdge, height: buttonEdge)
            .contentShape(Circle())
        }
        .buttonStyle(PressDownStyle())
        .disabled(isDisabled || isLoading)
        .accessibilityLabel(Text(accessibilityLabel))
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Drawing

    private var effectiveTint: Color {
        if let tint { return tint }
        if role == .destructive { return .red }
        return .accentColor
    }

    private var buttonEdge: CGFloat {
        switch size {
        case .xs: return 28
        case .sm: return 32
        case .md: return 40
        case .lg: return 48
        }
    }

    private var iconSize: CGFloat {
        switch size {
        case .xs: return 12
        case .sm: return 14
        case .md: return 16
        case .lg: return 20
        }
    }

    private var strokeOpacity: Double { 0.35 }
    private var fillOpacity: Double { 0.15 }
    private var subtleOpacity: Double { 0.10 }
    private var progressScale: CGFloat { max(0.7, iconSize / 16) }

    @ViewBuilder
    private var background: some View {
        switch variant {
        case .bordered:
            Circle()
                .stroke(effectiveTint.opacity(strokeOpacity), lineWidth: 1)
                .background(Circle().fill(.clear))
        case .filled:
            Circle().fill(effectiveTint.opacity(fillOpacity))
        case .subtle:
            if #available(iOS 15.0, *) {
                Circle().fill(.thinMaterial)
                    .overlay(Circle().strokeBorder(Color.primary.opacity(0.06)))
            } else {
                Circle().fill(Color.secondary.opacity(subtleOpacity))
            }
        case .plain:
            Circle().fill(.clear)
        }
    }
}

/// Press feedback (tiny scale on press)
public struct PressDownStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}
