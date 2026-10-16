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
/// let future = DeltaTExtrapolation(earthOrientation, after: .model(.espenakMeeus2006))
/// ```
public struct DeltaTExtrapolation: DeltaTSource {
	/// How ΔT continues past an end of the source's span.
	public enum Method: Hashable, Sendable {
		/// ΔT stays at its value at the end.
		case constant
		/// ΔT continues at its average rate over the last `years` Julian years of the source,
		/// or over the whole source if it is shorter.
		///
		/// A year or more averages out the seasonal variation in daily Earth orientation data.
		case linear(years: Double = 1)
		/// ΔT follows `model`, offset to equal the source at the end, so ΔT is continuous.
		case model(DeltaTModel)
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
	public init(_ source: some BoundedDeltaTSource, before: Method? = nil, after: Method? = nil, limit: Double? = nil) {
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
			// The average rate from `span` years inside the end, or the far end if nearer
			let inward = end == coverage.lowerBound ? span : -span
			guard let offset = try? end.adding(days: inward * JulianDate.daysPerJulianYear) else { return nil }
			let inside = min(max(offset, coverage.lowerBound), coverage.upperBound)
			guard inside != end,
				  let insideDeltaT = source.deltaT(at: inside),
				  let baseline = julianYears(from: inside, to: end)
			else { return endDeltaT }
			return endDeltaT + (endDeltaT - insideDeltaT) / baseline * years
		case .model(let model):
			// Models are defined on decimal years
			return model.deltaT(decimalYear: tt.decimalYear) + (endDeltaT - model.deltaT(decimalYear: end.decimalYear))
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

extension EarthOrientationTable: BoundedDeltaTSource {
	/// The TT dates covered by the table, the same as ``range``.
	public var coverage: ClosedRange<JulianDate> {
		range
	}
}
