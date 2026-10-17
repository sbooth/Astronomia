//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// A source of ΔT that covers a single span of dates.
public protocol BoundedDeltaTSource: DeltaTSource {
	/// The TT dates the source covers.
	///
	/// The source returns ΔT for every date in the range, including its ends.
	var coverage: ClosedRange<JulianDate> { get }
}

/// A source of ΔT that extends a bounded source past the dates it covers.
///
/// Within the source's span ΔT comes from the source. Before or after it, ΔT comes from the
/// method for that side, if any, up to `limit` Julian years from the end of the span.
///
/// ```swift
/// // Observations, continued into the future along the model's trend
/// let model = DeltaTModel.espenakMeeus2006
/// let future = try DeltaTExtrapolation(earthOrientation, after: .following(model))
/// ```
public struct DeltaTExtrapolation: DeltaTSource {
	/// How ΔT continues past an end of the source's span.
	public enum Method: Sendable {
		/// ΔT stays at its value at the end.
		case constant
		/// ΔT continues at its average rate over the last `years` Julian years of the source,
		/// or over the whole source if it is shorter. `years` must be finite and positive.
		///
		/// A year or more averages out the seasonal variation in daily Earth orientation data.
		case linear(years: Double = 1)
		/// ΔT follows another source, offset to equal the bounded source at the end, so ΔT is
		/// continuous.
		///
		/// The other source must cover both the end and the date; otherwise there is no ΔT.
		case following(any DeltaTSource)
	}

	/// The bounded source.
	public let source: any BoundedDeltaTSource
	/// How ΔT continues before the source's span, or `nil` to not extend it.
	public let before: Method?
	/// How ΔT continues after the source's span, or `nil` to not extend it.
	public let after: Method?
	/// The number of Julian years past an end to extend the source, or `nil` for no limit.
	public let limit: Double?

	/// Creates a source that extends `source` past the dates it covers.
	///
	/// - Parameters:
	///   - source: The bounded source.
	///   - before: How ΔT continues before the source's span, or `nil` to not extend it.
	///   - after: How ΔT continues after the source's span, or `nil` to not extend it.
	///   - limit: The number of Julian years past an end to extend the source, or `nil` for no
	///     limit.
	/// - Throws:
	///   - ``TimescaleConversionError/invalidExtrapolationLimit`` if `limit` is not finite and
	///     nonnegative.
	///   - ``TimescaleConversionError/invalidExtrapolationSpan`` if the span of a
	///     ``Method/linear(years:)`` method is not finite and positive.
	public init(_ source: some BoundedDeltaTSource, before: Method? = nil, after: Method? = nil, limit: Double? = nil) throws(TimescaleConversionError) {
		if let limit {
			guard limit.isFinite, limit >= 0 else { throw .invalidExtrapolationLimit }
		}
		for case .linear(let years)? in [before, after] {
			guard years.isFinite, years > 0 else { throw .invalidExtrapolationSpan }
		}
		self.init(uncheckedSource: source, before: before, after: after, limit: limit)
	}

	/// Creates a source from arguments already known to be valid.
	///
	/// - Precondition: `limit` and any linear span satisfy the requirements of
	///   ``init(_:before:after:limit:)``.
	init(uncheckedSource source: some BoundedDeltaTSource, before: Method?, after: Method?, limit: Double?) {
		self.source = source
		self.before = before
		self.after = after
		self.limit = limit
	}

	public func deltaT(at tt: JulianDate) -> Double? {
		if let deltaT = source.deltaT(at: tt) {
			return deltaT
		}

		let coverage = source.coverage
		let end: JulianDate
		let method: Method?
		if tt <= coverage.lowerBound {
			end = coverage.lowerBound
			method = before
		} else if tt >= coverage.upperBound {
			end = coverage.upperBound
			method = after
		} else {
			return nil
		}

		guard let method,
			  let endDeltaT = source.deltaT(at: end),
			  // An interval too long to represent is beyond any extrapolation
			  let years = julianYears(from: end, to: tt)
		else { return nil }
		if let limit, abs(years) > limit { return nil }

		switch method {
		case .constant:
			return endDeltaT
		case .linear(let span):
			// The average rate from `span` years inside the end, or from the far end if nearer.
			// Capping the span at the source's length keeps a long span from overflowing.
			guard let length = julianYears(from: coverage.lowerBound, to: coverage.upperBound) else { return nil }
			let inward = min(span, length)
			guard let offset = try? end.adding(days: (end == coverage.lowerBound ? inward : -inward) * JulianDate.daysPerJulianYear)
			else { return nil }
			let inside = min(max(offset, coverage.lowerBound), coverage.upperBound)
			// A source covering a single date has no rate, so ΔT stays at its value.
			guard inside != end else { return endDeltaT }
			guard let insideDeltaT = source.deltaT(at: inside),
				  let baseline = julianYears(from: inside, to: end)
			else { return nil }
			return endDeltaT + (endDeltaT - insideDeltaT) / baseline * years
		case .following(let other):
			guard let otherAtEnd = other.deltaT(at: end), let otherDeltaT = other.deltaT(at: tt) else { return nil }
			return otherDeltaT + (endDeltaT - otherAtEnd)
		}
	}
}

/// Returns the number of Julian years from `start` to `end`, or `nil` if the interval cannot
/// be represented.
private func julianYears(from start: JulianDate, to end: JulianDate) -> Double? {
	guard let interval = try? start.interval(to: end) else { return nil }
	return interval.inDays / JulianDate.daysPerJulianYear
}

extension DeltaTTable: BoundedDeltaTSource {}
