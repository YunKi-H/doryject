//
//  PeriodForecastCalculatorTests.swift
//  BloodyDayTests
//
//  Created by Yunki on 2/23/26.
//

import Foundation
import Testing
@testable import BloodyDay

struct PeriodForecastCalculatorTests {
    private let calendar: Calendar = .current
    
    @Test
    func expectedStartDate_returnsNextCycleForFutureTargetAfterPredictedRange() {
        let firstExpected = makeDate(2026, 2, 10)
        let context = PeriodPredictionContext(
            firstExpected: firstExpected,
            cycleLength: 28,
            predictedLength: 5
        )
        
        let resolved = PeriodForecastCalculator.expectedStartDate(
            target: makeDate(2026, 2, 20),
            today: makeDate(2026, 2, 12),
            context: context,
            calendar: calendar
        )
        
        #expect(resolved == makeDate(2026, 3, 10))
    }

    @Test
    func delayedPeriodStart_returnsNilDuringPredictedPeriod() {
        let predictedStart = makeDate(2026, 2, 10)

        let delayedStart = PeriodForecastCalculator.delayedPeriodStart(
            for: makeDate(2026, 2, 14),
            predictedStarts: [predictedStart],
            predictedLength: 5,
            calendar: calendar
        )

        #expect(delayedStart == nil)
    }

    @Test
    func delayedPeriodStart_returnsExpectedStartAfterPredictedPeriodEnds() {
        let predictedStart = makeDate(2026, 2, 10)

        let delayedStart = PeriodForecastCalculator.delayedPeriodStart(
            for: makeDate(2026, 2, 15),
            predictedStarts: [predictedStart],
            predictedLength: 5,
            calendar: calendar
        )

        #expect(delayedStart == predictedStart)
    }
    
    @Test
    func latestPillCycleProjection_autoRecordOnUsesActualLastIntakeDate() {
        var settings = UserSettings()
        settings.pill.pillEnabled = true
        settings.pill.pillAutoRecordEnabled = true
        settings.pill.pillCount = 21
        settings.pill.pillBreakDuration = 7
        
        let start = makeDate(2026, 2, 1)
        let pillDates: Set<Date> = [start, addDays(start, 1), addDays(start, 3)]
        
        let projection = PeriodForecastCalculator.latestPillCycleProjection(
            settings: settings,
            pillDates: pillDates,
            calendar: calendar
        )
        
        #expect(projection?.cycleStart == start)
        #expect(projection?.lastIntakeDate == addDays(start, 3))
        #expect(projection?.projectedLastIntakeDate == addDays(start, 3))
        #expect(projection?.intakeCount == 3)
        #expect(projection?.cycleLength == 28)
    }
    
    @Test
    func latestPillCycleProjection_autoRecordOffProjectsToPackCompletionByIntakeCount() {
        var settings = UserSettings()
        settings.pill.pillEnabled = true
        settings.pill.pillAutoRecordEnabled = false
        settings.pill.pillCount = 21
        settings.pill.pillBreakDuration = 7
        
        let start = makeDate(2026, 2, 1)
        let lastIntake = addDays(start, 3)
        let pillDates: Set<Date> = [start, addDays(start, 1), lastIntake]
        
        let projection = PeriodForecastCalculator.latestPillCycleProjection(
            settings: settings,
            pillDates: pillDates,
            calendar: calendar
        )
        
        // 3 intakes recorded in a 21-pill cycle => 18 remaining, projected last = last intake + 18 days.
        #expect(projection?.projectedLastIntakeDate == addDays(lastIntake, 18))
        #expect(projection?.intakeCount == 3)
    }

    @Test
    func latestPillCycleProjection_usesNewCycleAfterPillCountCap() {
        var settings = UserSettings()
        settings.pill.pillEnabled = true
        settings.pill.pillAutoRecordEnabled = true
        settings.pill.pillCount = 21
        settings.pill.pillBreakDuration = 7

        let start = makeDate(2026, 2, 1)
        let pillDates: Set<Date> = Set((0..<23).map { addDays(start, $0) })

        let projection = PeriodForecastCalculator.latestPillCycleProjection(
            settings: settings,
            pillDates: pillDates,
            calendar: calendar
        )

        #expect(projection?.cycleStart == addDays(start, 21))
        #expect(projection?.lastIntakeDate == addDays(start, 22))
        #expect(projection?.projectedLastIntakeDate == addDays(start, 22))
        #expect(projection?.intakeCount == 2)
    }

    @Test
    func predictionContext_prefersLatestActualPeriodWhenItIsNewerThanPillAnchor() {
        var settings = UserSettings()
        settings.period.autoCyclePredictionEnabled = false
        settings.period.averageCycleDays = 28
        settings.period.averagePeriodDays = 5
        settings.pill.pillEnabled = true
        settings.pill.pillAutoRecordEnabled = true
        settings.pill.pillCount = 21
        settings.pill.pillBreakDuration = 7

        let actualStart = makeDate(2026, 3, 6)
        let summaries = summaries(fromRuns: [(start: actualStart, length: 5)])
        let pillCycleStart = makeDate(2026, 2, 14)
        let pillDates: Set<Date> = Set((0..<18).map { addDays(pillCycleStart, $0) })

        let context = PeriodForecastCalculator.predictionContext(
            target: makeDate(2026, 3, 11),
            settings: settings,
            periodSummaries: summaries,
            pillDates: pillDates,
            calendar: calendar
        )

        #expect(context?.firstExpected == makeDate(2026, 4, 3))
        #expect(context?.cycleLength == 28)
        #expect(context?.predictedLength == 5)
    }

