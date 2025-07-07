//
//  ContentView.swift
//  SideChat
//
//  Created by Armaan Gupta on 7/7/25.
//

import SwiftUI
import Defaults

struct ContentView: View {
    @EnvironmentObject var defaultsManager: DefaultsManager
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "message.badge")
                .imageScale(.large)
                .foregroundStyle(.blue)
            
            Text("SideChat")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("LLM Sidebar Interface")
                .font(.title2)
                .foregroundStyle(.secondary)
            
            VStack(spacing: 10) {
                Text("Coming Soon:")
                    .font(.headline)
                
                Text("• Chat interface")
                Text("• Multiple LLM providers")
                Text("• Sidebar window management")
                Text("• Settings and customization")
            }
            .foregroundStyle(.secondary)
            
            Spacer()
            
            #if DEBUG
            Text("Debug mode enabled - Check Settings for development tools")
                .font(.caption)
                .foregroundStyle(.orange)
            #endif
        }
        .padding()
        .frame(minWidth: 400, minHeight: 300)
    }
}

#Preview {
    ContentView()
        .environmentObject(DefaultsManager.shared)
}
