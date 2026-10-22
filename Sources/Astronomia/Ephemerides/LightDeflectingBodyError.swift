//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// Errors that can occur when creating a light-deflecting body.
public enum LightDeflectingBodyError: Error, Hashable, Sendable {
	/// The gravitational parameter is negative, NaN, or infinite.
	case invalidGravitationalParameter
	/// The radius is zero, negative, NaN, or infinite.
	case invalidRadius
}
