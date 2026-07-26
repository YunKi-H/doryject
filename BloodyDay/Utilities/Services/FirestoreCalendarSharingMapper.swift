//
//  FirestoreCalendarSharingMapper.swift
//  BloodyDay
//
//  Created by Yunki on 7/26/26.
//

import FirebaseFirestore
import Foundation

enum FirestoreCalendarSharingMapper {
    enum Collection {
        static let users = "users"
        static let connectionCodes = "connectionCodes"
        static let requests = "connectionRequests"
        static let connections = "connections"
        static let memberships = "connectionMemberships"
        static let events = "events"
        static let pillCycles = "pillCycles"
    }

    static func profile(
        userID: String,
        data: [String: Any]
    ) -> CalendarSharingProfile? {
        guard let displayName = data["displayName"] as? String,
              let connectionCode = data["connectionCode"] as? String else {
            return nil
        }
        return CalendarSharingProfile(
            userID: userID,
            displayName: displayName,
            connectionCode: connectionCode
        )
    }

    static func request(
        id: String,
        data: [String: Any]
    ) -> CalendarConnectionRequest? {
        guard let senderID = data["senderID"] as? String,
              let senderDisplayName = data["senderDisplayName"] as? String,
              let recipientID = data["recipientID"] as? String,
              let statusRaw = data["status"] as? String,
              let status = CalendarConnectionRequestStatus(rawValue: statusRaw),
              let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() else {
            return nil
        }
        return CalendarConnectionRequest(
            id: id,
            senderID: senderID,
            senderDisplayName: senderDisplayName,
            recipientID: recipientID,
            status: status,
            createdAt: createdAt
        )
    }

    static func connection(
        id: String,
        data: [String: Any]
    ) -> CalendarConnection? {
        guard let ownerID = data["ownerID"] as? String,
              let ownerDisplayName = data["ownerDisplayName"] as? String,
              let viewerID = data["viewerID"] as? String,
              let viewerDisplayName = data["viewerDisplayName"] as? String,
              let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() else {
            return nil
        }
        let sharedEventTypes = SharedEventTypeSelection(
            period: data["sharedPeriod"] as? Bool ?? true,
            pill: data["sharedPill"] as? Bool ?? true,
            love: data["sharedLove"] as? Bool ?? true
        )
        return CalendarConnection(
            id: id,
            ownerID: ownerID,
            ownerDisplayName: ownerDisplayName,
            viewerID: viewerID,
            viewerDisplayName: viewerDisplayName,
            sharedEventTypes: sharedEventTypes,
            createdAt: createdAt,
            computationSettings: computationSettings(data)
        )
    }

    static func computationSettingsData(
        _ settings: SharedCalendarComputationSettings,
        ownerID: String
    ) -> [String: Any] {
        [
            "periodAutoCyclePredictionEnabled":
                settings.period.autoCyclePredictionEnabled,
            "periodAverageCycleDays":
                settings.period.averageCycleDays.map { $0 as Any }
                    ?? FieldValue.delete(),
            "periodAveragePeriodDays":
                settings.period.averagePeriodDays.map { $0 as Any }
                    ?? FieldValue.delete(),
            "pillEnabled": settings.pill.pillEnabled,
            "pillAutoRecordEnabled": settings.pill.pillAutoRecordEnabled,
            "pillCount": settings.pill.pillCount,
            "pillBreakDuration": settings.pill.pillBreakDuration,
            "calculationUpdatedAt": FieldValue.serverTimestamp(),
            "calculationUpdatedBy": ownerID
        ]
    }

