//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// The Celestial Intermediate Reference System (CIRS).
///
/// The z axis points to the celestial intermediate pole (CIP), as in ``TrueEquatorOfDate``,
/// and the x axis to the celestial intermediate origin (CIO), a point on the CIP's equator
/// that does not rotate about the pole as the pole moves. Right ascensions in this frame
/// differ from those of the true equinox by the equation of the origins, and the hour angle
/// is the Earth rotation angle less the right ascension. The IAU adopted the CIO in 2000 and
/// named the system in 2006 (Resolution B2).
///
/// - Note: Here a frame is only a set of axes. Libraries such as Astropy also use the name
///   for apparent places, which include aberration and light deflection.
public enum CIRS: EquatorialFrame, DatedReferenceFrame {
	public static let name = "CIRS"

	public static func rotationFromICRS(at epoch: Instant<TT>, earthOrientation: EarthOrientation) -> Rotation<ICRS, CIRS> {
		let orientation = IAU2006.Orientation(at: epoch, earthOrientation: earthOrientation)
		return orientation.intermediate.relabeled(fromFrameEpoch: NoEpoch(), toFrameEpoch: epoch)
	}
}
