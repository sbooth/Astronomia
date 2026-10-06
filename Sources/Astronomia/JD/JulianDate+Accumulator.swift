//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

extension JulianDate {
	/// Start a sum that includes a caller-supplied split with ``init(days1:days2:)`` or
	/// ``init(seconds1:seconds2:)``, and add epochs, dates, and intervals afterwards:
	/// if the split's parts cancel, anything added before them is absorbed into the larger part
	/// and lost. Dates and intervals are canonical, so combining them is exact in any order
	/// whenever the result is small.
	/// - Note: Adding a non-finite value or overflowing `whole` leaves the accumulator non-finite.
	struct Accumulator {
		/// The integral number of whole days, or a non-finite value.
		fileprivate var whole: Double
		/// The fraction of a day, in the right-open interval [-0.5, 0.5), or a non-finite value.
		fileprivate var fraction: Double

		/// Creates a zero accumulator.
		init() {
			whole = 0
			fraction = 0
		}

		/// Adds `days`, keeping the parts canonical.
		///
		/// `days` is split exactly into its nearest integer and a remainder in the closed interval
		/// [-0.5, 0.5]. Integers accumulate in `whole` (exact while below 2^53 in magnitude;
		/// beyond that they round but stay integral) and remainders accumulate in `fraction`,
		/// so each call rounds at most once, by at most 2^-54, and only if both `fraction` and
		/// `days` have fractional parts. A non-finite `days`, or an overflowing `whole`, leaves
		/// the accumulator non-finite.
		mutating func add(days: Double) {
			let w = days.rounded()
			// (days - w) is exact and lies in [-0.5, 0.5]. The exact sum lies in [-1, 1) and rounds
			// into [-1, 1]. One rounding.
			let g = fraction + (days - w)
			var v = g.rounded()
			// Exact, [-0.5, 0.5].
			var f = g - v
			// Ties go up so the canonical form is unique. Only g == -0.5 lands here.
			if f == 0.5 {
				v += 1
				f = -0.5
			}
			fraction = f
			whole = (whole + w) + v
		}

		/// Adds `seconds`, assuming 86,400 seconds per day.
		mutating func add(seconds: Double) {
			// Exact, |r| <= 43,200. NaN for non-finite input, which propagates.
			let r = seconds.remainder(dividingBy: JulianDate.secondsPerDay)
			// While the day count is below 2^53, the rounded quotient is within one day of it,
			// so the residual seconds - 86,400 q is exact (below 2^17 in magnitude, and an integer
			// or a multiple of ulp(seconds)). It differs from r by exactly -86,400, 0, or 86,400,
			// which corrects q. Beyond 2^53 days the count rounds, with a relative error of
			// at most 2^-53.
			let q = (seconds / JulianDate.secondsPerDay).rounded()
			let residual = seconds.addingProduct(-q, secondsPerDay)
			add(days: q + ((residual - r) / JulianDate.secondsPerDay).rounded())
			add(days: r / JulianDate.secondsPerDay)
		}

		/// `true` if both parts are finite.
		var isFinite: Bool {
			whole.isFinite && fraction.isFinite
		}
	}
}

extension JulianDate.Accumulator {
	/// Creates an accumulator holding a caller-supplied split `days1 + days2`.
	init(days1: Double, days2: Double) {
		self.init()
		add(days: days1)
		add(days: days2)
	}

	/// Creates an accumulator holding a caller-supplied split `seconds1 + seconds2`, assuming 86,400
	/// seconds per day. See ``init(days1:days2:)``.
	init(seconds1: Double, seconds2: Double) {
		self.init()
		add(seconds: seconds1)
		add(seconds: seconds2)
	}
}

extension JulianDate.Accumulator {
	/// Adds a Julian Date, as days since JD 0.0.
	mutating func add(_ date: JulianDate) {
		add(days: date.day)
		add(days: date.fraction)
	}

	/// Adds an interval.
	mutating func add(_ interval: JulianDate.Interval) {
		add(days: interval.days)
		add(days: interval.fraction)
	}

	/// Subtracts a Julian Date, as days since JD 0.0, without forming its negation.
	mutating func subtract(_ date: JulianDate) {
		add(days: -date.day)
		add(days: -date.fraction)
	}

	/// Subtracts an interval without forming its negation.
	mutating func subtract(_ interval: JulianDate.Interval) {
		add(days: -interval.days) 
		add(days: -interval.fraction)
	}
}

extension JulianDate.Accumulator {
	/// Adds `x * y` days, as the rounded product plus its exact fused multiply-add residual.
	/// Rounds at most twice, by at most 2^-54 days each.
	mutating func add(productOf x: Double, _ y: Double) {
		let p = x * y
		add(days: p)
		add(days: (-p).addingProduct(x, y))
	}
}

extension JulianDate {
	/// Creates a Julian Date from an accumulated sum relative to JD 0.0, returning `nil`
	/// if it is not finite.
	init?(_ a: Accumulator) {
		guard a.isFinite else {
			return nil
		}
		day = a.whole
		fraction = a.fraction
	}
}

extension JulianDate.Interval {
	/// Creates an interval from an accumulated sum, returning `nil` if it is not finite.
	init?(_ a: JulianDate.Accumulator) {
		guard a.isFinite else {
			return nil
		}
		days = a.whole
		fraction = a.fraction
	}
}

extension JulianDate.Accumulator: CustomDebugStringConvertible {
	var debugDescription: String {
		"JulianDate.Accumulator(whole: \(whole), fraction: \(fraction))"
	}
}
