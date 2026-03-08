//
//  PactDeviceActivityMonitorExtension.swift
//  PactDeviceActivityMonitor
//
//  Add this file to the PactDeviceActivityMonitor extension target in Xcode.
//  The target needs: DeviceActivity framework, FamilyControls entitlement, App Groups capability.
//

import Foundation
import DeviceActivity
import ManagedSettings
import FamilyControls

class PactDeviceActivityMonitorExtension: DeviceActivityMonitor {

    private let store = ManagedSettingsStore()
    private let appGroupID = "group.cmc.Pact"
    private let selectionKey = "familyActivitySelection"

    // MARK: - Schedule Events

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        guard activity == .pactDaily else { return }
        applyRestrictions()
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        guard activity == .pactDaily else { return }
        // End of day window — clear restrictions so midnight is unrestricted
        // until the next morning's intervalDidStart fires.
        store.clearAllSettings()
    }

    // MARK: - Helpers

    private func applyRestrictions() {
        guard let data = UserDefaults(suiteName: appGroupID)?
            .data(forKey: selectionKey),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        else { return }

        let apps = selection.applicationTokens
        let categories = selection.categoryTokens

        store.shield.applications = apps.isEmpty ? nil : apps
        store.shield.applicationCategories = categories.isEmpty ? nil : .specific(categories)
    }
}

// Mirror the DeviceActivityName constant — must match AppBlockingService.swift
extension DeviceActivityName {
    static let pactDaily = DeviceActivityName("pact.daily")
}
