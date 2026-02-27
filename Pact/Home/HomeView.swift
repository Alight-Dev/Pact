//
//  HomeView.swift
//  Pact
//

import SwiftUI

struct HomeView: View {
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            Text("Home")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(.black)
        }
    }
}

#Preview {
    HomeView()
}
