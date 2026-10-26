//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

#if canImport(CoreLocation)

import CoreLocation
import Testing
@testable import Astronomia

@Suite struct ObserverCoreLocationTests {
	static let coordinate = CLLocationCoordinate2D(latitude: 40.015, longitude: -105.27)

	/// Returns a location at the coordinate with the given accuracies.
	static func location(horizontalAccuracy: Double = 5, verticalAccuracy: Double = 3) -> CLLocation {
		CLLocation(coordinate: coordinate, altitude: 1_655, horizontalAccuracy: horizontalAccuracy, verticalAccuracy: verticalAccuracy, timestamp: Date())
	}

	@Test func coordinateIsTheGeodeticCoordinate() throws {
		let observer = try Observer.site(coordinate: Self.coordinate, height: .meters(1_655))
		let expected = try Observer.site(latitude: .degrees(40.015), longitude: .degrees(-105.27), height: .meters(1_655))
		#expect(observer == expected)
	}

	@Test func invalidCoordinatesThrow() {
		#expect(throws: ObserverError.invalidLatitude) {
			try Observer.site(coordinate: kCLLocationCoordinate2DInvalid)
		}
		#expect(throws: ObserverError.nonFiniteValue) {
			try Observer.site(coordinate: CLLocationCoordinate2D(latitude: .nan, longitude: 0))
		}
	}

	@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
	@Test func locationIsAtItsEllipsoidalAltitude() throws {
		let location = Self.location()
		let observer = try Observer.site(location)
		let expected = try Observer.site(coordinate: Self.coordinate, height: .meters(location.ellipsoidalAltitude))
		#expect(observer == expected)
	}

	@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
	@Test func locationsWithoutACoordinateOrAltitudeThrow() throws {
		// A negative horizontal accuracy marks an invalid coordinate; 0 is valid.
		#expect(throws: ObserverError.invalidLatitude) {
			try Observer.site(Self.location(horizontalAccuracy: -1))
		}
		_ = try Observer.site(Self.location(horizontalAccuracy: 0))
		// A vertical accuracy of 0 or less marks an invalid altitude.
		for accuracy in [0.0, -1] {
			#expect(throws: ObserverError.invalidHeight) {
				try Observer.site(Self.location(verticalAccuracy: accuracy))
			}
		}
	}
}

#endif
