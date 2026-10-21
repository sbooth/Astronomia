//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// How the orientation of the Earth is determined: by the IAU models alone, or corrected by
/// observed and predicted Earth orientation parameters.
///
/// The frames of date follow the IAU 2006/2000A precession-nutation model. The model leaves
/// out the free core nutation and its own small errors, a few tenths of a milliarcsecond,
/// which the IERS publishes as the celestial pole offsets dX and dY. With a table that
/// covers the date, the frames apply its offsets; otherwise they follow the model alone.
///
/// ```swift
/// let observed = EarthOrientation(table: table)
/// let tod = icrs.converted(to: TrueEquatorOfDate.self, at: tt, earthOrientation: observed)
/// let cirs = icrs.converted(to: CIRS.self, at: tt) // earthOrientation: .model
/// ```
public struct EarthOrientation: Sendable {
	/// The IAU models alone.
	public static let model = EarthOrientation()

	/// Observed and predicted Earth orientation parameters, or `nil` for the models alone.
	public var table: EarthOrientationTable?

	/// Creates a context.
	///
	/// - Parameter table: Observed and predicted Earth orientation parameters, or `nil` for
	///   the models alone.
	public init(table: EarthOrientationTable? = nil) {
		self.table = table
	}

	/// Returns the celestial pole offsets at a TT instant, if the table covers it and has them.
	///
	/// - Parameter tt: An instant in TT.
	/// - Returns: dX and dY, in radians, or `nil`.
	func poleOffsets(at tt: Instant<TT>) -> (dX: Double, dY: Double)? {
		guard let offsets = table?.celestialPoleOffsets(at: tt.julianDate) else { return nil }
		return (offsets.dX.radians, offsets.dY.radians)
	}
}
