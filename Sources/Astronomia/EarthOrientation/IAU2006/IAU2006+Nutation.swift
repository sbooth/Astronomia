//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

extension IAU2006 {
	/// The nutation in longitude and in obliquity.
	public struct Nutation: Hashable, Sendable {
		/// The nutation in longitude, Δψ: the motion of the true equinox along the ecliptic.
		public let longitude: Angle
		/// The nutation in obliquity, Δε: the change in the obliquity of the true equator.
		public let obliquity: Angle

		/// Creates a nutation.
		///
		/// - Parameters:
		///   - longitude: The nutation in longitude, Δψ.
		///   - obliquity: The nutation in obliquity, Δε.
		public init(longitude: Angle, obliquity: Angle) {
			self.longitude = longitude
			self.obliquity = obliquity
		}
	}

	/// Returns the nutation at an instant, IAU 2000A_R06.
	///
	/// With celestial pole offsets from `earthOrientation`, the nutation is corrected so that it
	/// moves the pole by them.
	///
	/// - Parameters:
	///   - tt: An instant in TT.
	///   - earthOrientation: Observed Earth orientation to apply.
	/// - Returns: The nutation in longitude and obliquity.
	public static func nutation(at tt: Instant<TT>, earthOrientation: EarthOrientation = .model) -> Nutation {
		let nutation = Orientation(at: tt, earthOrientation: earthOrientation).nutation
		return Nutation(longitude: Angle(radians: nutation.longitude), obliquity: Angle(radians: nutation.obliquity))
	}

	/// Returns the mean obliquity of the ecliptic, ε_A, IAU 2006.
	///
	/// - Parameter tt: An instant in TT.
	/// - Returns: The angle between the mean equator and the ecliptic of date.
	public static func meanObliquity(at tt: Instant<TT>) -> Angle {
		Angle(radians: precessionAngles(at: tt.julianDate.julianCenturiesSinceJ2000).epsilon)
	}

	/// Returns the X and Y coordinates of the celestial intermediate pole (CIP) in the GCRS.
	///
	/// X and Y are the first two components of the unit vector toward the CIP, as angles.
	///
	/// - Parameters:
	///   - tt: An instant in TT.
	///   - earthOrientation: Observed Earth orientation to apply.
	/// - Returns: X and Y, with any celestial pole offsets added.
	public static func celestialIntermediatePole(at tt: Instant<TT>, earthOrientation: EarthOrientation = .model) -> (x: Angle, y: Angle) {
		let pole = Orientation(at: tt, earthOrientation: earthOrientation).pole
		return (Angle(radians: pole.x), Angle(radians: pole.y))
	}

	/// Returns the CIO locator s, which places the celestial intermediate origin on the CIP's
	/// equator, from the series for s + XY/2 of the IERS Conventions (2010), Table 5.2d.
	///
	/// - Parameter tt: An instant in TT.
	/// - Returns: s, a few milliarcseconds over the centuries around J2000.0.
	public static func cioLocator(at tt: Instant<TT>) -> Angle {
		Angle(radians: Orientation(at: tt, earthOrientation: .model).s)
	}
}

extension IAU2006 {
	/// Returns the nutation at an instant in any timescale, IAU 2000A_R06.
	///
	/// - Parameters:
	///   - instant: An instant, which is converted to TT.
	///   - context: Observational data for converting `instant` to TT.
	///   - earthOrientation: Observed Earth orientation to apply.
	/// - Returns: The nutation in longitude and obliquity.
	/// - Throws: A ``TimescaleConversionError`` if `instant` can't be converted to TT.
	public static func nutation<Scale: Timescale>(at instant: Instant<Scale>, context: Scale.Context = Scale.defaultContext, earthOrientation: EarthOrientation = .model) throws(TimescaleConversionError) -> Nutation {
		nutation(at: try instant.converted(to: TT.self, sourceContext: context), earthOrientation: earthOrientation)
	}

	/// Returns the mean obliquity of the ecliptic at an instant in any timescale, IAU 2006.
	///
	/// - Parameters:
	///   - instant: An instant, which is converted to TT.
	///   - context: Observational data for converting `instant` to TT.
	/// - Returns: The angle between the mean equator and the ecliptic of date.
	/// - Throws: A ``TimescaleConversionError`` if `instant` can't be converted to TT.
	public static func meanObliquity<Scale: Timescale>(at instant: Instant<Scale>, context: Scale.Context = Scale.defaultContext) throws(TimescaleConversionError) -> Angle {
		meanObliquity(at: try instant.converted(to: TT.self, sourceContext: context))
	}

	/// Returns the X and Y coordinates of the CIP in the GCRS at an instant in any timescale.
	///
	/// - Parameters:
	///   - instant: An instant, which is converted to TT.
	///   - context: Observational data for converting `instant` to TT.
	///   - earthOrientation: Observed Earth orientation to apply.
	/// - Returns: X and Y, with any celestial pole offsets added.
	/// - Throws: A ``TimescaleConversionError`` if `instant` can't be converted to TT.
	public static func celestialIntermediatePole<Scale: Timescale>(at instant: Instant<Scale>, context: Scale.Context = Scale.defaultContext, earthOrientation: EarthOrientation = .model) throws(TimescaleConversionError) -> (x: Angle, y: Angle) {
		celestialIntermediatePole(at: try instant.converted(to: TT.self, sourceContext: context), earthOrientation: earthOrientation)
	}

	/// Returns the CIO locator s at an instant in any timescale.
	///
	/// - Parameters:
	///   - instant: An instant, which is converted to TT.
	///   - context: Observational data for converting `instant` to TT.
	/// - Returns: s.
	/// - Throws: A ``TimescaleConversionError`` if `instant` can't be converted to TT.
	public static func cioLocator<Scale: Timescale>(at instant: Instant<Scale>, context: Scale.Context = Scale.defaultContext) throws(TimescaleConversionError) -> Angle {
		cioLocator(at: try instant.converted(to: TT.self, sourceContext: context))
	}
}

extension IAU2006.Orientation {
	/// Computes the orientation at an instant.
	///
	/// - Parameters:
	///   - tt: An instant in TT.
	///   - earthOrientation: Observed Earth orientation, whose pole offsets are applied where its
	///     table covers `tt`.
	init(at tt: Instant<TT>, earthOrientation: EarthOrientation) {
		self.init(at: tt.julianDate.julianCenturiesSinceJ2000, poleOffsets: earthOrientation.poleOffsets(at: tt))
	}
}
