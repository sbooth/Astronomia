//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// The true equator and equinox of date.
///
/// The z axis points to the celestial intermediate pole (CIP), which precesses and nutates,
/// and the x axis to the true equinox of date, where the ecliptic of date crosses the true
/// equator. Right ascensions in this frame are those of almanacs "of date" and of Greenwich
/// apparent sidereal time. The frame is the ICRS rotated by the frame bias, the IAU 2006
/// precession, and the IAU 2000A_R06 nutation, corrected by the celestial pole offsets of the
/// Earth orientation context.
public enum TrueEquatorOfDate: EquatorialFrame, DatedReferenceFrame {
	public static let name = "True equator of date"

	public static func rotationFromICRS(at epoch: Instant<TT>, earthOrientation: EarthOrientation) -> Rotation<ICRS, TrueEquatorOfDate> {
		let orientation = IAU2006.Orientation(at: epoch, earthOrientation: earthOrientation)
		return orientation.trueEquator.relabeled(fromFrameEpoch: NoEpoch(), toFrameEpoch: epoch)
	}
}
