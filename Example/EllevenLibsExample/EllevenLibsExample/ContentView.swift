//
//  ContentView.swift
//  EllevenLibsExample
//
//  Created by Matevos Ghazaryan on 3/12/26.
//

import SwiftUI
import EllevenLibs

struct ContentView: View {
    private let logger = ELogger(tag: "Example")

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "books.vertical")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("EllevenLibs Example")
                .font(.title)
            Text("Library Version: \(EllevenLibs.version)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button("Test Logger") {
                logger.debug("Debug message from Example app")
                logger.info("Info message from Example app")
                logger.warning("Warning message from Example app")
                logger.error("Error message from Example app")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
