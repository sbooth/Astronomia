//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// The epoch of a frame that needs none, such as a frame fixed relative to the ICRS or to the
/// Earth.
public struct NoEpoch: Hashable, Sendable {
	/// Creates the empty epoch.
	init() {}
}
