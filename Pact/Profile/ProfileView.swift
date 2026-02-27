//
//  ProfileView.swift
//  Pact
//

import SwiftUI

struct ProfileView: View {
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            Text("Profile")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(.black)
        }
    }
}

#Preview {
    ProfileView()
}
