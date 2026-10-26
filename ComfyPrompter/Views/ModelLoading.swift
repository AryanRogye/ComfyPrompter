//
//  ModelLoading.swift
//  ComfyPrompter
//
//  Created by Aryan Rogye on 10/26/26.
//

import SwiftUI

struct ModelLoading: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .controlSize(.large)

            VStack(spacing: 8) {
                Text("Loading Model")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Initializing gaze estimation model...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: 500, maxHeight: 400)
        .padding()
    }
}
