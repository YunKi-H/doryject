//
//  FirestoreCalendarSharingMapperTests.swift
//  BloodyDayTests
//
//  Created by Yunki on 7/26/26.
//

import Foundation
import Testing
@testable import BloodyDay

struct FirestoreCalendarSharingMapperTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    @Test
    func connectionAndMembershipUseSameParticipantOrder() {
        let connection = CalendarConnection(
            id: "connection",
            ownerID: "recipient",
            ownerDisplayName: "Recipient",
            viewerID: "sender",
            viewerDisplayName: "Sender",
            sharedEventTypes: SharedEventTypeSelection(),
            createdAt: .now
        )

        let connectionData =
            FirestoreCalendarSharingMapper.connectionData(connection)
        let senderMembership =
            FirestoreCalendarSharingMapper.membershipData(
                userID: "sender",
                connection: connection
            )
        let recipientMembership =
            FirestoreCalendarSharingMapper.membershipData(
                userID: "recipient",
                connection: connection
            )

        let participantIDs = ["recipient", "sender"]
        #expect(
            connectionData["participantIDs"] as? [String]
                == participantIDs
        )
        #expect(
            senderMembership["participantIDs"] as? [String]
                == participantIDs
        )
        #expect(
            recipientMembership["participantIDs"] as? [String]
                == participantIDs
        )
        #expect(senderMembership["userID"] as? String == "sender")
        #expect(recipientMembership["userID"] as? String == "recipient")
    }

    @Test
    func lifecyclePayloadsUseExpectedStatuses() {
        let profile = CalendarSharingProfile(
            userID: "sender",
            displayName: "Sender",
            connectionCode: "ABCDEFGH"
        )

        let requestData =
            FirestoreCalendarSharingMapper.pendingRequestData(
                sender: profile,
                recipientID: "recipient"
            )
        let acceptedData =
            FirestoreCalendarSharingMapper.requestStatusData(.accepted)
        let terminationData =
            FirestoreCalendarSharingMapper.terminationData(
                requestedBy: "sender"
            )

        #expect(
            requestData["status"] as? String
                == CalendarConnectionRequestStatus.pending.rawValue
        )
        #expect(
            acceptedData["status"] as? String
                == CalendarConnectionRequestStatus.accepted.rawValue
        )
        #expect(
            terminationData["status"] as? String
                == FirestoreCalendarSharingMapper.ConnectionStatus
                    .terminating.rawValue
        )
        #expect(
            terminationData["terminationRequestedBy"] as? String
                == "sender"
        )
    }

    @Test
    func sharedPillEventPreservesCycleReference() throws {
        let cycleID = UUID()
        let event = UserEvent(
            date: makeDate(2026, 7, 8),
            type: .pill,
            pillCycleID: cycleID,
            calendar: calendar
        )

        let data = FirestoreCalendarSharingMapper.sharedEventData(
            event,
            ownerID: "owner",
            calendar: calendar
        )
        let mapped = try #require(
            FirestoreCalendarSharingMapper.sharedEvent(
                id: event.id.uuidString,
                data: data
            )
        )

        #expect(data["pillCycleID"] as? String == cycleID.uuidString)
        #expect(mapped.id == event.id)
        #expect(mapped.day == CalendarDay(
            date: event.date,
            calendar: calendar
        ))
        #expect(mapped.type == .pill)
        #expect(mapped.pillCycleID == cycleID)
    }

    @Test
    func sharedPillCyclePreservesHistoricalSettings() throws {
        let cycleID = UUID()
        let cycle = PillCycleInfo(
            id: cycleID,
            intakeDates: [
                makeDate(2026, 7, 8),
                makeDate(2026, 7, 9)
            ],
            plannedPillCount: 24,
            breakDays: 4,
            autoRecordEnabled: true,
            status: .completed
        )

        let data = try #require(
            FirestoreCalendarSharingMapper.sharedPillCycleData(
                cycle,
                ownerID: "owner",
                calendar: calendar
            )
        )
        let mapped = try #require(
            FirestoreCalendarSharingMapper.sharedPillCycle(
                id: cycleID.uuidString,
                data: data
            )
        )

        #expect(mapped.id == cycleID)
        #expect(mapped.startDay == CalendarDay(
            date: makeDate(2026, 7, 8),
            calendar: calendar
        ))
        #expect(mapped.plannedPillCount == 24)
        #expect(mapped.breakDays == 4)
        #expect(mapped.autoRecordEnabled == true)
        #expect(mapped.status == .completed)
    }

    private func makeDate(
        _ year: Int,
        _ month: Int,
        _ day: Int
    ) -> Date {
        calendar.date(
            from: DateComponents(year: year, month: month, day: day)
        )!
    }
}
