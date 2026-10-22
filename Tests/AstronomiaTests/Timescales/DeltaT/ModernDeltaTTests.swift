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
	try JulianDate(julianDayNumber: GregorianCalendar.julianDayNumber(year: year, month: month, day: day), fractionFromNoon: -0.5)
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

	@Test func builtIn() throws {
		// 633 half-yearly historic entries from 1657.0 to 1973.0, then the 645 modern entries
		let builtIn = DeltaTTable.builtIn
		let historic = DeltaTTable.historic.entries
		let modern = DeltaTTable.modern.entries
		#expect(builtIn.entries.count == 1278)
		#expect(DeltaTTable(entries: builtIn.entries) != nil)
		#expect(Array(builtIn.entries.prefix(633)) == Array(historic.prefix(633)))
		#expect(Array(builtIn.entries.suffix(645)) == modern)
		#expect(try builtIn.entries[632].tt == JulianDate(decimalYear: 1973))
		#expect(builtIn.coverage.lowerBound == DeltaTTable.historic.coverage.lowerBound)
		#expect(builtIn.coverage.upperBound == DeltaTTable.modern.coverage.upperBound)

		// Uncertainties before 1973, none after; the interval across the seam has none.
		let before = try #require(builtIn.deltaTAndUncertainty(at: JulianDate(decimalYear: 1900.25)))
		#expect(before.uncertainty != nil)
		let seam = try #require(builtIn.deltaTAndUncertainty(at: midnight(1973, 1, 15)))
		#expect(seam.uncertainty == nil)
		#expect(seam.seconds > 43.373 && seam.seconds < 43.4724)
	}

	@Test func agreesWithHistoricTableWhereTheyOverlap() throws {
		// Both are observations from 1973 to 1984.5, so they agree to milliseconds.
		for year in stride(from: 1974.0, through: 1984.0, by: 1) {
			let tt = try JulianDate(decimalYear: year)
			let modern = try #require(DeltaTTable.modern.deltaT(atTT: tt))
			let historic = try #require(DeltaTTable.historic.deltaT(atTT: tt))
			#expect(abs(modern - historic) <= 0.01, "\(year)")
		}
	}

	@Test func defaultContinuesTrend() throws {
		let modern = DeltaTTable.modern
		let end = modern.coverage.upperBound
		let endDeltaT = try #require(modern.deltaT(atTT: end))
		let yearBefore = try end.adding(days: -daysPerJulianYear)
		let rate = try endDeltaT - #require(modern.deltaT(atTT: yearBefore))

		// A year after the table, ΔT continues the rate over its last year.
		let later = try end.adding(days: daysPerJulianYear)
		#expect(try abs(UT1.deltaT(at: later, context: UT1.defaultContext) - (endDeltaT + rate)) <= 1e-9)

		// Past the trend, ΔT is the model's.
		let pastTrend = try end.adding(days: (UT1.Context.defaultTrendYears + 0.1) * daysPerJulianYear)
		let model = DeltaTModel.stephensonMorrisonHohenkerk2016.deltaT(decimalYear: pastTrend.decimalYear)
		#expect(try UT1.deltaT(at: pastTrend, context: UT1.defaultContext) == model)

		// Without a trend, ΔT is the model's right after the table.
		let published = try UT1.Context(trendYears: nil)
		let model2 = DeltaTModel.stephensonMorrisonHohenkerk2016.deltaT(decimalYear: later.decimalYear)
		#expect(try UT1.deltaT(at: later, context: published) == model2)
	}

	@Test func trendYears() throws {
		// The default trend, a chosen trend, and none
		let end = DeltaTTable.modern.coverage.upperBound
		let afterTrend = try end.adding(days: 1.5 * daysPerJulianYear)
		let short = try UT1.Context(trendYears: 1)
		let model = DeltaTModel.stephensonMorrisonHohenkerk2016.deltaT(decimalYear: afterTrend.decimalYear)
		#expect(try UT1.deltaT(at: afterTrend, context: short) == model)
		#expect(try UT1.deltaT(at: afterTrend, context: UT1.Context()) != model)

		for years in [-1, Double.infinity, Double.nan] {
			#expect(throws: TimescaleConversionError.invalidExtrapolationLimit, "\(years)") {
				try UT1.Context(trendYears: years)
			}
		}
	}

	@Test func trendContinuesLaterSource() throws {
		// The Earth orientation data ends in 2017, before the built-in table, so the table's
		// values are used after it, and only the table is continued.
		let table = try #require(EarthOrientationTable(finals2000A: finalsAroundLeapSecond))
		let context = UT1.Context(earthOrientationTable: table)
		let mid2017 = try midnight(2017, 6, 1)
		#expect(try UT1.deltaT(at: mid2017, context: context) == DeltaTTable.modern.deltaT(atTT: mid2017))

		let later = try DeltaTTable.modern.coverage.upperBound.adding(days: daysPerJulianYear)
		#expect(try UT1.deltaT(at: later, context: context) == UT1.deltaT(at: later, context: UT1.defaultContext))

		// Without the ΔT table, the Earth orientation data is continued instead.
		let observationsOnly = UT1.Context(earthOrientationTable: table, deltaTTable: nil)
		let afterObservations = try table.coverage.upperBound.adding(days: 30)
		let endDeltaT = try #require(table.deltaT(atTT: table.coverage.upperBound))
		#expect(try abs(UT1.deltaT(at: afterObservations, context: observationsOnly) - endDeltaT) <= 0.1)
	}
}
