//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

@Suite struct DeltaTTableTests {
	typealias Entry = DeltaTTable.Entry

	@Test func rejectsInvalidEntries() {
		#expect(DeltaTTable(entries: []) == nil)
		#expect(DeltaTTable(entries: [Entry(decimalYear: 2000, deltaT: 64)]) == nil)
		// Not strictly increasing
		#expect(DeltaTTable(entries: [Entry(decimalYear: 2000, deltaT: 64), Entry(decimalYear: 2000, deltaT: 65)]) == nil)
		#expect(DeltaTTable(entries: [Entry(decimalYear: 2001, deltaT: 64), Entry(decimalYear: 2000, deltaT: 65)]) == nil)
		// Not finite
		#expect(DeltaTTable(entries: [Entry(decimalYear: 2000, deltaT: .nan), Entry(decimalYear: 2001, deltaT: 65)]) == nil)
		#expect(DeltaTTable(entries: [Entry(decimalYear: 2000, deltaT: 64), Entry(decimalYear: .infinity, deltaT: 65)]) == nil)
		#expect(DeltaTTable(entries: [Entry(decimalYear: 2000, deltaT: 64, uncertainty: .infinity), Entry(decimalYear: 2001, deltaT: 65)]) == nil)
		// Negative uncertainty
		#expect(DeltaTTable(entries: [Entry(decimalYear: 2000, deltaT: 64, uncertainty: -1), Entry(decimalYear: 2001, deltaT: 65)]) == nil)

		#expect(DeltaTTable(entries: [Entry(decimalYear: 2000, deltaT: 64), Entry(decimalYear: 2001, deltaT: 65)]) != nil)
	}

	@Test func interpolatesLinearly() throws {
		let table = try #require(DeltaTTable(entries: [
			Entry(decimalYear: 2000, deltaT: 64, uncertainty: 1),
			Entry(decimalYear: 2001, deltaT: 65, uncertainty: 3),
			Entry(decimalYear: 2003, deltaT: 61),
		]))
		#expect(table.range == 2000 ... 2003)

		let start = try #require(table.deltaTAndUncertainty(decimalYear: 2000))
		#expect(start.seconds == 64 && start.uncertainty == 1)
		let quarter = try #require(table.deltaTAndUncertainty(decimalYear: 2000.25))
		#expect(quarter.seconds == 64.25 && quarter.uncertainty == 1.5)
		let entry = try #require(table.deltaTAndUncertainty(decimalYear: 2001))
		#expect(entry.seconds == 65 && entry.uncertainty == 3)

		// No uncertainty unless both neighbors have one
		let later = try #require(table.deltaTAndUncertainty(decimalYear: 2002))
		#expect(later.seconds == 63 && later.uncertainty == nil)
		let end = try #require(table.deltaTAndUncertainty(decimalYear: 2003))
		#expect(end.seconds == 61 && end.uncertainty == nil)

		#expect(table.deltaTAndUncertainty(decimalYear: 1999.999) == nil)
		#expect(table.deltaTAndUncertainty(decimalYear: 2003.001) == nil)
	}

	@Test func historic() throws {
		let entries = DeltaTTable.historic.entries
		#expect(entries.count == 656)
		#expect(DeltaTTable.historic.range == 1657 ... 1984.5)
		#expect(DeltaTTable(entries: entries) != nil)
		for (index, entry) in entries.enumerated() {
			#expect(entry.decimalYear == 1657 + Double(index) / 2)
			#expect(entry.uncertainty != nil)
		}

		#expect(entries.first == Entry(decimalYear: 1657, deltaT: 44, uncertainty: 12))
		#expect(entries[1] == Entry(decimalYear: 1657.5, deltaT: 43, uncertainty: 15))
		#expect(entries.last == Entry(decimalYear: 1984.5, deltaT: 54.087, uncertainty: 0.001))
	}
}

@Suite struct UT1DeltaTSourceTests {
	@Test(arguments: [1657.25, 1700.25, 1900, 1984.25])
	func defaultUsesHistoricTable(decimalYear: Double) throws {
		let tt = try JulianDate(decimalYear: decimalYear)
		let tabulated = try #require(DeltaTTable.historic.deltaT(at: tt))
		#expect(try UT1.deltaT(at: tt, context: UT1.defaultContext) == tabulated)
	}

	@Test(arguments: [1600.0, 1656.9, 1985, 2026])
	func modelOutsideTable(decimalYear: Double) throws {
		let tt = try JulianDate(decimalYear: decimalYear)
		#expect(DeltaTTable.historic.deltaT(at: tt) == nil)
		#expect(try UT1.deltaT(at: tt, context: UT1.defaultContext) == DeltaTModel.espenakMeeus2006.deltaT(decimalYear: tt.decimalYear))
	}

	@Test func tableAgreesWithModelAtHandover() throws {
		// The model is fitted to Morrison & Stephenson (2004), not to this table, so the two
		// differ by 3.7 s at 1657 (within the table's 12 s uncertainty) and 0.04 s at 1984.5.
		for (decimalYear, tolerance) in [(1657.0, 4.0), (1984.5, 0.05)] {
			let table = try #require(DeltaTTable.historic.deltaTAndUncertainty(decimalYear: decimalYear))
			#expect(abs(table.seconds - DeltaTModel.espenakMeeus2006.deltaT(decimalYear: decimalYear)) < tolerance)
		}
	}

	@Test func requiresTabulatedValuesWithoutModel() throws {
		let context = UT1.Context(model: nil)
		let inTable = try JulianDate(decimalYear: 1900)
		let tabulated = try #require(DeltaTTable.historic.deltaT(at: inTable))
		#expect(try UT1.deltaT(at: inTable, context: context) == tabulated)

		let outsideTable = try JulianDate(decimalYear: 2026)
		#expect(throws: TimescaleConversionError.deltaTUnavailable) {
			try UT1.deltaT(at: outsideTable, context: context)
		}

		let noTable = UT1.Context(deltaTTable: nil, model: nil)
		#expect(throws: TimescaleConversionError.deltaTUnavailable) {
			try UT1.deltaT(at: inTable, context: noTable)
		}
	}

	@Test func roundTripThroughTable() throws {
		let ut1 = try JulianDate(decimalYear: 1850.3)
		let tt = try UT1.toTT(ut1, context: UT1.defaultContext)
		let back = try UT1.fromTT(tt, context: UT1.defaultContext)
		#expect(try abs(ut1.interval(to: back).inSeconds) <= 1e-6)
	}
}
