//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// An error from combining or rotating coordinates.
public enum CoordinateError: Error, Hashable, Sendable {
	/// Values in a frame of date at different epochs were combined, or a value was rotated by a
	/// rotation for another epoch of its frame.
	case epochMismatch
}

/// Throws unless two epochs of a frame of date are the same.
///
/// - Parameters:
///   - lhs: One epoch.
///   - rhs: The other.
/// - Throws: ``CoordinateError/epochMismatch`` if the epochs differ.
@inline(__always) func checkSameEpoch(_ lhs: Instant<TT>, _ rhs: Instant<TT>) throws(CoordinateError) {
	guard lhs == rhs else { throw .epochMismatch }
}
