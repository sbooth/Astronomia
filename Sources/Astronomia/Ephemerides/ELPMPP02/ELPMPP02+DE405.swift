//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

extension ELPMPP02 {
	/// ELP/MPP02 fitted to the DE405 ephemeris from 1950 to 2060, with corrections to the
	/// secular terms of the lunar angles that follow DE405 over several thousand years, for
	/// J1000.0 to J3000.0.
	///
	/// States are geocentric unless the origin is the Moon. With the published orientation of
	/// its frame, this fit agrees with modern ephemerides near the present to about 6 mas, so it
	/// is the library's default. Use ``ELPMPP02/de405``.
	public struct DE405: Ephemeris, Fit {
		/// The inertial mean ecliptic and equinox of J2000.0 as realized by the fit.
		///
		/// The frame is the axes of DE405 rotated by R1(ε) R3(φ), with ε = 23° 26' 21.40960" and
		/// φ = -0.05028" (Chapront et al. 2002, Table 9). The axes of DE405 are within a few
		/// milliarcseconds of the ICRS, so the frame is taken relative to the ICRS.
		///
		/// - Note: This is not ``EclipticJ2000``, the ecliptic of the IAU 2006 precession, from
		///   which it differs by a few milliarcseconds.
		public enum Ecliptic: EclipticFrame, FixedReferenceFrame {
			public static let name = "ELP/MPP02 (DE405) ecliptic J2000"

			public static let rotationFromICRS = Rotation<ICRS, Ecliptic>.aboutX(.arcseconds(84_381.409_60))
				* Rotation<ICRS, ICRS>.aboutZ(.arcseconds(-0.050_28))
		}

		public typealias Body = ELPMPP02.Body
		public typealias Frame = Ecliptic

		/// The Earth, the center of the solution.
		public static let defaultOrigin = Body.earth

		/// The series with the constants fitted to DE405, from `ELPMPP02.for`.
		static let series = Series(corrections: Corrections(
			w10: -0.070_08, w20: 0.207_94, w30: -0.072_15, earth0: -0.000_33, perihelion0: -0.007_49,
			w11: -0.351_06, gamma: 0.000_85, e: -0.000_06, earth1: 0.007_32, eccentricity: 0.002_24,
			w21: 0.080_17, w31: -0.043_17, w12: -0.037_43,
			secular: SecularCorrections(w13: -0.000_188_65, w14: -0.000_010_24, w22: 0.004_706_02, w23: -0.000_252_13, w32: -0.002_610_70, w33: -0.000_107_12)
		))

		/// Creates the solution. ``ELPMPP02/de405`` is an instance.
		public init() {}

		public var coverage: ClosedRange<Instant<TDB>> { builtInEphemerisInstants }

		public func state(of body: Body, relativeTo origin: Body, at tdb: Instant<TDB>) throws(EphemerisError) -> StateVector<Ecliptic> {
			try Self.fitState(of: body, relativeTo: origin, at: tdb)
		}
	}
}
