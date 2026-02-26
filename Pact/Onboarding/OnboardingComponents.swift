//
//  OnboardingComponents.swift
//  Pact
//
//  Created by Yaw Snr Owusu on 2/25/26.
//

import SwiftUI

// MARK: - Selectable Pill Button

struct SelectablePillButton: View {
    let title: String
    let isSelected: Bool
    let verticalPadding: CGFloat
    let action: () -> Void

    init(
        title: String,
        isSelected: Bool,
        verticalPadding: CGFloat = 22,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isSelected = isSelected
        self.verticalPadding = verticalPadding
        self.action = action
    }

    private var cardFill: Color {
        isSelected
            ? Color.white
            : Color(red: 0.95, green: 0.95, blue: 0.97)
    }

    private var borderColor: Color {
        isSelected ? Color.black : Color.black.opacity(0.06)
    }

    var body: some View {
        Button(action: action) {
            HStack {
                Spacer()
                Text(title)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Color.black)
                Spacer()
            }
            .padding(.vertical, verticalPadding)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(cardFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(borderColor, lineWidth: isSelected ? 1.5 : 1)
                    )
                    .shadow(
                        color: isSelected ? Color.black.opacity(0.08) : .clear,
                        radius: 12, x: 0, y: 4
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Step Progress Bar

struct OnboardingProgressBar: View {
    let totalSteps: Int
    let currentStep: Int  // 1-based

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...totalSteps, id: \.self) { step in
                Capsule()
                    .fill(step <= currentStep ? Color.black : Color.black.opacity(0.15))
                    .frame(height: 3)
            }
        }
    }
}
