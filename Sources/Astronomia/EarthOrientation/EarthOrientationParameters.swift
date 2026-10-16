//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// The position of the celestial intermediate pole (CIP) in the International Terrestrial
/// Reference System (ITRS).
///
/// Polar motion relates the terrestrial intermediate reference system, which rotates with the
/// CIP, to the ITRS, which is fixed to Earth's crust. The coordinate x_p is measured along the
/// meridian of Greenwich and y_p along the meridian 90° west. Each is a few tenths of an
/// arcsecond, combining the Chandler wobble, an annual term, and a slow drift.
public struct PolarMotion: Hashable, Sendable {
	/// The x coordinate of the pole, x_p.
	public let x: Angle
	/// The y coordinate of the pole, y_p.
	public let y: Angle
	/// Whether the coordinates are a prediction rather than an observation.
	public let isPredicted: Bool

	/// Creates polar motion coordinates.
	///
	/// - Parameters:
	///   - x: The x coordinate of the pole, x_p.
	///   - y: The y coordinate of the pole, y_p.
	///   - isPredicted: Whether the coordinates are a prediction.
	public init(x: Angle, y: Angle, isPredicted: Bool = false) {
		self.x = x
		self.y = y
		self.isPredicted = isPredicted
	}
}

/// Observed offsets of the celestial intermediate pole (CIP) from the IAU 2006/2000A
/// precession-nutation model.
///
/// The model does not include the free core nutation, which is not predictable, or its own
/// small errors. The IERS publishes the observed differences as dX and dY, corrections to the
/// model's X and Y coordinates of the CIP in the Geocentric Celestial Reference System. They
/// are a few tenths of a milliarcsecond.
public struct CelestialPoleOffsets: Hashable, Sendable {
	/// The correction to the X coordinate of the CIP, dX.
	public let dX: Angle
	/// The correction to the Y coordinate of the CIP, dY.
	public let dY: Angle
	/// Whether the offsets are a prediction rather than an observation.
	public let isPredicted: Bool

	/// Creates celestial pole offsets.
	///
	/// - Parameters:
	///   - dX: The correction to the X coordinate of the CIP.
	///   - dY: The correction to the Y coordinate of the CIP.
	///   - isPredicted: Whether the offsets are a prediction.
	public init(dX: Angle, dY: Angle, isPredicted: Bool = false) {
		self.dX = dX
		self.dY = dY
		self.isPredicted = isPredicted
	}
}
