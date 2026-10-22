//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

extension IAU2006 {
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
