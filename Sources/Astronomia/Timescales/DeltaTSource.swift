//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// A source of ΔT = TT - UT1 for a range of Julian Dates.
public protocol DeltaTSource: Sendable {
	/// The TT dates outside which the source supplies no ΔT.
	var coverage: ClosedRange<JulianDate> { get }

	/// Returns ΔT = TT - UT1, in seconds, at the specified TT.
	///
	/// - Parameter tt: A Julian Date in TT.
	/// - Returns: ΔT, in seconds, or `nil` if the source does not cover `tt`.
	func deltaT(at tt: JulianDate) -> Double?

	/// Returns ΔT = TT - UT1, in seconds, at the TT date whose UT1 is the specified date.
	///
	/// This solves TT = UT1 + ΔT(TT), so that UT1 + ΔT is the TT of `ut1`. The default
	/// implementation iterates within ``coverage``.
	///
	/// - Note: To find every TT in the coverage, ΔT must be available, continuous, and change
	///   more slowly than TT.
	/// - Parameter ut1: A Julian Date in UT1.
	/// - Returns: ΔT, in seconds, or `nil` if the source does not cover that TT.
	func deltaT(atUT1 ut1: JulianDate) -> Double?
}

extension DeltaTSource {
	/// Every representable Julian Date.
	public var coverage: ClosedRange<JulianDate> {
		.min ... .max
	}

	/// Returns ΔT at the TT date whose UT1 is the specified date.
	///
	/// - Parameter ut1: A Julian Date in UT1.
	/// - Returns: ΔT, in seconds, or `nil` if the TT of `ut1` is outside ``coverage``, or ΔT is
	///   unavailable at a date the iteration reaches.
	public func deltaT(atUT1 ut1: JulianDate) -> Double? {
		iteratedDeltaT(atUT1: ut1, within: coverage)
	}

	/// Returns ΔT at the TT date whose UT1 is `ut1`, for a source covering the TT dates in
	/// `range`, by fixed-point iteration kept within those dates.
	///
	/// The iteration evaluates TT = UT1 + ΔT(TT), starting from `ut1` and clamping each
	/// estimate to `range`, until an estimate repeats. Where ΔT changes more slowly than TT
	/// the solution is unique, and each step shrinks the error by a factor of dΔT/dt, at most
	/// about 2 × 10^-6 even for the model in antiquity, so an estimate repeats within a few
	/// steps. Clamping cannot move an estimate away from a solution within `range`, so the
	/// iteration never evaluates ΔT outside it.
	///
	/// A source whose ΔT changes nearly as fast as TT converges too slowly for that, so after
	/// eight steps the TT is bracketed and found by bisection instead.
	///
	/// The UT1 dates covered run from the UT1 of the first date in `range` to that of the
	/// last, computed as ``UT1/fromTT(_:context:)`` computes them, so the UT1 of either end is
	/// itself covered. An end at ``JulianDate/min`` or ``JulianDate/max`` is open: ΔT is not
	/// evaluated there, where a model's value can overflow.
	///
	/// - Parameters:
	///   - ut1: A Julian Date in UT1.
	///   - range: The TT dates covered.
	/// - Returns: ΔT, in seconds, or `nil` if `ut1` is outside the UT1 dates covered, ΔT is
	///   unavailable or non-finite at a bounded end of `range`, or ΔT is unavailable at a date
	///   the iteration reaches. A non-finite ΔT at a date the iteration reaches is returned for
	///   the caller to report. If the iteration does not converge, the result is that of
	///   bisection, which returns `nil` rather than an unconverged value.
	func iteratedDeltaT(atUT1 ut1: JulianDate, within range: ClosedRange<JulianDate>) -> Double? {
		// Rejects a UT1 date before the UT1 of the first date covered or after that of the last.
		for (end, isFirst) in [(range.lowerBound, true), (range.upperBound, false)] {
			guard end != .min, end != .max else { continue }
			// ΔT at an end only bounds the UT1 dates covered, so without a usable value there the
			// coverage on that side is unknown.
			guard let endDeltaT = deltaT(at: end), endDeltaT.isFinite,
				  let endUT1 = try? end.adding(seconds: -endDeltaT)
			else { return nil }
			if isFirst ? (ut1 < endUT1) : (ut1 > endUT1) { return nil }
		}

		var tt = ut1.clamped(to: range)
		for _ in 0 ..< 8 {
			guard let next = deltaT(at: tt) else { return nil }
			// A non-finite or unrepresentable step is left for the caller to report.
			guard next.isFinite, let estimate = try? ut1.adding(seconds: next) else { return next }
			let nextTT = estimate.clamped(to: range)
			if nextTT == tt { return next }
			tt = nextTT
		}
		return bisectedDeltaT(atUT1: ut1, within: range, from: tt)
	}

