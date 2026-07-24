//
//  PillSettingsViewModelTests.swift
//  BloodyDayTests
//
//  Created by Yunki on 7/24/26.
//

import Testing
@testable import BloodyDay

struct PillSettingsViewModelTests {
    @Test
    func updatePill_persistsSettingsAndRefreshesDerivedState() {
        let repository = PillSettingsTestRepository()
        let refresher = RecordingSettingsChangeRefresher()
        let viewModel = PillSettingsViewModel(
            repo: repository,
            settingsChangeRefresher: refresher
        )

        viewModel.updatePill {
            $0.pillEnabled = true
            $0.pillCount = 28
            $0.pillBreakDuration = 4
        }

        #expect(repository.load().pill.pillEnabled)
        #expect(repository.load().pill.pillCount == 28)
        #expect(repository.load().pill.pillBreakDuration == 4)
        #expect(refresher.refreshCount == 1)
        #expect(refresher.lastSettings?.pill.pillEnabled == true)
        #expect(refresher.lastSettings?.pill.pillCount == 28)
        #expect(refresher.lastSettings?.pill.pillBreakDuration == 4)
    }
}

private final class PillSettingsTestRepository: SettingsRepository {
    private var settings = UserSettings()

    func load() -> UserSettings {
        settings
    }

    func save(_ settings: UserSettings) {
        self.settings = settings
    }
}

private final class RecordingSettingsChangeRefresher: SettingsChangeRefreshing {
    private(set) var refreshCount = 0
    private(set) var lastSettings: UserSettings?

    func refresh(using settings: UserSettings) {
        refreshCount += 1
        lastSettings = settings
    }
}
