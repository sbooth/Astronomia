//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

/// ΔT from the default model, offset to join the historic table at its nearer end, as in the
/// continuous UT1 context outside the table.
func historicJoinedModel(_ decimalYear: Double) -> Double {
	let model = DeltaTModel.stephensonMorrisonHohenkerk2016
	let historic = DeltaTTable.historic
	let end = decimalYear < 1657 ? historic.coverage.lowerBound : historic.coverage.upperBound
	let endDeltaT = decimalYear < 1657 ? historic.entries[0].deltaT : historic.entries[historic.entries.count - 1].deltaT
	return model.deltaT(decimalYear: decimalYear) + (endDeltaT - model.deltaT(decimalYear: end.decimalYear))
}

@Suite struct DeltaTExtrapolationTests {
	typealias Entry = DeltaTTable.Entry

	/// ΔT rising 2 s per year at the start and 1 s per year at the end.
	static func table() throws -> DeltaTTable {
		try #require(DeltaTTable(entries: [
			Entry(decimalYear: 2000, deltaT: 60),
			Entry(decimalYear: 2001, deltaT: 62),
			Entry(decimalYear: 2002, deltaT: 63),
		]))
	}

	/// Returns ΔT from `source` at a decimal year, and the Julian Date of that decimal year.
	static func deltaT(_ source: some DeltaTSource, _ decimalYear: Double) throws -> (deltaT: Double?, tt: JulianDate) {
		let tt = try JulianDate(decimalYear: decimalYear)
		return (source.deltaT(atTT: tt), tt)
	}

	@Test func coverage() throws {
		let table = try Self.table()
		#expect(try table.coverage == JulianDate(decimalYear: 2000) ... JulianDate(decimalYear: 2002))
		#expect(table.deltaT(atTT: table.coverage.lowerBound) == 60)
		#expect(table.deltaT(atTT: table.coverage.upperBound) == 63)

		let historic = DeltaTTable.historic
		#expect(try historic.coverage == JulianDate(decimalYear: 1657) ... JulianDate(decimalYear: 1984.5))
		#expect(historic.deltaT(atTT: historic.coverage.lowerBound) == 44)
		#expect(historic.deltaT(atTT: historic.coverage.upperBound) == 54.087)

		let table2 = try #require(EarthOrientationTable(finals2000A: finalsAroundLeapSecond))
		#expect(table2.deltaT(atTT: table2.coverage.lowerBound) != nil)
		#expect(table2.deltaT(atTT: table2.coverage.upperBound) != nil)
	}

	/// Returns the Julian Date of a decimal year.
	static func year(_ decimalYear: Double) throws -> JulianDate {
		try JulianDate(decimalYear: decimalYear)
	}

	@Test func coversOnlyPastTheEnd() throws {
		let table = try Self.table()
		let before = try ConstantDeltaTExtrapolation(before: table, from: Self.year(1999))
		let after = try ConstantDeltaTExtrapolation(after: table, through: Self.year(2003))
		#expect(try before.coverage == Self.year(1999) ... Self.year(2000))
		#expect(try after.coverage == Self.year(2002) ... Self.year(2003))
		// Within the table, neither extrapolation gives ΔT
		#expect(try Self.deltaT(before, 2001).deltaT == nil)
		#expect(try Self.deltaT(after, 2001).deltaT == nil)
		#expect(try Self.deltaT(before, 2003).deltaT == nil)
		#expect(try Self.deltaT(after, 1999.5).deltaT == nil)
	}

	@Test func constant() throws {
		let table = try Self.table()
		let before = try ConstantDeltaTExtrapolation(before: table, from: Self.year(1980))
		let after = try ConstantDeltaTExtrapolation(after: table, through: Self.year(2020))
		#expect(before.seconds == 60)
		#expect(after.seconds == 63)
		#expect(try Self.deltaT(before, 1990).deltaT == 60)
		#expect(try Self.deltaT(after, 2010).deltaT == 63)
	}

	@Test func linear() throws {
		// The rate over a Julian year at each end of the table. A year after 2000-01-01 is
		// 2000-12-31T06:00, where ΔT is 60 + 2 × 365.25 / 366 s, and a year before 2002-01-01
		// is 2000-12-31T18:00, where ΔT is 60 + 2 × 365.75 / 366 s.
		let table = try Self.table()
		let before = try LinearDeltaTExtrapolation(before: table, from: Self.year(1990))
		let after = try LinearDeltaTExtrapolation(after: table, through: Self.year(2010))
		// 1998-01-01 is 730 days before 2000-01-01
		let (earlier, _) = try Self.deltaT(before, 1998)
		#expect(try abs(#require(earlier) - 56.01092896174863) <= 1e-9)
		// 2005-01-01 is 1096 days after 2002-01-01
		let (later, _) = try Self.deltaT(after, 2005)
		#expect(try abs(#require(later) - 66.00478375841085) <= 1e-9)
	}

	@Test func linearOverShortSource() throws {
		// Ten years is longer than the table, so the rate is over the whole table: 3 s in 731 days
		let table = try Self.table()
		let before = try LinearDeltaTExtrapolation(before: table, years: 10, from: Self.year(1990))
		let after = try LinearDeltaTExtrapolation(after: table, years: 10, through: Self.year(2010))
		#expect(abs(before.rate - after.rate) <= 1e-12)
		let (earlier, _) = try Self.deltaT(before, 1998)
		#expect(try abs(#require(earlier) - 57.00410396716826) <= 1e-9)
		let (later, _) = try Self.deltaT(after, 2005)
		#expect(try abs(#require(later) - 67.49794801641586) <= 1e-9)
	}

	@Test func linearOverVeryLongSpan() throws {
		// A span far longer than any date range uses the whole table, as a span of 10 years does.
		let table = try Self.table()
		let long = try LinearDeltaTExtrapolation(after: table, years: 1e300, through: Self.year(2010))
		let ten = try LinearDeltaTExtrapolation(after: table, years: 10, through: Self.year(2010))
		#expect(long.rate == ten.rate)
	}

	@Test func linearOverSourceWithoutStart() throws {
		// A source with no start is longer than any span, so the rate is over the year before
		// its end.
		let end = try Self.year(2002)
		let function = DeltaTFunction(coverage: .min ... end) { tt in
			// 2 s per Julian year
			(try? JulianDate.j2000.interval(to: tt)).map { 64 + 2 * $0.inDays / daysPerJulianYear }
		}
		let trend = try LinearDeltaTExtrapolation(after: function, through: Self.year(2003))
		#expect(abs(trend.rate - 2) <= 1e-9)
	}

	@Test func joinedModel() throws {
		let table = try Self.table()
		let model = DeltaTModel.espenakMeeus2006
		let after = try JoinedDeltaTSource(model, after: table)
		let before = try JoinedDeltaTSource(model, before: table)
		#expect(after.coverage.upperBound == .max)
		#expect(before.coverage.lowerBound == .min)
		let (later, laterTT) = try Self.deltaT(after, 2010)
		#expect(try abs(#require(later) - (63 + (model.deltaT(decimalYear: laterTT.decimalYear) - model.deltaT(decimalYear: 2002)))) <= 1e-9)
		let (earlier, earlierTT) = try Self.deltaT(before, 1990)
		#expect(try abs(#require(earlier) - (60 + (model.deltaT(decimalYear: earlierTT.decimalYear) - model.deltaT(decimalYear: 2000)))) <= 1e-9)
		// The join gives no ΔT within the table
		#expect(try Self.deltaT(after, 2001).deltaT == nil)
	}

	@Test func joinedTable() throws {
		// Another table, rising 1 s per year from 1990 to 2010
		let other = try #require(DeltaTTable(entries: [
			Entry(decimalYear: 1990, deltaT: 0),
			Entry(decimalYear: 2010, deltaT: 20),
		]))
		let table = try Self.table()
		let after = try JoinedDeltaTSource(other, after: table)
		let before = try JoinedDeltaTSource(other, before: table)
		let end = try JulianDate(decimalYear: 2002)
		let (later, laterTT) = try Self.deltaT(after, 2005)
		let expected = try #require(other.deltaT(atTT: laterTT)) - #require(other.deltaT(atTT: end)) + 63
		#expect(try abs(#require(later) - expected) <= 1e-9)
		#expect(try abs(#require(later) - 66) <= 0.01)

		// Outside the other table there is no ΔT
		#expect(try Self.deltaT(after, 2011).deltaT == nil)
		#expect(try Self.deltaT(before, 1989).deltaT == nil)
	}

	@Test func joinedFunction() throws {
		// Joining a constant holds the end value
		let table = try Self.table()
		let constant = try JoinedDeltaTSource(DeltaTFunction.constant(100), after: table)
		#expect(constant.offset == -37)
		#expect(try Self.deltaT(constant, 2010).deltaT == 63)

		// A source that does not cover the end cannot be joined
		#expect(throws: TimescaleConversionError.deltaTUnavailable) {
			try JoinedDeltaTSource(DeltaTFunction { _ in nil }, after: table)
		}
		let ending = try DeltaTFunction(coverage: .min ... JulianDate(decimalYear: 2001)) { _ in 100 }
		#expect(throws: TimescaleConversionError.deltaTUnavailable) {
			try JoinedDeltaTSource(ending, after: table)
		}
	}

	@Test func invalidArguments() throws {
		let table = try Self.table()
		// A limit within the table, on the wrong side of the end it extends
		let within = try Self.year(2001)
		#expect(throws: TimescaleConversionError.invalidExtrapolationLimit) {
			try ConstantDeltaTExtrapolation(before: table, from: within)
		}
		#expect(throws: TimescaleConversionError.invalidExtrapolationLimit) {
			try ConstantDeltaTExtrapolation(after: table, through: within)
		}
		#expect(throws: TimescaleConversionError.invalidExtrapolationLimit) {
			try LinearDeltaTExtrapolation(before: table, from: within)
		}
		#expect(throws: TimescaleConversionError.invalidExtrapolationLimit) {
			try LinearDeltaTExtrapolation(after: table, through: within)
		}
		for years in [0, -1, Double.infinity, Double.nan] {
			#expect(throws: TimescaleConversionError.invalidExtrapolationSpan, "\(years)") {
				try LinearDeltaTExtrapolation(before: table, years: years, from: .min)
			}
			#expect(throws: TimescaleConversionError.invalidExtrapolationSpan, "\(years)") {
				try LinearDeltaTExtrapolation(after: table, years: years, through: .max)
			}
		}
		// The end of the source must have a finite ΔT
		let empty = DeltaTFunction { _ in nil }
		#expect(throws: TimescaleConversionError.deltaTUnavailable) { try ConstantDeltaTExtrapolation(after: empty, through: .max) }
		#expect(throws: TimescaleConversionError.nonFiniteValue) {
			try ConstantDeltaTExtrapolation(after: DeltaTFunction.constant(.nan), through: .max)
		}
	}

	@Test func limitAtTheEnd() throws {
		// A limit at the end covers the end and no further.
		let table = try Self.table()
		let end = table.coverage.upperBound
		let source = try ConstantDeltaTExtrapolation(after: table, through: end)
		#expect(source.coverage == end ... end)
		#expect(source.deltaT(atTT: end) == 63)
		#expect(try source.deltaT(atTT: end.adding(seconds: 1)) == nil)
	}

	@Test func limit() throws {
		let table = try Self.table()
		let after = try ConstantDeltaTExtrapolation(after: table, through: Self.year(2003))
		let before = try ConstantDeltaTExtrapolation(before: table, from: Self.year(1999))
		#expect(try Self.deltaT(after, 2002.5).deltaT == 63)
		#expect(try Self.deltaT(after, 2003.5).deltaT == nil)
		#expect(try Self.deltaT(before, 1999.5).deltaT == 60)
		#expect(try Self.deltaT(before, 1998.5).deltaT == nil)
	}

	@Test func noLimit() throws {
		// The earliest and latest dates leave the coverage unbounded on that side.
		let table = try Self.table()
		let after = try ConstantDeltaTExtrapolation(after: table, through: .max)
		let before = try ConstantDeltaTExtrapolation(before: table, from: .min)
		#expect(after.coverage.upperBound == .max)
		#expect(before.coverage.lowerBound == .min)
		#expect(try Self.deltaT(after, 3000).deltaT == 63)
		#expect(try Self.deltaT(before, 1000).deltaT == 60)
	}

	@Test func handoverAtHistoricTable() throws {
		// A thousandth of a year either side of 1657.0 changes ΔT by milliseconds in the
		// continuous context, but by the 6.5 s between the model and the table in the default
		// context.
		let inside = try JulianDate(decimalYear: 1657.001)
		let outside = try JulianDate(decimalYear: 1656.999)
		let continuous = UT1.Context.continuous()
		#expect(try abs(UT1.deltaT(atTT: inside, context: continuous) - UT1.deltaT(atTT: outside, context: continuous)) <= 0.01)
		#expect(try abs(UT1.deltaT(atTT: inside, context: UT1.defaultContext) - UT1.deltaT(atTT: outside, context: UT1.defaultContext)) >= 3.6)
	}

	@Test func observationsJoinModelBeforeTheirStart() throws {
		// Without a ΔT table, dates before the first observation follow the model offset to
		// meet it, rather than the model itself.
		let table = try #require(EarthOrientationTable(finals2000A: finalsAroundLeapSecond))
		let model = DeltaTModel.espenakMeeus2006
		let context = UT1.Context.continuous(earthOrientation: table, deltaTTable: nil, model: model)
		let start = table.coverage.lowerBound
		let startDeltaT = try #require(table.deltaT(atTT: start))
		// The model is about 1.4 s from the first observation, so following it unadjusted
		// would jump there.
		#expect(abs(model.deltaT(decimalYear: start.decimalYear) - startDeltaT) > 1)

		let before = try start.adding(seconds: -1)
		#expect(try abs(UT1.deltaT(atTT: before, context: context) - startDeltaT) <= 1e-6)
		#expect(try UT1.deltaT(atTT: start, context: context) == startDeltaT)

		// UT1 advances by a second across the first observation, as TT does
		let ut1Before = try UT1.fromTT(before, context: context)
		let ut1Start = try UT1.fromTT(start, context: context)
		#expect(try abs(seconds(from: ut1Before, to: ut1Start) - 1) <= 1e-6)
	}

	@Test func observationsContinueAlongModel() throws {
		let table = try #require(EarthOrientationTable(finals2000A: finalsAroundLeapSecond))
		let end = table.coverage.upperBound
		let endDeltaT = try #require(table.deltaT(atTT: end))
		// Without the ΔT table, which covers these dates
		let context = UT1.Context.continuous(earthOrientation: table, deltaTTable: nil, model: .espenakMeeus2006)

		// A day after the last observation, ΔT is close to it, not the model's value
		let nextDay = try table.coverage.upperBound.adding(days: 1)
		let joined = try UT1.deltaT(atTT: nextDay, context: context)
		#expect(abs(joined - endDeltaT) <= 0.01)
		#expect(abs(joined - DeltaTModel.espenakMeeus2006.deltaT(decimalYear: nextDay.decimalYear)) > 1)

		// Later, ΔT follows the model's change since the last observation
		let later = try table.coverage.upperBound.adding(days: 365)
		let model = DeltaTModel.espenakMeeus2006
		let expected = endDeltaT + (model.deltaT(decimalYear: later.decimalYear) - model.deltaT(decimalYear: end.decimalYear))
		#expect(try abs(UT1.deltaT(atTT: later, context: context) - expected) <= 1e-9)
	}
}
