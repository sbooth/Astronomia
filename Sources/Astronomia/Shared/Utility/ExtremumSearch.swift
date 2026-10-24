//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// A search of an interval for the extremes of a quantity that rises and falls smoothly, as the
/// Moon's declination or distance, whose maxima and minima alternate.
///
/// An extreme is where the quantity's slope changes sign. The slope at a time is the rise of the
/// quantity over the next 10 seconds, which is sampled a step apart; a rise and then a fall
/// bracket a maximum, and a fall and then a rise a minimum, whose instant ``RootFinder`` finds
/// to 0.1 s as the midpoint of the 10 seconds over which the rise is zero. Near an extreme a
/// quantity barely changes, so comparing its values there can't place the extreme to 0.1 s, as
/// their differences are lost in their rounding errors; the rise, which changes sign at the
/// extreme, can. The Moon's declination, for example, has rounding errors of a few 1e-13
/// radians, from the arguments of its series, of up to 1e5 radians; near an extreme its rise
/// over 10 seconds changes by about 3e-11 radians a second. After an extreme the search skips
/// ahead by the least time to the next.
///
/// The quantity is evaluated only within the interval, so an extreme within 5 seconds of either
/// end isn't found. The search assumes nothing of the span over which the quantity can
/// be evaluated: where it can't be at the next sample, as past the end of an ephemeris's
/// coverage, the step halves toward the last sample, so an extreme before the end is still
/// bracketed.
struct ExtremumSearch<Failure: Error> {
	/// The rise of the quantity over the interval of a rise.
	struct Rise {
		/// The time, in days after the start of the interval, at the start of the rise.
		let time: Double
		/// The quantity at the start of the rise.
		let first: Double
		/// The quantity at the end of the rise.
		let second: Double

		/// The rise, negative for a fall.
		var rise: Double {
			second - first
		}
	}

	/// An extreme found.
	struct Extreme {
		/// Whether it is a maximum, rather than a minimum.
		let isMaximum: Bool
		/// The time, in days after the start of the interval.
		let time: Double
		/// The quantity at the extreme.
		let value: Double
	}

	/// The precision of an extreme, 0.1 s, in days.
	static var tolerance: Double { 0.1 / secondsPerDay }
	/// The most rises to evaluate to refine one extreme.
	static var maximumIterations: Int { 100 }
	/// The interval over which a rise is evaluated, 10 s, in days.
	static var interval: Double { 10 / secondsPerDay }

	/// The length of the interval, in days.
	let length: Double
	/// The time between samples, in days, less than the least time between extremes.
	let step: Double
	/// The time after an extreme within which the next can't be, less the step, in days.
	let skip: Double
	/// Returns the quantity at a time, in days after the start of the interval.
	let evaluate: (Double) throws(Failure) -> Double

	/// Returns the rise of the quantity from a time.
	func rise(at time: Double) throws(Failure) -> Rise {
		Rise(time: time, first: try evaluate(time), second: try evaluate(time + Self.interval))
	}

	/// Returns the extremes in the interval, in order.
	///
	/// - Parameters:
	///   - maxima: Whether to find only maxima, only minima, or with `nil` both. The others are
	///     bracketed, to step past them, but not refined or returned.
	///   - stoppingAfterFirst: Whether to stop at the first extreme found, without evaluating
	///     the quantity for the rest of the interval.
	func extremes(only maxima: Bool? = nil, stoppingAfterFirst: Bool = false) throws(Failure) -> [Extreme] {
		// The last time a rise can start
		let last = length - Self.interval
		guard last > 0 else { return [] }
		var extremes: [Extreme] = []
		var previous = try rise(at: 0)
		// The earliest time a rise couldn't be evaluated, as past the end of an ephemeris's
		// coverage
		var failedTime: Double? = nil
		while previous.time < last {
			var next = min(previous.time + step, last)
			// Halfway to a time that failed, so an extreme before it is bracketed
			if let failedTime, next >= failedTime {
				next = (previous.time + failedTime) / 2
			}
			let current: Rise
			do throws(Failure) {
				current = try rise(at: next)
			} catch {
				guard next - previous.time > Self.tolerance else {
					throw error
				}
				failedTime = next
				continue
			}
			guard (previous.rise > 0) != (current.rise > 0) else {
				previous = current
				continue
			}
			// The extreme is after the previous sample, so the next is at least the skip and a
			// step after it.
			let isMaximum = previous.rise > 0
			var resume = previous.time + skip
			if maxima == nil || maxima == isMaximum {
				let found = try RootFinder.refine(previous, current, time: \.time, tolerance: Self.tolerance, maximumIterations: Self.maximumIterations, evaluate: rise, function: \.rise)
				let time = found.time + Self.interval / 2
				let extreme = Extreme(isMaximum: isMaximum, time: time, value: try evaluate(time))
				extremes.append(extreme)
				if stoppingAfterFirst {
					break
				}
				resume = extreme.time + skip
			}
			guard resume < last else { break }
			previous = try rise(at: resume)
		}
		return extremes
	}
}
