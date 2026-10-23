//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

extension VSOP2013 {
	/// The solution as an ephemeris of the Sun, the planets, and the Earth-Moon barycenter, in
	/// the solution's ecliptic, for J1000.0 to J3000.0.
	///
	/// States are heliocentric unless another origin is given. For the Earth and the Moon, use
	/// ``BuiltInEphemeris``.
	///
	/// ```swift
	/// let mars = try VSOP2013.Solution().state(of: .mars, at: instant)
	/// let fast = try VSOP2013.Solution(precision: .arcsecond).state(of: .mars, at: instant)
	/// ```
	///
	/// - Note: Pluto's solution is less accurate than the planets'.
	public struct Solution: Ephemeris, Hashable {
		public typealias Body = VSOP2013.Body
		public typealias Frame = Ecliptic

		/// The Sun, the center of the solution.
		public static let defaultOrigin = Body.sun

		/// The precision level of the series.
		public let precision: Precision

		/// Creates the solution.
		///
		/// - Parameter precision: The precision level of the series, by default
		///   ``Precision/full``.
		public init(precision: Precision = .full) {
			self.precision = precision
		}

		public var coverage: ClosedRange<Instant<TDB>> { builtInEphemerisInstants }

		public func state(of body: Body, relativeTo origin: Body, at tdb: Instant<TDB>) throws(EphemerisError) -> StateVector<Ecliptic> {
			guard coverage.contains(tdb) else { throw .outsideCoverage }
			if body == origin {
				return .zero
			}
			guard let state = VSOP2013.heliocentricState(of: body, at: tdb.julianDate, precision: precision),
			      let originState = VSOP2013.heliocentricState(of: origin, at: tdb.julianDate, precision: precision)
			else {
				preconditionFailure("\(tdb.julianDate) is outside the coverage of VSOP2013")
			}
			return StateVector(state.position - originState.position, state.velocity - originState.velocity)
		}
	}

	/// The solution at full precision.
	public static let solution = VSOP2013.Solution()
}
