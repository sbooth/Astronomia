//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

extension EarthOrientationTable: DeltaTSource {
	/// Returns ΔT = TT - UT1, in seconds, at the specified TT, interpolated linearly between
	/// entries, or `nil` if `tt` is outside ``range``. Predicted entries are used.
	public func deltaT(at tt: JulianDate) -> Double? {
		deltaTAndPredictionStatus(at: tt)?.seconds
	}
}
