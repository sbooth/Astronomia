//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// ΔT held at its value at one end of a source, up to a limit past that end.
///
/// The extrapolation covers only the dates from the end to the limit, so it is used after the
/// source in a ``DeltaTSourceList``:
///
/// ```swift
/// // The last observation, held for 30 days
/// let end = earthOrientation.coverage.upperBound
/// let limit = try end.adding(days: 30)
/// let held = try ConstantDeltaTExtrapolation(after: earthOrientation, through: limit)
/// let context = UT1.Context(deltaT: DeltaTSourceList([earthOrientation, held]))
/// ```
public struct ConstantDeltaTExtrapolation: DeltaTSource {
	/// ΔT, in seconds.
	public let seconds: Double
	/// The TT dates covered, from the limit to the end of the source or the reverse.
	public let coverage: ClosedRange<JulianDate>

	/// Creates an extrapolation before the start of a source.
	///
	/// - Parameters:
	///   - source: The source, which must give a finite ΔT at the start of its coverage.
	///   - limit: The earliest TT date to cover, at or before the start of `source`. Pass
	///     ``JulianDate/min`` for no limit.
	/// - Throws:
	///   - ``TimescaleConversionError/deltaTUnavailable`` if `source` gives no ΔT at its start.
	///   - ``TimescaleConversionError/nonFiniteValue`` if that ΔT is NaN or infinite.
	///   - ``TimescaleConversionError/invalidExtrapolationLimit`` if `limit` is after the start
	///     of `source`.
	public init(before source: some DeltaTSource, from limit: JulianDate) throws(TimescaleConversionError) {
		let start = try boundary(of: source, atStart: true)
		guard limit <= start.date else { throw .invalidExtrapolationLimit }
		seconds = start.deltaT
		coverage = limit ... start.date
	}

	/// Creates an extrapolation after the end of a source.
	///
	/// - Parameters:
	///   - source: The source, which must give a finite ΔT at the end of its coverage.
	///   - limit: The latest TT date to cover, at or after the end of `source`. Pass
	///     ``JulianDate/max`` for no limit.
	/// - Throws:
	///   - ``TimescaleConversionError/deltaTUnavailable`` if `source` gives no ΔT at its end.
	///   - ``TimescaleConversionError/nonFiniteValue`` if that ΔT is NaN or infinite.
	///   - ``TimescaleConversionError/invalidExtrapolationLimit`` if `limit` is before the end
	///     of `source`.
	public init(after source: some DeltaTSource, through limit: JulianDate) throws(TimescaleConversionError) {
		let end = try boundary(of: source, atStart: false)
		guard limit >= end.date else { throw .invalidExtrapolationLimit }
		seconds = end.deltaT
		coverage = end.date ... limit
	}

	public func deltaT(at tt: JulianDate) -> Double? {
		coverage.contains(tt) ? seconds : nil
	}
}

/// ΔT continued along its average rate near one end of a source, up to a limit past that end.
///
/// The extrapolation covers only the dates from the end to the limit, so it is used after the
/// source in a ``DeltaTSourceList``:
///
/// ```swift
/// // The observations, continued along their trend over the last year for two years
/// let end = earthOrientation.coverage.upperBound
/// let limit = try end.adding(days: 2 * 365.25)
/// let trend = try LinearDeltaTExtrapolation(after: earthOrientation, years: 1, through: limit)
/// let context = UT1.Context(deltaT: DeltaTSourceList([earthOrientation, trend]))
/// ```
public struct LinearDeltaTExtrapolation: DeltaTSource {
	/// The rate of change of ΔT, in seconds per Julian year.
	public let rate: Double
	/// The TT dates covered, from the limit to the end of the source or the reverse.
	public let coverage: ClosedRange<JulianDate>
	/// The end of the source.
	let end: JulianDate
	/// ΔT at the end of the source, in seconds.
	let endDeltaT: Double

