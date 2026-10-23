//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// A search of an interval for a target's risings, settings, and transits.
///
/// The target's place is sampled every hour, and at the ends of the interval. Its hour angle
/// increases by about 15° an hour, so a transit falls between two samples whose hour angles
/// straddle 0° or 180°. A rising or setting falls between two samples, or a sample and a
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

	/// Returns the events in the interval, in order.
	func events() throws(RiseTransitSetError) -> [RiseTransitSetEvent] {
		let count = max(1, Int((length / Self.step).rounded(.up)))
		var samples: [Sample] = []
		samples.reserveCapacity(count + 1)
		for index in 0 ... count {
			samples.append(try evaluate(min(Double(index) * Self.step, length)))
		}

		var events: [(kind: RiseTransitSetEvent.Kind, sample: Sample)] = []
		var points: [Sample] = []
		for (a, b) in zip(samples, samples.dropFirst()) {
			points.append(a)
			// The hour angle increases by under 180° between samples, so the step is its change
			// reduced to (-π, π].
			let change = Self.reduced(b.hourAngle - a.hourAngle)
			for (kind, target) in [(RiseTransitSetEvent.Kind.upperTransit, 0.0), (.lowerTransit, Double.pi)] {
				// The target hour angle on the unwrapped scale from a's hour angle
				guard a.hourAngle < target, target <= a.hourAngle + change else { continue }
				let transit = try refine(a, b) { sample in
					a.hourAngle + Self.reduced(sample.hourAngle - a.hourAngle) - target
				}
				events.append((kind, transit))
				points.append(transit)
			}
		}
		if let last = samples.last {
			points.append(last)
		}
		points.sort { $0.time < $1.time }

		for (a, b) in zip(points, points.dropFirst()) where (a.height < 0) != (b.height < 0) {
			let crossing = try refine(a, b) { $0.height }
			events.append((b.height >= 0 ? .rising : .setting, crossing))
		}

		return events
			.sorted { $0.sample.time < $1.sample.time }
			.map { RiseTransitSetEvent(kind: $0.kind, instant: $0.sample.instant, place: $0.sample.place) }
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
