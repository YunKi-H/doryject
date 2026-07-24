//
//  PeriodSettingViewModelTests.swift
//  BloodyDayTests
//
//  Created by Yunki on 7/24/26.
//

import Testing
@testable import BloodyDay

struct PeriodSettingViewModelTests {
    @Test
    func updateAverages_persistsSettingsAndRefreshesDerivedState() {
        let repository = PeriodSettingsTestRepository()
        let refresher = PeriodSettingsRefreshRecorder()
        let viewModel = PeriodSettingViewModel(
            repo: repository,
            settingsChangeRefresher: refresher
        )

        viewModel.updateAverages(cycle: 30, period: 6)

        #expect(repository.load().period.averageCycleDays == 30)
        #expect(repository.load().period.averagePeriodDays == 6)
        #expect(refresher.refreshCount == 1)
        #expect(refresher.lastSettings?.period.averageCycleDays == 30)
        #expect(refresher.lastSettings?.period.averagePeriodDays == 6)
    }
}

private final class PeriodSettingsTestRepository: SettingsRepository {
    private var settings = UserSettings()

    func load() -> UserSettings {
        settings
    }

    func save(_ settings: UserSettings) {
        self.settings = settings
    }
}

private final class PeriodSettingsRefreshRecorder: SettingsChangeRefreshing {
    private(set) var refreshCount = 0
    private(set) var lastSettings: UserSettings?

    func refresh(using settings: UserSettings) {
        refreshCount += 1
        lastSettings = settings
    }
}