	/// Creates an extrapolation before the start of a source.
	///
	/// - Parameters:
	///   - source: The source, which must give a finite ΔT throughout its coverage.
	///   - years: The number of Julian years after the start over which to average the rate,
	///     or the whole source if it is shorter. Finite and positive. A year or more averages
	///     out the seasonal variation in daily Earth orientation data.
	///   - limit: The earliest TT date to cover, at or before the start of `source`. Pass
	///     ``JulianDate/min`` for no limit.
	/// - Throws:
	///   - ``TimescaleConversionError/invalidExtrapolationSpan`` if `years` is not finite and
	///     positive.
	///   - ``TimescaleConversionError/deltaTUnavailable`` if `source` gives no ΔT at a date
	///     the rate needs.
	///   - ``TimescaleConversionError/nonFiniteValue`` if that ΔT is NaN or infinite.
	///   - ``TimescaleConversionError/dateOutOfRange`` if the span cannot be represented.
	///   - ``TimescaleConversionError/invalidExtrapolationLimit`` if `limit` is after the start
	///     of `source`.
	public init(before source: some DeltaTSource, years: Double = 1, from limit: JulianDate) throws(TimescaleConversionError) {
		try self.init(source, atStart: true, years: years, limit: limit)
	}

	/// Creates an extrapolation after the end of a source.
	///
	/// - Parameters:
	///   - source: The source, which must give a finite ΔT throughout its coverage.
	///   - years: The number of Julian years before the end over which to average the rate,
	///     or the whole source if it is shorter. Finite and positive. A year or more averages
	///     out the seasonal variation in daily Earth orientation data.
	///   - limit: The latest TT date to cover, at or after the end of `source`. Pass
	///     ``JulianDate/max`` for no limit.
	/// - Throws:
	///   - ``TimescaleConversionError/invalidExtrapolationSpan`` if `years` is not finite and
	///     positive.
	///   - ``TimescaleConversionError/deltaTUnavailable`` if `source` gives no ΔT at a date
	///     the rate needs.
	///   - ``TimescaleConversionError/nonFiniteValue`` if that ΔT is NaN or infinite.
	///   - ``TimescaleConversionError/dateOutOfRange`` if the span cannot be represented.
	///   - ``TimescaleConversionError/invalidExtrapolationLimit`` if `limit` is before the end
	///     of `source`.
	public init(after source: some DeltaTSource, years: Double = 1, through limit: JulianDate) throws(TimescaleConversionError) {
		try self.init(source, atStart: false, years: years, limit: limit)
	}

	/// Creates an extrapolation from the start or end of a source.
	init(_ source: some DeltaTSource, atStart: Bool, years: Double, limit: JulianDate) throws(TimescaleConversionError) {
		guard years.isFinite, years > 0 else { throw .invalidExtrapolationSpan }
		let extended = try boundary(of: source, atStart: atStart)
		guard atStart ? (limit <= extended.date) : (limit >= extended.date) else { throw .invalidExtrapolationLimit }
		let covered = source.coverage

		// The average rate from `years` inside the end, or from the far end if nearer. Capping
		// the span at the source's length keeps a long span from overflowing.
		let inward = julianYears(from: covered.lowerBound, to: covered.upperBound).map { Swift.min(years, $0) } ?? years
		let offset = (try? extended.date.adding(days: (atStart ? inward : -inward) * daysPerJulianYear))
			?? (atStart ? covered.upperBound : covered.lowerBound)
		let inside = offset.clamped(to: covered)

		if inside == extended.date {
			// A source covering a single date has no rate, so ΔT stays at its value.
			rate = 0
		} else {
			guard let insideDeltaT = source.deltaT(at: inside) else { throw .deltaTUnavailable }
			guard insideDeltaT.isFinite else { throw .nonFiniteValue }
			guard let baseline = julianYears(from: inside, to: extended.date) else { throw .dateOutOfRange }
			rate = (extended.deltaT - insideDeltaT) / baseline
		}
		end = extended.date
		endDeltaT = extended.deltaT
		coverage = atStart ? limit ... extended.date : extended.date ... limit
	}

	public func deltaT(at tt: JulianDate) -> Double? {
		guard coverage.contains(tt), let years = julianYears(from: end, to: tt) else { return nil }
		return endDeltaT + rate * years
	}
}

