//
//  UploadView.swift
//  Pact
//

import SwiftUI

struct UploadView: View {
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            Text("Upload")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(.black)
        }
    }
}

#Preview {
    UploadView()
}
