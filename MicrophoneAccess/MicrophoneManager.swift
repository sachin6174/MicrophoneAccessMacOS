//
//  MicrophoneManager.swift
//  MicrophoneAccess
//
//  Created by sachin kumar on 04/07/25.
//

import Foundation
import AVFoundation
import SwiftUI
import Combine

enum MicrophonePermissionStatus {
    case undetermined
    case granted
    case denied
}

class MicrophoneManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var permissionStatus: MicrophonePermissionStatus = .undetermined
    @Published var audioLevel: Float = 0.0
    
    private var audioRecorder: AVAudioRecorder?
    private var levelTimer: Timer?
    private var permissionCheckTimer: Timer?
    
    override init() {
        super.init()
        checkPermissionStatus()
        startPermissionMonitoring()
        
        // Listen for app becoming active to refresh permission status
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        permissionCheckTimer?.invalidate()
    }
    
    @objc private func appDidBecomeActive() {
        // Refresh permission status when app becomes active
        // This catches changes made in System Settings
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.checkPermissionStatus()
        }
    }
    
    private func startPermissionMonitoring() {
        // Check permission status every 2 seconds to catch manual changes
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkPermissionStatus()
        }
    }
    
    func checkPermissionStatus() {
        let currentStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        let newStatus: MicrophonePermissionStatus
        
        switch currentStatus {
        case .authorized:
            newStatus = .granted
            print("✅ Microphone permission: GRANTED")
        case .denied, .restricted:
            newStatus = .denied
            print("❌ Microphone permission: DENIED")
        case .notDetermined:
            newStatus = .undetermined
            print("⚠️ Microphone permission: NOT DETERMINED")
        @unknown default:
            newStatus = .undetermined
            print("⚠️ Microphone permission: UNKNOWN")
        }
        
        if newStatus != permissionStatus {
            DispatchQueue.main.async {
                self.permissionStatus = newStatus
                print("🔄 Permission status changed to: \(newStatus)")
            }
        }
    }
    
    func requestMicrophonePermission() {
        print("📋 Requesting microphone permission...")
        
        // Use Apple's recommended approach from AVFoundation documentation
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            DispatchQueue.main.async {
                print("🎯 Permission request completed: \(granted)")
                self?.permissionStatus = granted ? .granted : .denied
                self?.checkPermissionStatus()
                
                if granted {
                    print("✅ Microphone access GRANTED - app will appear in System Settings")
                } else {
                    print("❌ Microphone access DENIED - user can change in System Settings > Privacy & Security > Microphone")
                }
            }
        }
    }
    
    func forcePermissionRequest() {
        print("🔄 Force requesting microphone permission...")
        
        // Check current status first (Apple's recommended pattern)
        let currentStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        print("📊 Current authorization status: \(currentStatus)")
        
        if currentStatus == .notDetermined {
            // Only request if not determined (following Apple guidelines)
            requestMicrophonePermission()
        } else {
            // Update our internal status to match system status
            checkPermissionStatus()
            print("ℹ️ Permission already determined. Current status: \(permissionStatus)")
        }
    }
    
    // Apple's recommended async pattern for modern apps
    var isAuthorized: Bool {
        get async {
            let status = AVCaptureDevice.authorizationStatus(for: .audio)
            
            // Determine if the user previously authorized microphone access
            var isAuthorized = status == .authorized
            
            // If the system hasn't determined the user's authorization status,
            // explicitly prompt them for approval (following Apple's documentation)
            if status == .notDetermined {
                isAuthorized = await AVCaptureDevice.requestAccess(for: .audio)
                
                // Update our published status
                DispatchQueue.main.async {
                    self.permissionStatus = isAuthorized ? .granted : .denied
                }
            }
            
            return isAuthorized
        }
    }
    
    func refreshPermissionStatus() {
        // Force an immediate permission status refresh
        let currentStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        print("Current authorization status: \(currentStatus)")
        checkPermissionStatus()
    }
    
    func startRecording() {
        print("🎤 Starting recording process...")
        
        // Always check permission status first
        checkPermissionStatus()
        
        if permissionStatus == .undetermined {
            print("📝 Permission undetermined, requesting access...")
            requestMicrophonePermission()
            return
        }
        
        guard permissionStatus == .granted else {
            print("🚫 Cannot start recording - permission denied")
            return
        }
        
        do {
            // Use Documents directory for better access
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let audioFilename = documentsPath.appendingPathComponent("recording_\(Date().timeIntervalSince1970).m4a")
            
            print("📁 Recording to: \(audioFilename.path)")
            
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.prepareToRecord()
            
            let success = audioRecorder?.record() ?? false
            if success {
                isRecording = true
                startLevelMonitoring()
                print("✅ Recording started successfully!")
            } else {
                print("❌ Failed to start recording - record() returned false")
            }
            
        } catch {
            print("💥 Failed to start recording with error: \(error)")
            print("Error details: \(error.localizedDescription)")
        }
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        isRecording = false
        stopLevelMonitoring()
    }
    
    private func startLevelMonitoring() {
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateAudioLevel()
        }
    }
    
    private func stopLevelMonitoring() {
        levelTimer?.invalidate()
        levelTimer = nil
        audioLevel = 0.0
    }
    
    private func updateAudioLevel() {
        guard let recorder = audioRecorder, recorder.isRecording else { return }
        
        recorder.updateMeters()
        let power = recorder.averagePower(forChannel: 0)
        let normalizedLevel = pow(10, power / 20)
        audioLevel = normalizedLevel
    }
    
    func revokePermission() -> Bool {
        print("🔄 Attempting to revoke microphone permission using tccutil...")
        
        // Get the app's bundle identifier
        guard let bundleId = Bundle.main.bundleIdentifier else {
            print("❌ Could not get bundle identifier")
            return false
        }
        
        print("📱 Bundle ID: \(bundleId)")
        
        // Create the tccutil command
        let command = "tccutil reset Microphone \(bundleId)"
        print("🔧 Running command: \(command)")
        
        // Execute the command
        let task = Process()
        task.launchPath = "/usr/bin/tccutil"
        task.arguments = ["reset", "Microphone", bundleId]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            if task.terminationStatus == 0 {
                print("✅ Successfully revoked microphone permission")
                print("📄 Output: \(output)")
                
                // Wait a moment then refresh permission status
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.checkPermissionStatus()
                }
                return true
            } else {
                print("❌ Failed to revoke permission. Exit code: \(task.terminationStatus)")
                print("📄 Error output: \(output)")
                print("ℹ️ Note: tccutil requires Full Disk Access or may not work in sandboxed apps")
                return false
            }
        } catch {
            print("❌ Error executing tccutil: \(error)")
            print("ℹ️ Sandboxed apps cannot execute tccutil. This is expected behavior.")
            print("💡 Alternative: Direct user to System Settings > Privacy & Security > Microphone")
            return false
        }
    }
    
    func copyTccutilCommand() {
        guard let bundleId = Bundle.main.bundleIdentifier else {
            print("❌ Could not get bundle identifier")
            return
        }
        
        let command = "tccutil reset Microphone \(bundleId)"
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(command, forType: NSPasteboard.PasteboardType.string)
        print("📋 Copied tccutil command to clipboard: \(command)")
    }
}

