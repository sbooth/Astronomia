//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// The Terrestrial Intermediate Reference System (TIRS).
///
/// The z axis points to the celestial intermediate pole (CIP) and the x axis to the
/// terrestrial intermediate origin (TIO), near the Greenwich meridian. The frame is the
/// ``CIRS`` turned about the CIP by the Earth rotation angle, so the longitude of a celestial
/// body in it is the negative of its Greenwich hour angle measured from the TIO. The IAU named
/// the system in 2006 (Resolution B2).
///
/// Its epoch is the instant in TT whose CIP fixes the axes.
public enum TIRS: TerrestrialReferenceFrame {
	public typealias Epoch = Instant<TT>
	public static let name = "TIRS"

	public static func rotationFromICRS(at tt: Instant<TT>, ut1: Instant<UT1>, earthOrientation: EarthOrientation) -> Rotation<ICRS, TIRS> {
		IAU2006.terrestrialIntermediate(at: tt, ut1: ut1, earthOrientation: earthOrientation).relabeled(fromFrameEpoch: NoEpoch(), toFrameEpoch: tt)
	}

	/// Returns the Earth's angular velocity, along the CIP.
	public static func angularVelocity(at tt: Instant<TT>, earthOrientation: EarthOrientation) -> SIMD3<Double> {
		SIMD3(0, 0, earthOrientation.rotationRate(at: tt))
	}
}
