//
//  PeriodSettings.swift
//  BloodyDay
//
//  Created by Yunki on 1/8/26.
//

import Foundation

struct PeriodSettings: Codable, Equatable, Sendable {
    var autoCyclePredictionEnabled: Bool = true
    var averageCycleDays: Int? = nil
    var averagePeriodDays: Int? = nil

    init(
        autoCyclePredictionEnabled: Bool = true,
        averageCycleDays: Int? = nil,
        averagePeriodDays: Int? = nil
    ) {
        self.autoCyclePredictionEnabled = autoCyclePredictionEnabled
        self.averageCycleDays = averageCycleDays
        self.averagePeriodDays = averagePeriodDays
    }

    private enum CodingKeys: String, CodingKey {
        case autoCyclePredictionEnabled
        case averageCycleDays
        case averagePeriodDays
    }

    init(from decoder: Decoder) throws {
        let defaults = Self()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        autoCyclePredictionEnabled = try container.decode(
            Bool.self,
            forKey: .autoCyclePredictionEnabled,
            default: defaults.autoCyclePredictionEnabled
        )
        averageCycleDays = try container.decodeIfPresent(
            Int.self,
            forKey: .averageCycleDays
        )
        averagePeriodDays = try container.decodeIfPresent(
            Int.self,
            forKey: .averagePeriodDays
        )
    }
}
