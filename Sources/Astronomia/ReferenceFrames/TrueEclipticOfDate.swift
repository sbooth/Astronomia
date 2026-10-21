//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// The ecliptic of date with the true equinox of date.
///
/// The z axis points to the pole of the ecliptic of date, as in ``MeanEclipticOfDate``, which
/// nutation does not move, and the x axis to the true equinox of date. Ecliptic longitudes
/// in this frame are the mean longitudes plus the nutation in longitude, as for the apparent
/// longitude of the Sun at the equinoxes and solstices. The frame is the
/// ``TrueEquatorOfDate`` rotated by the true obliquity, R1(ε_A + Δε).
public enum TrueEclipticOfDate: EclipticFrame, DatedReferenceFrame {
	public static let name = "True ecliptic of date"

	public static func rotationFromICRS(at epoch: Instant<TT>, earthOrientation: EarthOrientation) -> Rotation<ICRS, TrueEclipticOfDate> {
		let orientation = IAU2006.Orientation(at: epoch, earthOrientation: earthOrientation)
		return orientation.trueEcliptic.relabeled(fromFrameEpoch: NoEpoch(), toFrameEpoch: epoch)
	}
}
