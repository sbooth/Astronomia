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
/// The Earth's rotation also needs UT1, from ``ut1``, which by default takes ΔT from the
/// table, then the built-in ΔT table and model.
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
	public let table: EarthOrientationTable?
	/// The source of UT1 for the Earth's rotation.
	public let ut1: UT1.Context

	/// Creates a description of the Earth's orientation.
	///
	/// - Parameters:
	///   - table: Observed and predicted Earth orientation parameters, or `nil` for the models
	///     alone.
	///   - ut1: The source of UT1, or `nil` for a context that takes ΔT from `table`, then the
	///     built-in ΔT table and model, as
	///     ``UT1/Context/init(earthOrientation:deltaTTable:model:)`` does.
	public init(table: EarthOrientationTable? = nil, ut1: UT1.Context? = nil) {
		self.table = table
		self.ut1 = ut1 ?? UT1.Context(earthOrientation: table)
	}

	/// Returns the polar motion at a TT instant, or zero if the table doesn't cover it or has
	/// none.
	///
	/// - Parameter tt: An instant in TT.
	/// - Returns: x_p and y_p, in radians.
	func polarMotion(at tt: Instant<TT>) -> (x: Double, y: Double) {
		guard let motion = table?.polarMotion(at: tt.julianDate) else { return (0, 0) }
		return (motion.x.radians, motion.y.radians)
	}

	/// Returns the Earth's rate of rotation at a TT instant: the nominal rate of the Earth
	/// rotation angle, slowed by the excess length of day where the table has it.
	///
	/// - Parameter tt: An instant in TT.
	/// - Returns: The rate, in radians per day of 86,400 s.
	func rotationRate(at tt: Instant<TT>) -> Double {
		let excess = table?.excessLengthOfDay(at: tt.julianDate) ?? 0
		return twoPi * (1 + EarthRotation.excessTurnsPerDay) * (1 - excess / secondsPerDay)
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
