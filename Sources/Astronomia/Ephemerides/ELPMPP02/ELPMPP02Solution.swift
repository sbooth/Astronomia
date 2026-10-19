//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

extension ELPMPP02 {
	/// The solution as an ephemeris of the Moon relative to the Earth, in the ecliptic of its fit,
	/// for J1000.0 to J3000.0.
	///
	/// States are geocentric unless the origin is the Moon. For the Moon with the planets, use
	/// ``SolarSystemEphemeris``.
	///
	/// ```swift
	/// let moon = try ELPMPP02.Solution().state(of: .moon, at: instant)
	/// let laserRanging = ELPMPP02.Solution(fit: ELPMPP02.LaserRanging.self)
	/// ```
	public struct Solution<SelectedFit: Fit>: Ephemeris {
		public typealias Body = ELPMPP02.Body
		public typealias Frame = SelectedFit.Ecliptic

		/// The Earth, the center of the solution.
		public static var defaultOrigin: Body {
			.earth
		}

		/// Creates the solution with a fit of its constants.
		///
		/// - Parameter fit: The fit.
		public init(fit: SelectedFit.Type) {}

		public var coverage: ClosedRange<Instant<TDB>> {
			Instant(builtInEphemerisCoverage.lowerBound) ... Instant(builtInEphemerisCoverage.upperBound)
		}

		public func state(of body: Body, relativeTo origin: Body, at tdb: Instant<TDB>) throws(EphemerisError) -> StateVector<SelectedFit.Ecliptic> {
			guard coverage.contains(tdb) else { throw .outsideCoverage }
			if body == origin {
				return .zero
			}
			guard let moon = ELPMPP02.eclipticState(at: tdb.julianDate, series: SelectedFit.series) else {
				preconditionFailure("\(tdb.julianDate) is outside the coverage of ELP/MPP02")
			}
			let state = StateVector<SelectedFit.Ecliptic>(moon.position, moon.velocity)
			return body == .moon ? state : -state
		}
	}
}

extension ELPMPP02.Solution where SelectedFit == ELPMPP02.DE405 {
	/// Creates the solution with the default fit, ``ELPMPP02/DE405``.
	public init() {
		self.init(fit: ELPMPP02.DE405.self)
	}
}
