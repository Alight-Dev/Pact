//
//  WelcomeView.swift
//  Pact
//
//  Created by Yaw Snr Owusu on 2/24/26.
//

import SwiftUI

struct WelcomeView: View {
    var onGetStarted: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    .white,
                    Color(red: 0.85, green: 0.96, blue: 0.95)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Image("PactLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .padding(.bottom, 24)

                Text("Welcome to Pact")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.bottom, 16)

                Text("Where you and your team will\nmake the most of your goals")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Spacer()

                Button(action: onGetStarted) {
                    Text("Get Started")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(red: 0.93, green: 0.92, blue: 0.87))
                        )
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
    }
}

#Preview {
    WelcomeView(onGetStarted: {})
}
