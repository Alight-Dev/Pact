//
//  ShieldConfigurationExtension.swift
//  PactShieldConfiguration
//
//  This is the class loaded by iOS — NSExtensionPrincipalClass in Info.plist
//  resolves to $(PRODUCT_MODULE_NAME).ShieldConfigurationExtension.
//

import ManagedSettings
import ManagedSettingsUI
import UIKit

class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    // MARK: - Application shields

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        makeShieldConfiguration()
    }

    override func configuration(
        shielding application: Application,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        makeShieldConfiguration()
    }

    // MARK: - Web domain shields

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        makeShieldConfiguration()
    }

    override func configuration(
        shielding webDomain: WebDomain,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        makeShieldConfiguration()
    }

    // MARK: - Shared configuration

    private func makeShieldConfiguration() -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialLight,
            backgroundColor: .white,
            icon: UIImage(named: "PactLogo"),
            title: ShieldConfiguration.Label(
                text: "Blocked by Pact",
                color: .black
            ),
            subtitle: ShieldConfiguration.Label(
                text: "Complete your tasks today to unlock this app.",
                color: UIColor(white: 0.45, alpha: 1)
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "OK",
                color: .white
            ),
            primaryButtonBackgroundColor: .black
        )
    }
}