    @Test
    func predictionContext_ignoresExpiredPillCycleAndUsesActualPeriodCycle() {
        var settings = UserSettings()
        settings.period.autoCyclePredictionEnabled = false
        settings.period.averageCycleDays = 28
        settings.period.averagePeriodDays = 5
        settings.pill.pillEnabled = true
        settings.pill.pillAutoRecordEnabled = true
        settings.pill.pillCount = 21
        settings.pill.pillBreakDuration = 7

        let actualStart = makeDate(2026, 3, 1)
        let summaries = summaries(fromRuns: [(start: actualStart, length: 5)])
        let stalePillStart = makeDate(2026, 1, 1)
        let pillDates = Set((0..<21).map { addDays(stalePillStart, $0) })

        let context = PeriodForecastCalculator.predictionContext(
            target: makeDate(2026, 4, 1),
            settings: settings,
            periodSummaries: summaries,
            pillDates: pillDates,
            calendar: calendar
        )

        #expect(context?.firstExpected == makeDate(2026, 3, 29))
        #expect(context?.cycleLength == 28)
    }
    
    @Test
    func suppressPredictedCycleArtifacts_removesOverlappingPredictedPeriodAndFertilityArtifacts() {
        let predictedStart = makeDate(2026, 2, 10)
        var predicted: [Date: [EventType]] = [:]
        
        for offset in 0..<5 {
            predicted[addDays(predictedStart, offset)] = [.period]
        }
        let ovulation = addDays(predictedStart, -14)
        predicted[ovulation, default: []].append(.ovulation)
        for offset in -19...(-13) { // ovulation-5 ... ovulation+1 relative to predictedStart
            predicted[addDays(predictedStart, offset), default: []].append(.fertile)
        }
        
        let actualSummaries = summaries(fromRuns: [(start: makeDate(2026, 2, 12), length: 5)])
        
        PeriodForecastCalculator.suppressPredictedCycleArtifactsOverlappingActualPeriods(
            predictedEventsByDay: &predicted,
            actualPeriodSummaries: actualSummaries,
            estimatedCycleLength: 28,
            calendar: calendar
        )
        
        for offset in 0..<5 {
            let day = addDays(predictedStart, offset)
            #expect(predicted[day]?.contains(.period) != true)
            #expect(predicted[day]?.contains(.delayed) != true)
        }
        #expect(predicted[ovulation]?.contains(.ovulation) != true)
        #expect(predicted[addDays(ovulation, -2)]?.contains(.fertile) != true)
    }
    
    @Test
    func validPredictedPeriodStarts_filtersOutRunInvalidatedByActualPeriod() {
        let rawStarts = [makeDate(2026, 2, 10), makeDate(2026, 3, 10)]
        let actualSummaries = summaries(fromRuns: [(start: makeDate(2026, 2, 12), length: 5)])
        
        let valid = PeriodForecastCalculator.validPredictedPeriodStarts(
            rawStarts: rawStarts,
            today: makeDate(2026, 1, 1),
            predictedLength: 5,
            actualPeriodSummaries: actualSummaries,
            estimatedCycleLength: 28,
            calendar: calendar
        )
        
        #expect(valid.count == 1)
        #expect(valid.first == makeDate(2026, 3, 10))
    }
    
    @Test
    func validPredictedPeriodStarts_filtersNearbyCycleByStartMatchingEvenWithoutOverlap() {
        let rawStarts = [makeDate(2026, 2, 10), makeDate(2026, 3, 10)]
        // Does not overlap 2/10...2/14, but start is within tolerance (distance 8 days for cycle 28 => tolerance 14)
        let actualSummaries = summaries(fromRuns: [(start: makeDate(2026, 2, 18), length: 5)])
        
        let valid = PeriodForecastCalculator.validPredictedPeriodStarts(
            rawStarts: rawStarts,
            today: makeDate(2026, 1, 1),
            predictedLength: 5,
            actualPeriodSummaries: actualSummaries,
            estimatedCycleLength: 28,
            calendar: calendar
        )
        
        #expect(valid == [makeDate(2026, 3, 10)])
    }
    
    private func summaries(fromRuns runs: [(start: Date, length: Int)]) -> [PeriodSummary] {
        let dates = runs.flatMap { run in
            (0..<run.length).map { addDays(run.start, $0) }
        }
        return PeriodSummaryBuilder.build(from: dates, calendar: calendar)
    }
    
    private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        let components = DateComponents(year: year, month: month, day: day, hour: 12)
        return calendar.date(from: components)!.startOfDay
    }
    
    private func addDays(_ date: Date, _ days: Int) -> Date {
        calendar.date(byAdding: .day, value: days, to: date)!.startOfDay
    }
}