	/// Returns ΔT at the TT date whose UT1 is `ut1`, by bisection within `range`.
	///
	/// UT1 = TT - ΔT increases with TT wherever ΔT changes more slowly than TT, so a date whose
	/// UT1 is before `ut1` and one whose UT1 is after it bracket the TT. From `start`, the search
	/// steps toward the TT, doubling the step, until it passes the TT, then halves the bracket
	/// until its ends are neighboring dates, and takes the end whose UT1 is nearer `ut1`.
	///
	/// - Parameters:
	///   - ut1: A Julian Date in UT1.
	///   - range: The TT dates covered.
	///   - start: A TT date in `range` to search from.
	/// - Returns: ΔT, in seconds, or `nil` if ΔT is unavailable or non-finite at a date the
	///   search reaches, or the search reaches an end of `range` without passing the TT.
	private func bisectedDeltaT(atUT1 ut1: JulianDate, within range: ClosedRange<JulianDate>, from start: JulianDate) -> Double? {
		/// A TT date, the seconds from `ut1` to its UT1, and ΔT there.
		typealias Point = (date: JulianDate, seconds: Double, deltaT: Double)

		/// Returns `tt` as a point, or `nil` if ΔT there is unavailable or non-finite.
		func point(_ tt: JulianDate) -> Point? {
			guard let value = deltaT(at: tt), value.isFinite,
				  let pointUT1 = try? tt.adding(seconds: -value),
				  let interval = try? ut1.interval(to: pointUT1)
			else { return nil }
			return (tt, interval.inSeconds, value)
		}

		guard let first = point(start) else { return nil }
		guard first.seconds != 0 else { return first.deltaT }

		// The TT is after `start` if the UT1 of `start` is before `ut1`. `inner` stays on the
		// side of `start` and `outer`, once found, is on the other side or at the TT.
		let isForward = first.seconds < 0
		let end = isForward ? range.upperBound : range.lowerBound
		var inner = first
		var outer: Point?
		var step = first.seconds.magnitude
		for _ in 0 ..< 128 {
			let date = ((try? start.adding(seconds: isForward ? step : -step)) ?? end).clamped(to: range)
			guard let next = point(date) else { return nil }
			if next.seconds != 0, (next.seconds < 0) == isForward {
				guard date != end else { return nil }
				inner = next
				step *= 2
			} else {
				outer = next
				break
			}
		}
		guard var outer else { return nil }

		for _ in 0 ..< 256 {
			let (low, high) = isForward ? (inner.date, outer.date) : (outer.date, inner.date)
			guard let span = try? low.interval(to: high),
				  let mid = try? low.adding(days: span.inDays / 2),
				  low < mid, mid < high
			else { break }
			guard let next = point(mid) else { return nil }
			if next.seconds != 0, (next.seconds < 0) == isForward {
				inner = next
			} else {
				outer = next
			}
		}
		return inner.seconds.magnitude < outer.seconds.magnitude ? inner.deltaT : outer.deltaT
	}
}

/// A source of ΔT that tries a list of sources in order.
///
/// ΔT comes from the first source that covers the date. Sources can differ where one hands
/// over to the next, so ΔT need not be continuous there.
///
/// A list has the default ``coverage``, every date, since its sources can leave gaps and
/// overlap. It finds the TT of a UT1 date through its sources. An empty list covers no dates,
/// so conversions that need ΔT throw ``TimescaleConversionError/deltaTUnavailable``.
public struct DeltaTSourceList: DeltaTSource {
	/// The sources, in order of preference.
	public let sources: [any DeltaTSource]

	/// Creates a list of sources.
	///
	/// - Parameter sources: The sources, in order of preference.
	public init(_ sources: [any DeltaTSource]) {
		self.sources = sources
	}

	public func deltaT(at tt: JulianDate) -> Double? {
		for source in sources {
			if let deltaT = source.deltaT(at: tt) {
				return deltaT
			}
		}
		return nil
	}

	/// Returns ΔT at the TT date whose UT1 is the specified date, from the first source that
	/// covers that UT1 date.
	///
	/// Sources are tried by the UT1 date rather than the TT date. The two orders agree except
	/// within a step where one source hands over to the next, where a UT1 date has no TT or two.
	public func deltaT(atUT1 ut1: JulianDate) -> Double? {
		for source in sources {
			if let value = source.deltaT(atUT1: ut1) {
				return value
			}
		}
		return nil
	}
}

/// A source of ΔT given by a function.
///
/// ```swift
/// // ΔT fixed at 69.2 s, as stated for a published prediction
/// let context = UT1.Context(deltaT: DeltaTFunction.constant(69.2))
/// ```
public struct DeltaTFunction: DeltaTSource {
	/// The TT dates covered.
	public let coverage: ClosedRange<JulianDate>
	/// The function, returning ΔT in seconds at a TT, or `nil` where it does not apply.
	let function: @Sendable (JulianDate) -> Double?

	/// Creates a source from a function.
	///
	/// - Parameters:
	///   - coverage: The TT dates the function covers. Outside them the source gives no ΔT
	///     without calling the function. For converting UT1 to TT near where the function
	///     begins or ends, the function should give ΔT throughout.
	///   - function: A function returning ΔT, in seconds, at a Julian Date in TT, or `nil` for
	///     dates it does not cover.
	public init(coverage: ClosedRange<JulianDate> = .min ... .max, _ function: @escaping @Sendable (JulianDate) -> Double?) {
		self.coverage = coverage
		self.function = function
	}

	/// Returns a source with the same ΔT at every date.
	///
	/// - Parameter seconds: ΔT, in seconds.
	public static func constant(_ seconds: Double) -> DeltaTFunction {
		DeltaTFunction { _ in seconds }
	}

	public func deltaT(at tt: JulianDate) -> Double? {
		guard coverage.contains(tt) else { return nil }
		return function(tt)
	}
}