/// ΔT from another source, offset to join a source continuously at one end.
///
/// Past the end, ΔT changes as the other source's ΔT does, wherever the other source covers.
/// It is used after the source in a ``DeltaTSourceList``:
///
/// ```swift
/// // Observations, continued into the future along the model's trend
/// let model = DeltaTModel.espenakMeeus2006
/// let future = try JoinedDeltaTSource(model, after: earthOrientation)
/// let context = UT1.Context(deltaT: DeltaTSourceList([earthOrientation, future, model]))
/// ```
///
/// The joined values are not published values: before 1657.0, for example, the default model
/// joined to ``DeltaTTable/builtIn`` is the model's value plus about 6.5 s.
public struct JoinedDeltaTSource: DeltaTSource {
	/// The source whose changes ΔT follows.
	public let other: any DeltaTSource
	/// The offset added to the other source's ΔT, in seconds.
	public let offset: Double
	/// The TT dates covered, from the end of the source to the end of the other source.
	public let coverage: ClosedRange<JulianDate>
	/// The end of the source where the two are joined.
	let joinDate: JulianDate
	/// ΔT of the source at the join, in seconds.
	let joinDeltaT: Double

	/// Creates a source following `other` before the start of `source`.
	///
	/// - Parameters:
	///   - other: The source to follow, which must cover the start of `source`.
	///   - source: The source to join.
	/// - Throws:
	///   - ``TimescaleConversionError/deltaTUnavailable`` if either source gives no ΔT at the
	///     start of `source`.
	///   - ``TimescaleConversionError/nonFiniteValue`` if either ΔT there is NaN or infinite.
	public init(_ other: some DeltaTSource, before source: some DeltaTSource) throws(TimescaleConversionError) {
		try self.init(other, source, atStart: true)
	}

	/// Creates a source following `other` after the end of `source`.
	///
	/// - Parameters:
	///   - other: The source to follow, which must cover the end of `source`.
	///   - source: The source to join.
	/// - Throws:
	///   - ``TimescaleConversionError/deltaTUnavailable`` if either source gives no ΔT at the
	///     end of `source`.
	///   - ``TimescaleConversionError/nonFiniteValue`` if either ΔT there is NaN or infinite.
	public init(_ other: some DeltaTSource, after source: some DeltaTSource) throws(TimescaleConversionError) {
		try self.init(other, source, atStart: false)
	}

	/// Creates a source following `other` from the start or end of `source`.
	init(_ other: some DeltaTSource, _ source: some DeltaTSource, atStart: Bool) throws(TimescaleConversionError) {
		let date = atStart ? source.coverage.lowerBound : source.coverage.upperBound
		guard other.coverage.contains(date),
			  let sourceDeltaT = source.deltaT(at: date),
			  let otherDeltaT = other.deltaT(at: date)
		else { throw .deltaTUnavailable }
		guard sourceDeltaT.isFinite, otherDeltaT.isFinite else { throw .nonFiniteValue }

		self.other = other
		offset = sourceDeltaT - otherDeltaT
		coverage = atStart ? other.coverage.lowerBound ... date : date ... other.coverage.upperBound
		joinDate = date
		joinDeltaT = sourceDeltaT
	}

	public func deltaT(at tt: JulianDate) -> Double? {
		guard coverage.contains(tt) else { return nil }
		// The other source's ΔT plus the offset can round away from the source's at the join, so
		// the source's is returned there to meet it exactly.
		guard tt != joinDate else { return joinDeltaT }
		guard let otherDeltaT = other.deltaT(at: tt) else { return nil }
		return otherDeltaT + offset
	}
}

/// Returns the start or end of a source's coverage and ΔT there.
///
/// - Throws:
///   - ``TimescaleConversionError/deltaTUnavailable`` if `source` gives no ΔT there.
///   - ``TimescaleConversionError/nonFiniteValue`` if that ΔT is NaN or infinite.
private func boundary(of source: some DeltaTSource, atStart: Bool) throws(TimescaleConversionError) -> (date: JulianDate, deltaT: Double) {
	let date = atStart ? source.coverage.lowerBound : source.coverage.upperBound
	guard let deltaT = source.deltaT(at: date) else { throw .deltaTUnavailable }
	guard deltaT.isFinite else { throw .nonFiniteValue }
	return (date, deltaT)
}

/// Returns the number of Julian years from `start` to `end`, or `nil` if the interval cannot
/// be represented.
private func julianYears(from start: JulianDate, to end: JulianDate) -> Double? {
	guard let interval = try? start.interval(to: end) else { return nil }
	return interval.inDays / daysPerJulianYear
}
