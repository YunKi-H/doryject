//
//  CalendarConnectionCodeGeneratorTests.swift
//  BloodyDayTests
//
//  Created by Yunki on 7/26/26.
//

import Testing
@testable import BloodyDay

struct CalendarConnectionCodeGeneratorTests {
    @Test
    func normalizesCaseWhitespaceSeparatorsAndAmbiguousCharacters() {
        let normalized = CalendarConnectionCodeGenerator.normalize(
            " o0i1-abcd-2345 "
        )

        #expect(normalized == "ABCD2345")
    }

    @Test
    func generatedCodeHasEightSupportedCharacters() {
        let code = CalendarConnectionCodeGenerator.make()

        #expect(code.count == 8)
        #expect(CalendarConnectionCodeGenerator.normalize(code) == code)
    }
}
