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
}
