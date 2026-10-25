//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

extension Observation {
	/// Returns the angular radius of a body as the observer sees it.
	///
	/// The semidiameter is asin(R / d), the angle at the observer between the body's center and
	/// the edge of a sphere of the body's radius R from the ephemeris at the distance d of its
	/// apparent place. From a site the Moon is nearer when it is higher, so its semidiameter
	/// there is larger than from the center of the Earth, by up to about 0.3' at the zenith.
	///
	/// ```swift
	/// let sky = try site.observation(at: instant)
	/// let moon = try sky.semidiameter(of: .moon)
	/// ```
	///
	/// - Parameter body: The body.
	/// - Returns: The semidiameter, in the closed interval [0, 90]°, or `nil` for a body
	///   without a radius in the ephemeris.
	/// - Throws: An ``EphemerisError``, as the apparent place of a body does.
	public func semidiameter(of body: E.Body) throws(EphemerisError) -> Angle? {
		guard let radius = E.radius(of: body) else { return nil }
		let distance = try apparentPlace(of: body).position.distance
		return .asin(min(radius.astronomicalUnits / distance.astronomicalUnits, 1))
	}
}
