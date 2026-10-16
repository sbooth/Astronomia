//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

/// ΔT from Espenak & Meeus (2006), offset to join the historic table at its nearer end, as in
/// the default UT1 context outside the table.
func historicJoinedModel(_ decimalYear: Double) -> Double {
	let model = DeltaTModel.espenakMeeus2006
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
		return (source.deltaT(at: tt), tt)
	}

	@Test func coverage() throws {
		let table = try Self.table()
		#expect(try table.coverage == JulianDate(decimalYear: 2000) ... JulianDate(decimalYear: 2002))
		#expect(table.deltaT(at: table.coverage.lowerBound) == 60)
		#expect(table.deltaT(at: table.coverage.upperBound) == 63)

		let historic = DeltaTTable.historic
		#expect(try historic.coverage == JulianDate(decimalYear: 1657) ... JulianDate(decimalYear: 1984.5))
		#expect(historic.deltaT(at: historic.coverage.lowerBound) == 44)
		#expect(historic.deltaT(at: historic.coverage.upperBound) == 54.087)

		let table2 = try #require(EarthOrientationTable(finals2000A: finalsAroundLeapSecond))
		#expect(table2.coverage == table2.range)
	}

	@Test func withinSpanUsesSource() throws {
		let source = DeltaTExtrapolation(try Self.table(), before: .constant, after: .constant)
		let (value, _) = try Self.deltaT(source, 2001)
		#expect(try abs(#require(value) - 62) <= 1e-6)
	}

	@Test func notExtendedByDefault() throws {
		let source = DeltaTExtrapolation(try Self.table())
		#expect(try Self.deltaT(source, 1999).deltaT == nil)
		#expect(try Self.deltaT(source, 2003).deltaT == nil)

		let beforeOnly = DeltaTExtrapolation(try Self.table(), before: .constant)
		#expect(try Self.deltaT(beforeOnly, 1999).deltaT == 60)
		#expect(try Self.deltaT(beforeOnly, 2003).deltaT == nil)
	}

	@Test func constant() throws {
		let source = DeltaTExtrapolation(try Self.table(), before: .constant, after: .constant)
		#expect(try Self.deltaT(source, 1990).deltaT == 60)
		#expect(try Self.deltaT(source, 2010).deltaT == 63)
	}

	@Test func linear() throws {
		// The rate over a Julian year at each end of the table. A year after 2000-01-01 is
		// 2000-12-31T06:00, where ΔT is 60 + 2 × 365.25 / 366 s, and a year before 2002-01-01
		// is 2000-12-31T18:00, where ΔT is 60 + 2 × 365.75 / 366 s.
		let source = DeltaTExtrapolation(try Self.table(), before: .linear(), after: .linear())
		// 1998-01-01 is 730 days before 2000-01-01
		let (before, _) = try Self.deltaT(source, 1998)
		#expect(try abs(#require(before) - 56.01092896174863) <= 1e-9)
		// 2005-01-01 is 1096 days after 2002-01-01
		let (after, _) = try Self.deltaT(source, 2005)
		#expect(try abs(#require(after) - 66.00478375841085) <= 1e-9)
	}

	@Test func linearOverShortSource() throws {
		// Ten years is longer than the table, so the rate is over the whole table: 3 s in 731 days
		let source = DeltaTExtrapolation(try Self.table(), before: .linear(years: 10), after: .linear(years: 10))
		let (before, _) = try Self.deltaT(source, 1998)
		#expect(try abs(#require(before) - 57.00410396716826) <= 1e-9)
		let (after, _) = try Self.deltaT(source, 2005)
		#expect(try abs(#require(after) - 67.49794801641586) <= 1e-9)
	}

	@Test func model() throws {
		let model = DeltaTModel.espenakMeeus2006
		let source = DeltaTExtrapolation(try Self.table(), before: .following(model), after: .following(model))
		let (after, afterTT) = try Self.deltaT(source, 2010)
		#expect(try abs(#require(after) - (63 + (model.deltaT(decimalYear: afterTT.decimalYear) - model.deltaT(decimalYear: 2002)))) <= 1e-9)
		let (before, beforeTT) = try Self.deltaT(source, 1990)
		#expect(try abs(#require(before) - (60 + (model.deltaT(decimalYear: beforeTT.decimalYear) - model.deltaT(decimalYear: 2000)))) <= 1e-9)
	}

	@Test func followingAnotherTable() throws {
		// Another table, rising 1 s per year from 1990 to 2010
		let other = try #require(DeltaTTable(entries: [
			Entry(decimalYear: 1990, deltaT: 0),
			Entry(decimalYear: 2010, deltaT: 20),
		]))
		let source = DeltaTExtrapolation(try Self.table(), before: .following(other), after: .following(other))
		let end = try JulianDate(decimalYear: 2002)
		let (after, afterTT) = try Self.deltaT(source, 2005)
		let expected = try #require(other.deltaT(at: afterTT)) - #require(other.deltaT(at: end)) + 63
		#expect(try abs(#require(after) - expected) <= 1e-9)
		#expect(try abs(#require(after) - 66) <= 0.01)

		// Outside the other table there is no ΔT
		#expect(try Self.deltaT(source, 2011).deltaT == nil)
		#expect(try Self.deltaT(source, 1989).deltaT == nil)
	}

	@Test func followingFunction() throws {
		// Following a constant holds the end value
		let constant = DeltaTExtrapolation(try Self.table(), after: .following(DeltaTFunction.constant(100)))
		#expect(try Self.deltaT(constant, 2010).deltaT == 63)

		// A source that covers nothing gives no ΔT
		let empty = DeltaTExtrapolation(try Self.table(), after: .following(DeltaTFunction { _ in nil }))
		#expect(try Self.deltaT(empty, 2010).deltaT == nil)
	}

	@Test func limit() throws {
		let source = DeltaTExtrapolation(try Self.table(), before: .constant, after: .constant, limit: 1)
		#expect(try Self.deltaT(source, 2002.5).deltaT == 63)
		#expect(try Self.deltaT(source, 2003.5).deltaT == nil)
		#expect(try Self.deltaT(source, 1999.5).deltaT == 60)
		#expect(try Self.deltaT(source, 1998.5).deltaT == nil)
	}

	@Test(arguments: [(1657.0, 3.6), (1984.5, 0.03)])
	func handoverAtHistoricTable(decimalYear: Double, step: Double) throws {
		// A thousandth of a year either side of the end changes ΔT by milliseconds in the
		// continuous context, but by the 3.7 s or 0.04 s between the model and the table in the
		// default context.
		let inside = try JulianDate(decimalYear: decimalYear + (decimalYear < 1700 ? 0.001 : -0.001))
		let outside = try JulianDate(decimalYear: decimalYear + (decimalYear < 1700 ? -0.001 : 0.001))
		let continuous = UT1.Context.continuous()
		#expect(try abs(UT1.deltaT(at: inside, context: continuous) - UT1.deltaT(at: outside, context: continuous)) <= 0.01)
		#expect(try abs(UT1.deltaT(at: inside, context: UT1.defaultContext) - UT1.deltaT(at: outside, context: UT1.defaultContext)) >= step)
	}

	@Test func observationsContinueAlongModel() throws {
		let table = try #require(EarthOrientationTable(finals2000A: finalsAroundLeapSecond))
		let end = table.coverage.upperBound
		let endDeltaT = try #require(table.deltaT(at: end))
		let context = UT1.Context.continuous(earthOrientation: table)

		// A day after the last observation, ΔT is close to it, not the model's value
		let nextDay = try table.range.upperBound.adding(days: 1)
		let joined = try UT1.deltaT(at: nextDay, context: context)
		#expect(abs(joined - endDeltaT) <= 0.01)
		#expect(abs(joined - DeltaTModel.espenakMeeus2006.deltaT(decimalYear: nextDay.decimalYear)) > 1)

		// Later, ΔT follows the model's change since the last observation
		let later = try table.range.upperBound.adding(days: 365)
		let model = DeltaTModel.espenakMeeus2006
		let expected = endDeltaT + (model.deltaT(decimalYear: later.decimalYear) - model.deltaT(decimalYear: end.decimalYear))
		#expect(try abs(UT1.deltaT(at: later, context: context) - expected) <= 1e-9)
	}
}
