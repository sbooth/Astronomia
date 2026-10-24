//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// Errors that can occur when creating an event altitude.
public enum EventAltitudeError: Error, Hashable, Sendable {
	/// A value is NaN or infinite.
	case nonFiniteValue
	/// The altitude is outside the closed interval [-90, 90]°.
	case invalidAltitude
	/// The radius is negative.
	case invalidRadius
}
