//
//  TeamView.swift
//  Pact
//

import SwiftUI

struct TeamView: View {
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            Text("Team")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(.black)
        }
    }
}

#Preview {
    TeamView()
}
