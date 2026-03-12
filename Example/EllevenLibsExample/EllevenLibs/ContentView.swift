//
//  ContentView.swift
//  EllevenLibsExample
//
//  Created by Matevos Ghazaryan on 3/12/26.
//

import SwiftUI
import EllevenLibs

struct ContentView: View {
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
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
