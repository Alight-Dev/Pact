//
//  AppBlockingService.swift
//  Pact
//

import FamilyControls
import ManagedSettings
import DeviceActivity
import Foundation

final class AppBlockingService {
    static let shared = AppBlockingService()
    private init() {}

    /// Must match the App Group ID added in Xcode for all three targets.
    static let appGroupID = "group.cmc.Pact"
    static let selectionKey = "familyActivitySelection"

    private let store = ManagedSettingsStore()

    // MARK: - Lock

    /// Reads the saved FamilyActivitySelection from App Group UserDefaults and applies shields.
    func lock() {
        guard let data = UserDefaults(suiteName: Self.appGroupID)?
            .data(forKey: Self.selectionKey),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        else { return }

        let apps = selection.applicationTokens
        let categories = selection.categoryTokens

        store.shield.applications = apps.isEmpty ? nil : apps
        store.shield.applicationCategories = categories.isEmpty ? nil : .specific(categories)
    }

    // MARK: - Unlock

    /// Clears all ManagedSettings restrictions — call when one activity is approved.
    func unlock() {
        store.clearAllSettings()
    }

    // MARK: - Schedule

    /// Schedules a recurring daily DeviceActivity window starting at `lockHour`:00.
    /// The DeviceActivityMonitor extension fires `intervalDidStart` each morning and re-applies the lock.
    /// Safe to call multiple times; replaces any existing schedule with the same name.
    func scheduleMorningLock(lockHour: Int = 6) {
        let center = DeviceActivityCenter()
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: lockHour, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )
        try? center.startMonitoring(.pactDaily, during: schedule)
    }

    /// Stops the morning lock schedule (call when user leaves their team).
    func cancelSchedule() {
        DeviceActivityCenter().stopMonitoring([.pactDaily])
    }
}

// MARK: - DeviceActivityName

extension DeviceActivityName {
    static let pactDaily = DeviceActivityName("pact.daily")
}
