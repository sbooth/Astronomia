//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

extension ELPMPP02 {
	/// ELP/MPP02 fitted to lunar laser ranging from 1970 to 2001, the default of the solution
	/// itself, for J1000.0 to J3000.0.
	///
	/// States are geocentric unless the origin is the Moon. With the published orientation of
	/// its frame, this fit differs from modern ephemerides by about 40 mas, mostly in its origin
	/// of longitudes. Use ``ELPMPP02/laserRanging``.
	public struct LaserRanging: Ephemeris, Fit {
		/// The inertial mean ecliptic and equinox of J2000.0 as realized by the fit.
		///
		/// The frame is the ICRS rotated by R1(ε) R3(φ), with ε = 23° 26′ 21.41100″ and
		/// φ = -0.05542″ (Chapront et al. 2002, Table 9).
		///
		/// - Note: The angles come from the solution S2001, which precedes ELP/MPP02. Chapront and
		///   Francou (2003) note that the two fits differ mainly by their origin of longitudes,
		///   by about 0.036″. This is not ``EclipticJ2000``, the ecliptic of the IAU 2006
		///   precession.
		public enum Ecliptic: EclipticFrame, FixedReferenceFrame {
			public static let name = "ELP/MPP02 (LLR) ecliptic J2000"

			public static let rotationFromICRS = Rotation<ICRS, Ecliptic>.aboutX(.arcseconds(84_381.411_00))
				* Rotation<ICRS, ICRS>.aboutZ(.arcseconds(-0.055_42))
		}

		public typealias Body = ELPMPP02.Body
		public typealias Frame = Ecliptic

		/// The Earth, the center of the solution.
		public static let defaultOrigin = Body.earth

		/// The series with the constants fitted to lunar laser ranging, from `ELPMPP02.for`.
		static let series = Series(corrections: Corrections(
			w10: -0.105_25, w20: 0.168_26, w30: -0.107_60, earth0: -0.040_12, perihelion0: -0.048_54,
			w11: -0.323_11, gamma: 0.000_69, e: 0.000_05, earth1: 0.014_42, eccentricity: 0.002_26,
			w21: 0.080_17, w31: -0.043_17, w12: -0.037_94,
			secular: nil
		))

		/// Creates the solution. ``ELPMPP02/laserRanging`` is an instance.
		public init() {}

		public var coverage: ClosedRange<Instant<TDB>> { builtInEphemerisInstants }

		public func state(of body: Body, relativeTo origin: Body, at tdb: Instant<TDB>) throws(EphemerisError) -> StateVector<Ecliptic> {
			try Self.fitState(of: body, relativeTo: origin, at: tdb)
		}
	}
}
