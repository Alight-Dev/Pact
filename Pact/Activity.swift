//
//  Activity.swift
//  Pact
//
//  Created by Yaw Snr Owusu on 2/25/26.
//

import Foundation
import SwiftData

@Model
final class Activity {
    var name: String
    var activityDescription: String
    var iconName: String
    var order: Int
    var createdAt: Date

    init(name: String, activityDescription: String, iconName: String, order: Int = 0) {
        self.name = name
        self.activityDescription = activityDescription
        self.iconName = iconName
        self.order = order
        self.createdAt = Date()
    }
}
