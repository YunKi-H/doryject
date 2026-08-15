//
//  CalendarScopeNotificationSchedulerTests.swift
//  BloodyDayTests
//
//  Created by Yunki on 8/15/26.
//

import Foundation
import Testing
@testable import BloodyDay

struct CalendarScopeNotificationSchedulerTests {
    @Test
    func sharedCalendarDisablesEveryManagedNotificationWithoutMutatingInput() {
        let recorder = ScopeNotificationRecorder()
        let scheduler = CalendarScopeNotificationScheduler(base: recorder)
        let settings = UserSettings(
            notifications: NotificationSettings(
                periodReminderEnabled: true,
                periodDelayedEnabled: true,
                pillReminderEnabled: true,
                pillPurchaseReminderEnabled: true
            )
        )
        scheduler.setSharedCalendarActive(true)

        scheduler.apply(
            settings: settings,
            eventRepository: MockEventRepository()
        )

        #expect(recorder.settings?.notifications.periodReminderEnabled == false)
        #expect(recorder.settings?.notifications.periodDelayedEnabled == false)
        #expect(recorder.settings?.notifications.pillReminderEnabled == false)
        #expect(
            recorder.settings?.notifications.pillPurchaseReminderEnabled
                == false
        )
        #expect(settings.notifications.periodReminderEnabled)
        #expect(settings.notifications.periodDelayedEnabled)
        #expect(settings.notifications.pillReminderEnabled)
        #expect(settings.notifications.pillPurchaseReminderEnabled)
    }

    @Test
    func returningToLocalCalendarRestoresSavedNotificationSettings() {
        let recorder = ScopeNotificationRecorder()
        let scheduler = CalendarScopeNotificationScheduler(base: recorder)
        let settings = UserSettings(
            notifications: NotificationSettings(
                periodReminderEnabled: true,
                pillReminderEnabled: true
            )
        )
        scheduler.setSharedCalendarActive(true)
        scheduler.apply(
            settings: settings,
            eventRepository: MockEventRepository()
        )

        scheduler.setSharedCalendarActive(false)
        scheduler.apply(
            settings: settings,
            eventRepository: MockEventRepository()
        )

        #expect(recorder.settings?.notifications.periodReminderEnabled == true)
        #expect(recorder.settings?.notifications.pillReminderEnabled == true)
    }

    @Test
    func sharedCalendarPreventsNotificationSettingChanges() {
        let repository = ScopeNotificationSettingsRepository()
        let viewModel = NotificationSettingsViewModel(
            repo: repository,
            scheduler: NoopNotificationScheduler(),
            eventRepository: MockEventRepository()
        )
        viewModel.setSharedCalendarActive(true)

        viewModel.updateNotifications {
            $0.periodReminderEnabled = false
        }

        #expect(repository.load().notifications.periodReminderEnabled)
        #expect(
            viewModel.displayedNotifications.periodReminderEnabled == false
        )
        viewModel.setSharedCalendarActive(false)
        #expect(viewModel.displayedNotifications.periodReminderEnabled)
    }
}

private final class ScopeNotificationRecorder: NotificationScheduler {
    private(set) var settings: UserSettings?

    func apply(settings: UserSettings, eventRepository: EventRepository) {
        self.settings = settings
    }
}

private final class ScopeNotificationSettingsRepository: SettingsRepository {
    private var settings = UserSettings()

    func load() -> UserSettings { settings }

    func save(_ settings: UserSettings) {
        self.settings = settings
    }
}
