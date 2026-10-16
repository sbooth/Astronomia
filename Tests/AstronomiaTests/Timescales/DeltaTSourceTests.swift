//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

@Suite struct DeltaTSourceTests {
	@Test func builtInSources() throws {
		let inTable = try JulianDate(decimalYear: 1900.25)
		let outsideTable = try JulianDate(decimalYear: 2026)

		#expect(DeltaTTable.historic.deltaT(at: inTable) == DeltaTTable.historic.deltaTAndUncertainty(at: inTable)?.seconds)
		#expect(DeltaTTable.historic.deltaT(at: outsideTable) == nil)

		// A model covers every date
		#expect(DeltaTModel.espenakMeeus2006.deltaT(at: inTable) == DeltaTModel.espenakMeeus2006.deltaT(decimalYear: inTable.decimalYear))
		#expect(DeltaTModel.espenakMeeus2006.deltaT(at: outsideTable) != nil)
	}

	@Test func sourceListUsesFirstSourceThatCovers() throws {
		let cutoff = try JulianDate(decimalYear: 2000)
		let list = DeltaTSourceList([
			DeltaTFunction { $0 < cutoff ? 1 : nil },
			DeltaTFunction.constant(2),
			DeltaTFunction.constant(3),
		])
		let before = try JulianDate(decimalYear: 1999)
		let after = try JulianDate(decimalYear: 2001)
		#expect(list.deltaT(at: before) == 1)
		#expect(list.deltaT(at: after) == 2)
		#expect(DeltaTSourceList([]).deltaT(at: cutoff) == nil)
	}

	@Test func defaultContextOrder() throws {
		// The historic table, then the model
		for decimalYear in [1600.0, 1900.25, 2026] {
			let tt = try JulianDate(decimalYear: decimalYear)
			let expected = DeltaTTable.historic.deltaT(at: tt) ?? DeltaTModel.espenakMeeus2006.deltaT(decimalYear: tt.decimalYear)
			#expect(try UT1.deltaT(at: tt, context: UT1.defaultContext) == expected)
		}
	}

	@Test func customOrder() throws {
		// Prefer the model over the table, for consistency with work based on the model
		let modelFirst = UT1.Context(deltaT: DeltaTSourceList([DeltaTModel.espenakMeeus2006, DeltaTTable.historic]))
		let tt = try JulianDate(decimalYear: 1900.25)
		#expect(try UT1.deltaT(at: tt, context: modelFirst) == DeltaTModel.espenakMeeus2006.deltaT(decimalYear: tt.decimalYear))
		#expect(try UT1.deltaT(at: tt, context: modelFirst) != DeltaTTable.historic.deltaT(at: tt))
	}

	@Test func constant() throws {
		let context = UT1.Context(deltaT: DeltaTFunction.constant(69.2))
		let tt = try JulianDate(decimalYear: 2026.5)
		let ut1 = try UT1.fromTT(tt, context: context)
		#expect(try abs(ut1.interval(to: tt).inSeconds - 69.2) <= 1e-6)
		let back = try UT1.toTT(ut1, context: context)
		#expect(try abs(tt.interval(to: back).inSeconds) <= 1e-9)
	}

	@Test func errors() throws {
		let tt = try JulianDate(decimalYear: 2026)
		#expect(throws: TimescaleConversionError.deltaTUnavailable) {
			try UT1.deltaT(at: tt, context: UT1.Context(deltaT: DeltaTSourceList([])))
		}
		#expect(throws: TimescaleConversionError.nonFiniteValue) {
			try UT1.deltaT(at: tt, context: UT1.Context(deltaT: DeltaTFunction.constant(.nan)))
		}
		#expect(throws: TimescaleConversionError.nonFiniteValue) {
			try UT1.fromTT(tt, context: UT1.Context(deltaT: DeltaTFunction.constant(.infinity)))
		}
	}
}
