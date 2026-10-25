//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// A search of an interval for a target's rises, sets, and transits.
///
/// The target's place is sampled every hour, in order, and at the ends of the interval. Its
/// hour angle increases by about 15° an hour, so a transit falls between two samples whose hour
/// angles straddle 0° or 180°. A rise or set falls between two samples, or a sample and a
/// transit, on either side of the event altitude. Each is then found to 0.1 s by the Illinois
/// variant of the method of false position, safeguarded by bisection.
///
/// A target that rises and sets again within an hour, grazing the event altitude near its
/// transit, can be missed when both crossings fall between two samples; this happens only for
/// a target that barely clears the horizon, as near the poles.
struct RiseTransitSetSearch {
	/// A place of the target at a time.
	struct Sample {
		/// The time, in days after the start of the interval.
		let time: Double
		/// The instant of the time.
		let instant: Instant<TT>
		/// The hour angle, in radians in the left-open interval (-π, π].
		let hourAngle: Double
		/// The altitude of the target above the event altitude, in radians.
		let height: Double
		/// The place.
		let place: ObservedPlace
	}

	/// The interval between samples, an hour, in days.
	static let step = 1.0 / 24
	/// The precision of an event, 0.1 s, in days.
	static let tolerance = 0.1 / secondsPerDay
	/// The most evaluations to refine one event.
	static let maximumIterations = 100

	/// The length of the interval, in days.
	let length: Double
	/// Returns the target's place at a time, in days after the start of the interval.
	let evaluate: (Double) throws(RiseTransitSetError) -> Sample

	/// Returns the events in the interval, in order, or the first that a predicate accepts.
	///
	/// The samples are taken in order, and the events between each two are found once both
	/// are, so a search for the first event evaluates the place no further than the hour after
	/// it. Where the place can't be evaluated at the next sample, as past the end of an
	/// ephemeris's coverage, the step halves toward the last sample, so an event before the end
	/// is still bracketed.
	///
	/// - Parameter accept: Whether an event ends the search, or `nil` to find every event.
	/// - Returns: The events, or the first accepted, in order of their instants.
	/// - Throws: The failure to evaluate the place, where the times that fail come within the
	///   tolerance of one that doesn't.
	func events(stoppingAt accept: ((RiseTransitSetEvent) -> Bool)? = nil) throws(RiseTransitSetError) -> [RiseTransitSetEvent] {
		var events: [RiseTransitSetEvent] = []
		var a = try evaluate(0)
		// The earliest time the place couldn't be evaluated, as past the end of an ephemeris's
		// coverage, and the error
		var failed: (time: Double, error: RiseTransitSetError)? = nil
		while a.time < length {
			var time = min(a.time + Self.step, length)
			// Halfway to a time that failed, so an event before it is bracketed, until there is
			// no time between them to tell
			if let failed, time >= failed.time {
				time = (a.time + failed.time) / 2
				guard failed.time - a.time > Self.tolerance, time > a.time else {
					throw failed.error
				}
			}
			let b: Sample
			do throws(RiseTransitSetError) {
				b = try evaluate(time)
			} catch {
				failed = (time, error)
				continue
			}

			// The hour angle increases by under 180° between samples, so the step is its change
			// reduced to (-π, π].
			var found: [(kind: RiseTransitSetEvent.Kind, sample: Sample)] = []
			var points = [a]
			let change = Self.reduced(b.hourAngle - a.hourAngle)
			for (kind, target) in [(RiseTransitSetEvent.Kind.upperTransit, 0.0), (.lowerTransit, Double.pi)] {
				// The target hour angle on the unwrapped scale from a's hour angle
				guard a.hourAngle < target, target <= a.hourAngle + change else { continue }
				let transit = try refine(a, b) { sample in
					a.hourAngle + Self.reduced(sample.hourAngle - a.hourAngle) - target
				}
				found.append((kind, transit))
				points.append(transit)
			}
			points.append(b)
			points.sort { $0.time < $1.time }
			// A rise or set falls between two of the samples and the transits between them.
			for (p, q) in zip(points, points.dropFirst()) where (p.height < 0) != (q.height < 0) {
				let crossing = try refine(p, q) { $0.height }
				found.append((q.height >= 0 ? .rise : .set, crossing))
			}

			for (kind, sample) in found.sorted(by: { $0.sample.time < $1.sample.time }) {
				let event = RiseTransitSetEvent(kind: kind, instant: sample.instant, place: sample.place)
				guard let accept else {
					events.append(event)
					continue
				}
				if accept(event) {
					return [event]
				}
			}
			a = b
		}
		return events
	}

	/// Returns an angle reduced to the left-open interval (-π, π].
	static func reduced(_ angle: Double) -> Double {
		let r = angle.remainder(dividingBy: twoPi)
		return r == -.pi ? .pi : r
	}

	/// Finds where a function of the place changes sign between two samples, to the tolerance,
	/// as ``RootFinder/refine(_:_:time:tolerance:maximumIterations:evaluate:function:)`` does.
	///
	/// - Parameters:
	///   - a: The earlier sample.
	///   - b: The later sample, on the other side of the root.
	///   - function: The function, negative on one side and nonnegative on the other.
	/// - Returns: The sample within the tolerance of the root.
	func refine(_ a: Sample, _ b: Sample, function: (Sample) -> Double) throws(RiseTransitSetError) -> Sample {
		try RootFinder.refine(a, b, time: \.time, tolerance: Self.tolerance, maximumIterations: Self.maximumIterations, evaluate: evaluate, function: function)
	}
}
