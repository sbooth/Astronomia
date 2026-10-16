//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

/// Returns 0h on a Gregorian date, as a Julian Date.
private func midnight(_ year: Int, _ month: Int, _ day: Int) throws -> JulianDate {
	try JulianDate(julianDayNumber: GregorianCalendar.julianDayNumberFrom(year: year, month: month, day: day), fractionFromNoon: -0.5)
}

@Suite struct ModernDeltaTTests {
	@Test func entries() throws {
		let entries = DeltaTTable.modern.entries
		#expect(entries.count == 645)
		#expect(DeltaTTable(entries: entries) != nil)
		#expect(try entries.first == DeltaTTable.Entry(tt: midnight(1973, 2, 1), deltaT: 43.4724))
		#expect(try entries.last == DeltaTTable.Entry(tt: midnight(2026, 10, 1), deltaT: 69.2065))
		#expect(entries.allSatisfy { $0.uncertainty == nil && $0.tt.fractionFromNoon == -0.5 })
		#expect(try DeltaTTable.modern.coverage == midnight(1973, 2, 1) ... midnight(2026, 10, 1))
	}

	@Test func agreesWithHistoricTableWhereTheyOverlap() throws {
		// Both are observations from 1973 to 1984.5, so they agree to milliseconds.
		for year in stride(from: 1974.0, through: 1984.0, by: 1) {
			let tt = try JulianDate(decimalYear: year)
			let modern = try #require(DeltaTTable.modern.deltaT(at: tt))
			let historic = try #require(DeltaTTable.historic.deltaT(at: tt))
			#expect(abs(modern - historic) <= 0.01, "\(year)")
		}
	}

	@Test func defaultContinuesTrend() throws {
		let modern = DeltaTTable.modern
		let end = modern.coverage.upperBound
		let endDeltaT = try #require(modern.deltaT(at: end))
		let yearBefore = try end.adding(days: -JulianDate.daysPerJulianYear)
		let rate = try endDeltaT - #require(modern.deltaT(at: yearBefore))

		// A year after the table, ΔT continues the rate over its last year.
		let later = try end.adding(days: JulianDate.daysPerJulianYear)
		#expect(try abs(UT1.deltaT(at: later, context: UT1.defaultContext) - (endDeltaT + rate)) <= 1e-9)

		// Past the trend, ΔT is the model's.
		let pastTrend = try end.adding(days: (UT1.Context.defaultTrendYears + 0.1) * JulianDate.daysPerJulianYear)
		let model = DeltaTModel.espenakMeeus2006.deltaT(decimalYear: pastTrend.decimalYear)
		#expect(try UT1.deltaT(at: pastTrend, context: UT1.defaultContext) == model)

		// Without a trend, ΔT is the model's right after the table.
		let published = UT1.Context(trendYears: nil)
		let model2 = DeltaTModel.espenakMeeus2006.deltaT(decimalYear: later.decimalYear)
		#expect(try UT1.deltaT(at: later, context: published) == model2)
	}

	@Test func trendContinuesLaterSource() throws {
		// The Earth orientation data ends in 2017, before the modern table, so the modern
		// table's values are used after it, and only the modern table is continued.
		let table = try #require(EarthOrientationTable(finals2000A: finalsAroundLeapSecond))
		let context = UT1.Context(earthOrientation: table)
		let mid2017 = try midnight(2017, 6, 1)
		#expect(try UT1.deltaT(at: mid2017, context: context) == DeltaTTable.modern.deltaT(at: mid2017))

		let later = try DeltaTTable.modern.coverage.upperBound.adding(days: JulianDate.daysPerJulianYear)
		#expect(try UT1.deltaT(at: later, context: context) == UT1.deltaT(at: later, context: UT1.defaultContext))

		// Without the modern table, the Earth orientation data is continued instead.
		let observationsOnly = UT1.Context(earthOrientation: table, modernDeltaT: nil)
		let afterObservations = try table.coverage.upperBound.adding(days: 30)
		let endDeltaT = try #require(table.deltaT(at: table.coverage.upperBound))
		#expect(try abs(UT1.deltaT(at: afterObservations, context: observationsOnly) - endDeltaT) <= 0.1)
	}
}
