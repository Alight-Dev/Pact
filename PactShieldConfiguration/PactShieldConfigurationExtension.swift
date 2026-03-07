//
//  PactShieldConfigurationExtension.swift
//  PactShieldConfiguration
//
//  Add this file to the PactShieldConfiguration extension target in Xcode.
//  The target needs: FamilyControls entitlement, App Groups capability.
//

import ManagedSettings
import ManagedSettingsUI
import UIKit

class PactShieldConfigurationExtension: ShieldConfigurationDataSource {

    // MARK: - Application Shield

    override func configuration(
        shielding application: Application
    ) -> ShieldConfiguration {
        makeShieldConfiguration()
    }

    // MARK: - Shared Configuration

    private func makeShieldConfiguration() -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialLight,
            backgroundColor: .white,
            icon: UIImage(named: "AppIcon"),
            title: ShieldConfiguration.Label(
                text: "App Blocked by Pact",
                color: .black
            ),
            subtitle: ShieldConfiguration.Label(
                text: "Complete today's activity and get it approved to unlock.",
                color: UIColor(white: 0.45, alpha: 1)
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Open Pact",
                color: .white
            ),
            primaryButtonBackgroundColor: .black
        )
    }
}
