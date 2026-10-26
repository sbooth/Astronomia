//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

#if canImport(CoreLocation)

import CoreLocation

extension Observer {
	/// Returns an observer at a site given by `coordinate`.
	///
	/// - Parameters:
	///   - coordinate: The geodetic coordinate.
	///   - height: The height above the ellipsoid. A GPS receiver gives this height; a height
	///     above mean sea level differs from it by the geoid's height, up to about 100 m.
	/// - Returns: The observer.
	/// - Throws:
	///   - ``ObserverError/nonFiniteValue`` if a coordinate is NaN or infinite.
	///   - ``ObserverError/invalidLatitude`` if the latitude is outside the closed interval [-90, 90]°.
	///   - ``ObserverError/invalidHeight`` if the height is more than 100 km above or below
	///     the ellipsoid.
	public static func site(coordinate: CLLocationCoordinate2D, height: Distance = .zero) throws(ObserverError) -> Observer {
		try site(latitude: .degrees(coordinate.latitude), longitude: .degrees(coordinate.longitude), height: height, ellipsoid: .wgs84)
	}

	/// Returns an observer at a site given by `location`.
	///
	/// - Parameters:
	///   - location: The geodetic coordinate and altitude.
	/// - Returns: The observer.
	/// - Throws:
	///   - ``ObserverError/nonFiniteValue`` if a coordinate is NaN or infinite.
	///   - ``ObserverError/invalidLatitude`` if the latitude is outside the closed interval [-90, 90]°.
	///   - ``ObserverError/invalidHeight`` if the height is more than 100 km above or below
	///     the ellipsoid.
	@available(macOS 12, *)
	public static func site(_ location: CLLocation) throws(ObserverError) -> Observer {
		guard location.verticalAccuracy > 0 else { throw .invalidHeight }
		return try site(coordinate: location.coordinate, height: .meters(location.ellipsoidalAltitude))
	}
}

#endif