    static func sharedEventData(
        _ event: UserEvent,
        ownerID: String,
        calendar: Calendar
    ) -> [String: Any] {
        var data: [String: Any] = [
            "ownerID": ownerID,
            "eventID": event.id.uuidString,
            "dayKey": CalendarDay(
                date: event.resolvedDate(calendar: calendar),
                calendar: calendar
            ).dayKey,
            "typeRaw": event.type.rawValue,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        if event.type == .pill,
           let pillCycleID = event.pillCycleID {
            data["pillCycleID"] = pillCycleID.uuidString
        }
        return data
    }

    static func sharedEvent(
        id: String,
        data: [String: Any]
    ) -> SharedCalendarEvent? {
        guard let eventID = UUID(uuidString: data["eventID"] as? String ?? id),
              let dayKey = numericInt(data["dayKey"]),
              let day = CalendarDay(dayKey: dayKey),
              let typeRaw = data["typeRaw"] as? String,
              let type = EventType(rawValue: typeRaw),
              SharedEventTypeSelection().includes(type) else {
            return nil
        }
        return SharedCalendarEvent(
            id: eventID,
            day: day,
            type: type,
            pillCycleID: (data["pillCycleID"] as? String)
                .flatMap(UUID.init(uuidString:))
        )
    }

    static func sharedEventDataMatches(
        _ existing: [String: Any]?,
        expected: [String: Any]
    ) -> Bool {
        guard let existing else { return false }
        return existing["ownerID"] as? String == expected["ownerID"] as? String
            && existing["eventID"] as? String == expected["eventID"] as? String
            && numericInt(existing["dayKey"]) == numericInt(expected["dayKey"])
            && existing["typeRaw"] as? String == expected["typeRaw"] as? String
            && existing["pillCycleID"] as? String
                == expected["pillCycleID"] as? String
    }

    static func sharedPillCycleData(
        _ cycle: PillCycleInfo,
        ownerID: String,
        calendar: Calendar
    ) -> [String: Any]? {
        guard let startDate = cycle.startDate(calendar: calendar) else {
            return nil
        }
        var data: [String: Any] = [
            "ownerID": ownerID,
            "cycleID": cycle.id.uuidString,
            "startDayKey": CalendarDay(
                date: startDate,
                calendar: calendar
            ).dayKey,
            "statusRaw": cycle.status.rawValue,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        if let plannedPillCount = cycle.plannedPillCount {
            data["plannedPillCount"] = plannedPillCount
        }
        if let breakDays = cycle.breakDays {
            data["breakDays"] = breakDays
        }
        if let autoRecordEnabled = cycle.autoRecordEnabled {
            data["autoRecordEnabled"] = autoRecordEnabled
        }
        return data
    }

    static func sharedPillCycle(
        id: String,
        data: [String: Any]
    ) -> SharedPillCycleMetadata? {
        guard let cycleID = UUID(uuidString: data["cycleID"] as? String ?? id),
              let startDayKey = numericInt(data["startDayKey"]),
              let startDay = CalendarDay(dayKey: startDayKey),
              let statusRaw = data["statusRaw"] as? String,
              let status = PillCycleStatus(rawValue: statusRaw) else {
            return nil
        }
        return SharedPillCycleMetadata(
            id: cycleID,
            startDay: startDay,
            plannedPillCount: numericInt(data["plannedPillCount"]),
            breakDays: numericInt(data["breakDays"]),
            autoRecordEnabled: data["autoRecordEnabled"] as? Bool,
            status: status
        )
    }

    static func sharedPillCycleDataMatches(
        _ existing: [String: Any]?,
        expected: [String: Any]
    ) -> Bool {
        guard let existing else { return false }
        return existing["ownerID"] as? String == expected["ownerID"] as? String
            && existing["cycleID"] as? String
                == expected["cycleID"] as? String
            && numericInt(existing["startDayKey"])
                == numericInt(expected["startDayKey"])
            && numericInt(existing["plannedPillCount"])
                == numericInt(expected["plannedPillCount"])
            && numericInt(existing["breakDays"])
                == numericInt(expected["breakDays"])
            && existing["autoRecordEnabled"] as? Bool
                == expected["autoRecordEnabled"] as? Bool
            && existing["statusRaw"] as? String
                == expected["statusRaw"] as? String
    }

    private static func numericInt(_ value: Any?) -> Int? {
        if let value = value as? Int {
            return value
        }
        if let value = value as? Int64 {
            return Int(value)
        }
        if let value = value as? NSNumber {
            return value.intValue
        }
        return nil
    }

    private static func computationSettings(
        _ data: [String: Any]
    ) -> SharedCalendarComputationSettings? {
        guard let autoPrediction =
                data["periodAutoCyclePredictionEnabled"] as? Bool,
              let pillEnabled = data["pillEnabled"] as? Bool,
              let pillAutoRecord = data["pillAutoRecordEnabled"] as? Bool,
              let pillCount = numericInt(data["pillCount"]),
              let pillBreakDuration = numericInt(data["pillBreakDuration"]) else {
            return nil
        }

        let period = PeriodSettings(
            autoCyclePredictionEnabled: autoPrediction,
            averageCycleDays: numericInt(data["periodAverageCycleDays"]),
            averagePeriodDays: numericInt(data["periodAveragePeriodDays"])
        )
        var pill = PillSettings()
        pill.pillEnabled = pillEnabled
        pill.pillAutoRecordEnabled = pillAutoRecord
        pill.pillCount = pillCount
        pill.pillBreakDuration = pillBreakDuration
        return SharedCalendarComputationSettings(period: period, pill: pill)
    }
}
