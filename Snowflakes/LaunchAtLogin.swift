//
//  LaunchAtLogin.swift
//  Snowflakes
//
//  Created by Andrew Sereda on 22.10.2025.
//  Enhanced launch at login functionality with auto-enable
//

import Foundation
import ServiceManagement
import Combine

final class LaunchAtLogin: ObservableObject {
    static let shared = LaunchAtLogin()
    
    @Published var isEnabled: Bool = false {
        didSet {
            guard isEnabled != oldValue else { return }
            updateLaunchAtLogin(isEnabled)
            saveSetting()
        }
    }
    
    private let defaultsKey = "LaunchAtLogin.enabled"
    
    private init() {
        loadSetting()
        checkAndAutoEnable()
    }
    
    private func loadSetting() {
        // Load saved preference, default to true for auto-enable
        let savedSetting = UserDefaults.standard.object(forKey: defaultsKey) as? Bool ?? true
        let systemStatus = SMAppService.mainApp.status == .enabled
        
        // Use the saved setting, but verify against system status
        isEnabled = savedSetting && systemStatus
    }
    
    private func saveSetting() {
        UserDefaults.standard.set(isEnabled, forKey: defaultsKey)
    }
    
    private func checkAndAutoEnable() {
        // Auto-enable on first run if user hasn't explicitly disabled it
        let hasUserSetPreference = UserDefaults.standard.object(forKey: defaultsKey) != nil
        
        if !hasUserSetPreference {
            // First run - auto enable
            enableLaunchAtLogin()
        } else if isEnabled && SMAppService.mainApp.status != .enabled {
            // User wants it enabled but system doesn't have it - fix it
            enableLaunchAtLogin()
        }
    }
    
    private func enableLaunchAtLogin() {
        isEnabled = true
    }
    
    private func updateLaunchAtLogin(_ enable: Bool) {
        do {
            if enable {
                if SMAppService.mainApp.status == .enabled {
                    return // Already enabled
                }
                try SMAppService.mainApp.register()
                print("✅ Launch at login enabled")
            } else {
                if SMAppService.mainApp.status == .notRegistered {
                    return // Already disabled
                }
                try SMAppService.mainApp.unregister()
                print("❌ Launch at login disabled")
            }
        } catch {
            print("Failed to \(enable ? "enable" : "disable") launch at login: \(error.localizedDescription)")
            
            // Revert on failure
            DispatchQueue.main.async { [weak self] in
                self?.isEnabled = !enable
            }
        }
    }
    
    func refresh() {
        // Refresh status from system
        let systemStatus = SMAppService.mainApp.status == .enabled
        if systemStatus != isEnabled {
            isEnabled = systemStatus
        }
    }
    
    // Manual toggle method for UI
    func toggle() {
        isEnabled.toggle()
    }
}
