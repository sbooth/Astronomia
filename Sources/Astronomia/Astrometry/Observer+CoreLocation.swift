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
	///   - coordinate: The geodetic coordinate, on the WGS84 ellipsoid.
	///   - height: The height above the ellipsoid. A GPS receiver gives this height; a height
	///     above mean sea level differs from it by the geoid's height, up to about 100 m.
	/// - Returns: The observer.
	/// - Throws:
	///   - ``ObserverError/nonFiniteValue`` if a coordinate is NaN or infinite.
	///   - ``ObserverError/invalidLatitude`` if the latitude is outside the closed
	///     interval [-90, 90]°.
	///   - ``ObserverError/invalidHeight`` if the height is more than 100 km above or below
	///     the ellipsoid.
	public static func site(coordinate: CLLocationCoordinate2D, height: Distance = .zero) throws(ObserverError) -> Observer {
		try site(latitude: .degrees(coordinate.latitude), longitude: .degrees(coordinate.longitude), height: height, ellipsoid: .wgs84)
	}

	/// Returns an observer at a site given by `location`.
	///
	/// The site is the location's coordinate, at its `ellipsoidalAltitude`, the height above the
	/// WGS84 ellipsoid, not its `altitude` above mean sea level. A location must have both: Core
	/// Location marks a coordinate it doesn't have with a negative `horizontalAccuracy`, and an
	/// altitude with a `verticalAccuracy` of 0 or less, as for a location found without GPS.
	///
	/// - Parameters:
	///   - location: The location.
	/// - Returns: The observer.
	/// - Throws:
	///   - ``ObserverError/nonFiniteValue`` if a coordinate is NaN or infinite.
	///   - ``ObserverError/invalidLatitude`` if the location has no valid coordinate, or the
	///     latitude is outside the closed interval [-90, 90]°.
	///   - ``ObserverError/invalidHeight`` if the location has no valid altitude, or the
	///     height is more than 100 km above or below the ellipsoid.
	@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
	public static func site(_ location: CLLocation) throws(ObserverError) -> Observer {
		guard location.horizontalAccuracy >= 0 else { throw .invalidLatitude }
		guard location.verticalAccuracy > 0 else { throw .invalidHeight }
		return try site(coordinate: location.coordinate, height: .meters(location.ellipsoidalAltitude))
	}
}

#endif
