//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Foundation
import CAstronomyEngine

/// An observation location on or near the Earth's surface specified using the WGS-84 reference frame.
public struct ObservationLocation: Hashable {
	/// The latitude of the observer in degrees.
	///
	/// Positive values indicate latitudes north of the equator, negative south.
	public let latitude: Double
	/// The longitude of the observer in degrees.
	///
	/// Positive values indicate longitudes east of the zero meridian, negative west.
	public let longitude: Double
	/// The observer's height in meters MSL.
	public let height: Double

	/// Initializes `self` with the specified latitude, longitude, and height.
	public init(latitude: Double, longitude: Double, height: Double = 0) {
		precondition(latitude >= -90)
		precondition(latitude <= +90)
		precondition(longitude >= -180)
		precondition(longitude <= +180)
		self.latitude = latitude
		self.longitude = longitude
		self.height = height
	}
}

extension ObservationLocation {
	/// Converts `self` to an `astro_observer_t` instance.
	func toAstroObserver() -> astro_observer_t {
		Astronomy_MakeObserver(latitude, longitude, height)
	}
}

#if canImport(CoreLocation)
import CoreLocation

extension ObservationLocation {
	/// Initializes `self` to the value of `location`.
	public init(_ location: CLLocationCoordinate2D) {
		self.init(latitude: location.latitude, longitude: location.longitude)
	}

	/// Converts `self` to a `CLLocationCoordinate2D` instance.
	public func toCLLocationCoordinate2D() -> CLLocationCoordinate2D {
		CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
	}
}
#endif
