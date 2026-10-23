//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// A search of an interval for the instants when an angle that increases steadily, as the Sun's
/// longitude or the Moon's elongation from the Sun, reaches a multiple of 90°.
///
/// From each sample the next multiple is predicted from the angle's mean motion and bracketed by
/// a margin either side, which the angle's true motion keeps it within, and the instant it is
/// reached is found to 0.1 s by ``RootFinder``. The search then continues a day later. It
/// assumes nothing of the span over which the angle can be evaluated: where it can't be at the
/// end of a bracket, as past the end of an ephemeris's coverage, the bracket closes nearer the
/// event.
struct QuarterSearch<Failure: Error> {
	/// The angle at a time.
	struct Sample {
		/// The time, in days after the start of the interval.
		let time: Double
		/// The instant of the time.
		let instant: Instant<TT>
		/// The angle, in radians in the right-open interval [0, 2π).
		let angle: Double
	}

	/// The precision of an event, 0.1 s, in days.
	static var tolerance: Double { 0.1 / secondsPerDay }
	/// The most evaluations to refine one event.
	static var maximumIterations: Int { 100 }

	/// The length of the interval, in days.
	let length: Double
	/// The angle's mean motion, in radians per day.
	let meanMotion: Double
	/// The half-width of the bracket around a predicted event, in days.
	let margin: Double
	/// Returns the angle at a time, in days after the start of the interval.
	let evaluate: (Double) throws(Failure) -> Sample

	/// Returns the multiples of 90° reached in the interval, in order: the quarter, from 0 for
	/// 0° to 3 for 270°, and the instant.
	///
	/// - Parameter last: The only quarter to find, after which to stop, without evaluating the
	///   angle for the rest of the interval, or `nil` for every quarter. Other quarters are
	///   bracketed, to step past them, but not refined or returned.
	func events(stoppingAt last: Int? = nil) throws(Failure) -> [(quarter: Int, instant: Instant<TT>)] {
		var events: [(quarter: Int, instant: Instant<TT>)] = []
		var current = try evaluate(0)
		while current.time < length {
			// The next multiple of 90° after the current angle, and when the angle reaches it
			let index = Int((current.angle / halfPi).rounded(.down)) + 1
			let target = Double(index) * halfPi
			let predicted = current.time + (target - current.angle) / meanMotion
			/// How far past the target the angle is, negative before it.
			let past = { (sample: Sample) in Self.reduced(sample.angle - target) }

			// The bracket is the margin either side of the prediction, within the interval and
			// after the current time, which is before the event.
			var lower = current
			var upper: Sample? = nil
			if predicted - margin > current.time, predicted - margin < length {
				let sample = try evaluate(predicted - margin)
				if past(sample) < 0 {
					lower = sample
				} else {
					upper = sample
				}
			}
			if upper == nil {
				let sample = try sampleAfter(lower, past: past, at: min(predicted + margin, length))
				guard past(sample) >= 0 else {
					// The event is after the end of the interval, or past the bracket, which the
					// angle's motion doesn't allow but a custom ephemeris might.
					if sample.time >= length { break }
					current = sample
					continue
				}
				upper = sample
			}
			guard let upper else { break }
			if let last, index % 4 != last {
				// Step past another quarter without refining it.
				current = upper
				continue
			}
			let event = try RootFinder.refine(lower, upper, time: \.time, tolerance: Self.tolerance, maximumIterations: Self.maximumIterations, evaluate: evaluate, function: past)
			events.append((index % 4, event.instant))
			if last != nil {
				break
			}
			// The next event is days later.
			let next = event.time + 1
			guard next < length else { break }
			current = try evaluate(next)
		}
		return events
	}

	/// Returns the sample closing a bracket after a sample before the target, or the sample at
	/// the time if the angle is before the target there.
	///
	/// Where the angle can't be evaluated at the time, as past the end of an ephemeris's
	/// coverage, the time moves back halfway to the latest time that is before the target,
	/// until the angle can be evaluated past the target, so that an event near the end of the
	/// coverage is bracketed without assuming where the coverage ends.
	///
	/// - Parameters:
	///   - lower: A sample before the target.
	///   - past: How far past the target the angle of a sample is, negative before it.
	///   - time: The time to close the bracket.
	/// - Returns: A sample past the target, or one at `time` before it.
	/// - Throws: The failure to evaluate the angle when the times that fail come within the
	///   tolerance of a time that is before the target.
	func sampleAfter(_ lower: Sample, past: (Sample) -> Double, at time: Double) throws(Failure) -> Sample {
		var lower = lower
		var time = time
		var failedTime: Double? = nil
		while true {
			do throws(Failure) {
				let sample = try evaluate(time)
				guard let failedTime, past(sample) < 0 else {
					return sample
				}
				// The target is between this sample and a time that failed.
				lower = sample
				time = (lower.time + failedTime) / 2
			} catch {
				guard time - lower.time > Self.tolerance else {
					throw error
				}
				failedTime = time
				time = (lower.time + time) / 2
			}
		}
	}

	/// Returns an angle reduced to the left-open interval (-π, π].
	static func reduced(_ angle: Double) -> Double {
		let r = angle.remainder(dividingBy: twoPi)
		return r == -.pi ? .pi : r
	}
}

/// An interval of TT, with the instants of times within it.
struct SearchInterval {
	/// An error converting or checking an interval.
	enum Failure: Error {
		/// The interval ends before it starts.
		case invalidInterval
		/// The interval can't be converted to TT.
		case timescaleConversion(TimescaleConversionError)
	}

	/// The start of the interval.
	let start: Instant<TT>
	/// The end of the interval.
	let end: Instant<TT>
	/// The length of the interval, in days.
	let length: Double

	/// Creates an interval from instants in a timescale.
	///
	/// - Throws: A ``Failure`` if the instants can't be converted to TT, or the interval ends
	///   before it starts.
	init<Scale: Timescale>(from start: Instant<Scale>, to end: Instant<Scale>, context: Scale.Context) throws(Failure) {
		do throws(TimescaleConversionError) {
			self.start = try start.converted(to: TT.self, sourceContext: context)
			self.end = try end.converted(to: TT.self, sourceContext: context)
		} catch {
			throw .timescaleConversion(error)
		}
		guard self.start <= self.end else {
			throw .invalidInterval
		}
		length = self.end.julianDate.daysSinceJ2000 - self.start.julianDate.daysSinceJ2000
	}

	/// Returns the instant some days after the start, at most the end.
	///
	/// - Throws: ``Failure/invalidInterval`` if the instant can't be represented, which a time
	///   between two representable instants never is.
	func instant(_ days: Double) throws(Failure) -> Instant<TT> {
		if days >= length {
			return end
		}
		do throws(JulianDateError) {
			return Instant(try start.julianDate.adding(days: days))
		} catch {
			throw .invalidInterval
		}
	}
}
