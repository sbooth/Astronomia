//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// ΔT at one end of a bounded source's coverage.
public struct DeltaTEndpoint: Hashable, Sendable {
	/// The end, as a Julian Date in TT.
	public let tt: JulianDate
	/// ΔT at the end, in seconds.
	public let deltaT: Double
	/// The rate of change of ΔT at the end, in seconds per Julian year of 365.25 days.
	public let rate: Double

	/// Creates an endpoint.
	///
	/// - Parameters:
	///   - tt: The end, as a Julian Date in TT.
	///   - deltaT: ΔT at the end, in seconds.
	///   - rate: The rate of change of ΔT at the end, in seconds per Julian year.
	public init(tt: JulianDate, deltaT: Double, rate: Double) {
		self.tt = tt
		self.deltaT = deltaT
		self.rate = rate
	}
}

/// Returns the Julian years of 365.25 days from `start` to `end`.
///
/// Converting each Julian day number to `Double` cannot overflow, and is exact for any date
/// a table could cover.
func julianYears(from start: JulianDate, to end: JulianDate) -> Double {
	let days = (Double(end.julianDayNumber) - Double(start.julianDayNumber)) + (end.fractionFromNoon - start.fractionFromNoon)
	return days / JulianDate.daysPerJulianYear
}

/// A source of ΔT that covers a single span of dates.
public protocol BoundedDeltaTSource: DeltaTSource {
	/// ΔT at the start of the span.
	var lowerEnd: DeltaTEndpoint { get }
	/// ΔT at the end of the span.
	var upperEnd: DeltaTEndpoint { get }
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
		/// ΔT continues at its rate at the end.
		case linear
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

		let end: DeltaTEndpoint
		let method: Method?
		if tt <= source.lowerEnd.tt {
			end = source.lowerEnd
			method = before
		} else if tt >= source.upperEnd.tt {
			end = source.upperEnd
			method = after
		} else {
			return nil
		}
		guard let method else { return nil }
		let years = julianYears(from: end.tt, to: tt)
		if let limit, abs(years) > limit { return nil }

		switch method {
		case .constant:
			return end.deltaT
		case .linear:
			return end.deltaT + end.rate * years
		case .model(let model):
			// Models are defined on decimal years
			return model.deltaT(decimalYear: tt.decimalYear) + (end.deltaT - model.deltaT(decimalYear: end.tt.decimalYear))
		}
	}
}

extension DeltaTTable: BoundedDeltaTSource {}

extension EarthOrientationTable: BoundedDeltaTSource {
	public var lowerEnd: DeltaTEndpoint {
		// Initialization requires at least two entries.
		Self.endpoint(samples[0], samples[1], at: samples[0])
	}

	public var upperEnd: DeltaTEndpoint {
		let count = samples.count
		return Self.endpoint(samples[count - 2], samples[count - 1], at: samples[count - 1])
	}

	/// Returns the endpoint at `end`, with the rate from `a` to `b`.
	private static func endpoint(_ a: Sample, _ b: Sample, at end: Sample) -> DeltaTEndpoint {
		DeltaTEndpoint(tt: end.tt, deltaT: end.deltaT, rate: (b.deltaT - a.deltaT) / julianYears(from: a.tt, to: b.tt))
	}
}
