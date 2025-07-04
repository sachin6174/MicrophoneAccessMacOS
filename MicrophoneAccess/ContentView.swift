//
//  ContentView.swift
//  MicrophoneAccess
//
//  Created by sachin kumar on 04/07/25.
//

import SwiftUI
import AVFoundation
import AppKit

// https://developer.apple.com/documentation/avfoundation/requesting-authorization-to-capture-and-save-media

struct ContentView: View {
    @StateObject private var microphoneManager = MicrophoneManager()
    @State private var showCopiedAlert = false

    var body: some View {
        VStack(spacing: 30) {
            Text("Microphone Access")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack(spacing: 20) {
                // Permission Status Display
                HStack(spacing: 15) {
                    Image(systemName: microphoneIconName)
                        .foregroundColor(microphoneIconColor)
                        .font(.system(size: 40))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Microphone Permission")
                            .font(.headline)
                        Text(permissionStatusText)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                // Permission Action Buttons
                VStack(spacing: 12) {
                    if microphoneManager.permissionStatus != .granted {
                        Button(action: handlePermissionAction) {
                            Text("Give Permission")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    if microphoneManager.permissionStatus == .granted {
                        VStack(spacing: 12) {
                            // Commands Display
                            VStack(spacing: 12) {
                                Text("Terminal Commands for Microphone Permissions:")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                
                                // Command 1: Reset this app's permission
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Reset this app's permission:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    HStack {
                                        Text("tccutil reset Microphone \(Bundle.main.bundleIdentifier ?? "com.sachin.guitar.MicrophoneAccess")")
                                            .font(.system(.body, design: .monospaced))
                                            .padding(8)
                                            .background(Color.black.opacity(0.05))
                                            .cornerRadius(6)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        
                                        Button(action: {
                                            let command = "tccutil reset Microphone \(Bundle.main.bundleIdentifier ?? "com.sachin.guitar.MicrophoneAccess")"
                                            copyToClipboard(command)
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                showCopiedAlert = true
                                            }
                                        }) {
                                            Image(systemName: "doc.on.doc")
                                                .font(.system(size: 14))
                                                .foregroundColor(.blue)
                                                .padding(6)
                                                .background(Color.blue.opacity(0.1))
                                                .cornerRadius(4)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        .help("Copy command")
                                    }
                                }
                                
                                // Command 2: Reset single app permission
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Reset any app's permission:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    HStack {
                                        Text("tccutil reset Microphone <Bundle-ID>")
                                            .font(.system(.body, design: .monospaced))
                                            .padding(8)
                                            .background(Color.black.opacity(0.05))
                                            .cornerRadius(6)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        
                                        Button(action: {
                                            let command = "tccutil reset Microphone <Bundle-ID>"
                                            copyToClipboard(command)
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                showCopiedAlert = true
                                            }
                                        }) {
                                            Image(systemName: "doc.on.doc")
                                                .font(.system(size: 14))
                                                .foregroundColor(.blue)
                                                .padding(6)
                                                .background(Color.blue.opacity(0.1))
                                                .cornerRadius(4)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        .help("Copy command")
                                    }
                                }
                                
                                // Command 3: Reset all microphone permissions
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Reset ALL microphone permissions:")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                        .fontWeight(.medium)
                                    
                                    HStack {
                                        Text("tccutil reset Microphone")
                                            .font(.system(.body, design: .monospaced))
                                            .padding(8)
                                            .background(Color.red.opacity(0.05))
                                            .cornerRadius(6)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        
                                        Button(action: {
                                            let command = "tccutil reset Microphone"
                                            copyToClipboard(command)
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                showCopiedAlert = true
                                            }
                                        }) {
                                            Image(systemName: "doc.on.doc")
                                                .font(.system(size: 14))
                                                .foregroundColor(.red)
                                                .padding(6)
                                                .background(Color.red.opacity(0.1))
                                                .cornerRadius(4)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        .help("Copy command")
                                    }
                                }
                            }
                            .padding()
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(12)
                            
                            // System Settings fallback
                            Button(action: openSystemSettings) {
                                Text("Open System Settings")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                                    .frame(maxWidth: .infinity, minHeight: 32)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(6)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding(40)
        .frame(minWidth: 800, maxWidth: 800, minHeight: 500, maxHeight: 500)
//        .frame(minWidth: 550, maxWidth: 550, minHeight: 500, maxHeight: .infinity)
        .onAppear {
            microphoneManager.checkPermissionStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            // Refresh when app becomes active (user returns from System Settings)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                microphoneManager.refreshPermissionStatus()
            }
        }
        .alert(isPresented: $showCopiedAlert) {
            Alert(
                title: Text("Command Copied!"),
                message: Text("The command has been copied to your clipboard.\n\nOpen Terminal and paste (⌘+V) to execute."),
                dismissButton: .default(Text("OK")) {
                    showCopiedAlert = false
                }
            )
        }
    }
    
    private func copyToClipboard(_ text: String) {
        DispatchQueue.main.async {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            let success = pasteboard.setString(text, forType: NSPasteboard.PasteboardType.string)
            
            if success {
                print("✅ Successfully copied to clipboard: \(text)")
            } else {
                print("❌ Failed to copy to clipboard")
            }
        }
    }
    
    
    private var microphoneIconName: String {
        switch microphoneManager.permissionStatus {
        case .granted:
            return "mic.fill"
        case .denied:
            return "mic.slash.fill"
        case .undetermined:
            return "questionmark.circle.fill"
        @unknown default:
            return "mic"
        }
    }
    
    private var microphoneIconColor: Color {
        switch microphoneManager.permissionStatus {
        case .granted:
            return .green
        case .denied:
            return .red
        case .undetermined:
            return .orange
        @unknown default:
            return .gray
        }
    }
    
    private var permissionStatusText: String {
        switch microphoneManager.permissionStatus {
        case .granted:
            return "Access Granted"
        case .denied:
            return "Access Denied"
        case .undetermined:
            return "Permission Required"
        @unknown default:
            return "Unknown Status"
        }
    }
    
    private func handlePermissionAction() {
        switch microphoneManager.permissionStatus {
        case .undetermined:
            // For undetermined, first try to request permission via system dialog
            microphoneManager.forcePermissionRequest()
        case .denied:
            // For denied, open System Settings
            openSystemSettings()
        case .granted:
            // Should not reach here since button is hidden when granted
            break
        @unknown default:
            openSystemSettings()
        }
    }
    
    private func openSystemSettings() {
        // Try the modern macOS 13+ URL first, then fallback to legacy URL
        if let url = URL(string: "x-apple.systempreferences:com.apple.Settings.PrivacySecurity.extension") {
            NSWorkspace.shared.open(url)
        } else if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }
}

#Preview {
    ContentView()
}
