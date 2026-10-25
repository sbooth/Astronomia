//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// A search of an interval for the instants when a quantity that rises and falls smoothly, as
/// the Moon's ecliptic latitude, crosses zero, upward and downward in turn.
///
/// The quantity is sampled a step apart, and two samples on either side of zero bracket a
/// crossing, which ``RootFinder`` finds to 0.1 s. The interval is closed: a crossing where the
/// quantity is zero at its start or end is found, rising or falling. After a crossing the
/// search skips ahead by the least time to the next. The quantity is evaluated only within the
/// interval, and the search assumes nothing of the span over which it can be: where it can't be
/// at the next sample, as past the end of an ephemeris's coverage, the step halves toward the
/// last sample, so a crossing before the end is still bracketed.
struct CrossingSearch<Failure: Error> {
	/// The quantity at a time.
	struct Sample {
		/// The time, in days after the start of the interval.
		let time: Double
		/// The quantity.
		let value: Double
	}

	/// A crossing found.
	struct Crossing {
		/// Whether the quantity crosses upward, from negative to nonnegative.
		let isRising: Bool
		/// The time, in days after the start of the interval.
		let time: Double
	}

	/// The precision of a crossing, 0.1 s, in days.
	static var tolerance: Double { 0.1 / secondsPerDay }
	/// The most evaluations to refine one crossing.
	static var maximumIterations: Int { 100 }

	/// The length of the interval, in days.
	let length: Double
	/// The time between samples, in days, less than the least time between crossings.
	let step: Double
	/// The time after a crossing within which the next can't be, less the step, in days.
	let skip: Double
	/// Returns the quantity at a time, in days after the start of the interval.
	let evaluate: (Double) throws(Failure) -> Double

	/// Returns the sample at a time.
	func sample(at time: Double) throws(Failure) -> Sample {
		Sample(time: time, value: try evaluate(time))
	}

	/// Returns the crossings in the interval, in order.
	///
	/// - Parameters:
	///   - rising: Whether to find only upward crossings, only downward ones, or with `nil`
	///     both. The others are bracketed, to step past them, but not refined or returned.
	///   - stoppingAfterFirst: Whether to stop at the first crossing found, without evaluating
	///     the quantity for the rest of the interval.
	func crossings(only rising: Bool? = nil, stoppingAfterFirst: Bool = false) throws(Failure) -> [Crossing] {
		var crossings: [Crossing] = []
		var previous = try sample(at: 0)
		// The earliest time the quantity couldn't be evaluated, as past the end of an
		// ephemeris's coverage, and the error
		var failed: (time: Double, error: Failure)? = nil
		while previous.time < length {
			var next = min(previous.time + step, length)
			// Halfway to a time that failed, so a crossing before it is bracketed, until there is
			// no time between them to tell
			if let failed, next >= failed.time {
				next = (previous.time + failed.time) / 2
				guard failed.time - previous.time > Self.tolerance, next > previous.time else {
					throw failed.error
				}
			}
			let current: Sample
			do throws(Failure) {
				current = try sample(at: next)
			} catch {
				failed = (next, error)
				continue
			}
			// A change of sign brackets a crossing, where zero counts as nonnegative, so a
			// rising crossing at the start, and a falling one at the end, are their own: the
			// quantity is zero there and on the same side as the sample next to it.
			let crosses = (previous.value < 0) != (current.value < 0)
			let risingAtStart = previous.time == 0 && previous.value == 0 && current.value > 0
			let fallingAtEnd = current.time == length && current.value == 0 && previous.value > 0
			guard crosses || risingAtStart || fallingAtEnd else {
				previous = current
				continue
			}
			// The crossing is after the previous sample, so the next is at least the skip and a
			// step after it.
			let isRising = current.value > previous.value
			var resume = previous.time + skip
			if rising == nil || rising == isRising {
				let found = try RootFinder.refine(previous, current, time: \.time, tolerance: Self.tolerance, maximumIterations: Self.maximumIterations, evaluate: sample, function: \.value)
				crossings.append(Crossing(isRising: isRising, time: found.time))
				if stoppingAfterFirst {
					break
				}
				resume = found.time + skip
			}
			guard resume < length else { break }
			previous = try sample(at: resume)
		}
		return crossings
	}
}
