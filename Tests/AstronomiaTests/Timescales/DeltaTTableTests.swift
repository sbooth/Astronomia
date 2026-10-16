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

	/// Returns an entry at a decimal year.
	static func entry(_ decimalYear: Double, _ deltaT: Double, uncertainty: Double? = nil) throws -> Entry {
		try Entry(decimalYear: decimalYear, deltaT: deltaT, uncertainty: uncertainty)
	}

	@Test func entryFromDecimalYear() throws {
		#expect(try Self.entry(2000.25, 64) == Entry(tt: JulianDate(decimalYear: 2000.25), deltaT: 64))
		#expect(throws: CalendarError.nonFiniteValue) {
			try Self.entry(.infinity, 64)
		}
		#expect(throws: CalendarError.invalidDecimalYear) {
			try Self.entry(1e300, 64)
		}
	}

	@Test func rejectsInvalidEntries() throws {
		#expect(DeltaTTable(entries: []) == nil)
		#expect(try DeltaTTable(entries: [Self.entry(2000, 64)]) == nil)
		// Not strictly increasing
		#expect(try DeltaTTable(entries: [Self.entry(2000, 64), Self.entry(2000, 65)]) == nil)
		#expect(try DeltaTTable(entries: [Self.entry(2001, 64), Self.entry(2000, 65)]) == nil)
		// Not finite
		#expect(try DeltaTTable(entries: [Self.entry(2000, .nan), Self.entry(2001, 65)]) == nil)
		#expect(try DeltaTTable(entries: [Self.entry(2000, 64, uncertainty: .infinity), Self.entry(2001, 65)]) == nil)
		// Negative uncertainty
		#expect(try DeltaTTable(entries: [Self.entry(2000, 64, uncertainty: -1), Self.entry(2001, 65)]) == nil)

		#expect(try DeltaTTable(entries: [Self.entry(2000, 64), Self.entry(2001, 65)]) != nil)
	}

	@Test func interpolatesLinearly() throws {
		let table = try #require(DeltaTTable(entries: [
			Self.entry(2000, 64, uncertainty: 1),
			Self.entry(2001, 65, uncertainty: 3),
			Self.entry(2003, 61),
		]))
		#expect(try table.coverage == JulianDate(decimalYear: 2000) ... JulianDate(decimalYear: 2003))

		let start = try #require(table.deltaTAndUncertainty(at: JulianDate(decimalYear: 2000)))
		#expect(start.seconds == 64 && start.uncertainty == 1)
		// 2000.25 is 91.5 of 2000's 366 days
		let quarter = try #require(table.deltaTAndUncertainty(at: JulianDate(decimalYear: 2000.25)))
		#expect(quarter.seconds == 64.25 && quarter.uncertainty == 1.5)
		let entry = try #require(table.deltaTAndUncertainty(at: JulianDate(decimalYear: 2001)))
		#expect(entry.seconds == 65 && entry.uncertainty == 3)

		// No uncertainty unless both neighbors have one; 2002 is 365 of the 730 days to 2003
		let later = try #require(table.deltaTAndUncertainty(at: JulianDate(decimalYear: 2002)))
		#expect(later.seconds == 63 && later.uncertainty == nil)
		let end = try #require(table.deltaTAndUncertainty(at: JulianDate(decimalYear: 2003)))
		#expect(end.seconds == 61 && end.uncertainty == nil)

		#expect(try table.deltaTAndUncertainty(at: JulianDate(decimalYear: 1999.999)) == nil)
		#expect(try table.deltaTAndUncertainty(at: JulianDate(decimalYear: 2003.001)) == nil)
	}

	@Test func historic() throws {
		let entries = DeltaTTable.historic.entries
		#expect(entries.count == 656)
		#expect(try DeltaTTable.historic.coverage == JulianDate(decimalYear: 1657) ... JulianDate(decimalYear: 1984.5))
		#expect(DeltaTTable(entries: entries) != nil)
		for (index, entry) in entries.enumerated() {
			// The generator's conversion agrees with JulianDate(decimalYear:)
			#expect(try entry.tt == JulianDate(decimalYear: 1657 + Double(index) / 2))
			#expect(entry.uncertainty != nil)
		}

		#expect(try entries.first == Self.entry(1657, 44, uncertainty: 12))
		#expect(try entries[1] == Self.entry(1657.5, 43, uncertainty: 15))
		#expect(try entries.last == Self.entry(1984.5, 54.087, uncertainty: 0.001))

		// 1657.5 is noon on July 2, 1657
		#expect(try entries[1].tt == JulianDate(julianDayNumber: GregorianCalendar.julianDayNumberFrom(year: 1657, month: 7, day: 2)))
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
	func joinedModelOutsideTable(decimalYear: Double) throws {
		let tt = try JulianDate(decimalYear: decimalYear)
		#expect(DeltaTTable.historic.deltaT(at: tt) == nil)
		#expect(try UT1.deltaT(at: tt, context: UT1.defaultContext) == historicJoinedModel(tt.decimalYear))
	}

	@Test func tableAgreesWithModelAtHandover() throws {
		// The model is fitted to Morrison & Stephenson (2004), not to this table, so the two
		// differ by 3.7 s at 1657 (within the table's 12 s uncertainty) and 0.04 s at 1984.5.
		for (decimalYear, tolerance) in [(1657.0, 4.0), (1984.5, 0.05)] {
			let table = try #require(DeltaTTable.historic.deltaT(at: JulianDate(decimalYear: decimalYear)))
			#expect(abs(table - DeltaTModel.espenakMeeus2006.deltaT(decimalYear: decimalYear)) < tolerance)
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
