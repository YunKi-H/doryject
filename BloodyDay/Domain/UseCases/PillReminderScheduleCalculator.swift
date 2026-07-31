//
//  PillReminderScheduleCalculator.swift
//  BloodyDay
//
//  Created by Yunki on 7/24/26.
//

import Foundation

enum PillReminderScheduleCalculator {
    static func upcomingIntakeDates(
        projection: PillCycleProjection,
        from date: Date,
        count: Int,
        calendar: Calendar = .autoupdatingCurrent
    ) -> [Date] {
        guard count > 0, projection.pillCount > 0 else { return [] }

        let target = calendar.startOfDay(for: date)
        let currentCycleStart = calendar.startOfDay(for: projection.cycleStart)
        let currentCycleEnd = calendar.startOfDay(for: projection.projectedLastIntakeDate)
        var dates: [Date] = []

        appendIntakeDates(
            from: max(target, currentCycleStart),
            through: currentCycleEnd,
            limit: count,
            calendar: calendar,
            to: &dates
        )

        guard dates.count < count,
              let firstNextCycleStart = calendar.date(
                byAdding: .day,
                value: projection.breakDays + 1,
                to: currentCycleEnd
              ).map({ calendar.startOfDay(for: $0) }) else {
            return dates
        }

        let cycleLength = projection.cycleLength
        guard cycleLength > 0 else { return dates }

        var nextCycleStart = firstNextCycleStart
        if nextCycleStart < target {
            let daysFromNextCycle = calendar.dateComponents(
                [.day],
                from: nextCycleStart,
                to: target
            ).day ?? 0
            let cyclesToSkip = max(daysFromNextCycle / cycleLength, 0)
            if cyclesToSkip > 0,
               let skippedStart = calendar.date(
                   byAdding: .day,
                   value: cyclesToSkip * cycleLength,
                   to: nextCycleStart
               ) {
                nextCycleStart = calendar.startOfDay(for: skippedStart)
            }
        }

        while dates.count < count {
            guard let cycleEndExclusive = calendar.date(
                byAdding: .day,
                value: projection.pillCount,
                to: nextCycleStart
            ).map({ calendar.startOfDay(for: $0) }) else {
                break
            }

            appendIntakeDates(
                from: max(target, nextCycleStart),
                through: calendar.date(
                    byAdding: .day,
                    value: -1,
                    to: cycleEndExclusive
                ).map({ calendar.startOfDay(for: $0) }) ?? nextCycleStart,
                limit: count,
                calendar: calendar,
                to: &dates
            )

            guard dates.count < count,
                  let followingCycleStart = calendar.date(
                    byAdding: .day,
                    value: cycleLength,
                    to: nextCycleStart
                  ) else {
                break
            }
            nextCycleStart = calendar.startOfDay(for: followingCycleStart)
        }

        return dates
    }

    private static func appendIntakeDates(
        from start: Date,
        through end: Date,
        limit: Int,
        calendar: Calendar,
        to dates: inout [Date]
    ) {
        guard start <= end else { return }

        var cursor = start
        while cursor <= end, dates.count < limit {
            dates.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else {
                break
            }
            cursor = calendar.startOfDay(for: next)
        }
    }
}
