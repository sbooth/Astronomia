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
	///
	/// - Parameters:
	///   - expected: The epoch the operation required.
	///   - actual: The epoch of the value it was given.
	case epochMismatch(expected: Instant<TT>, actual: Instant<TT>)
}

/// Throws unless a value's epoch of a frame of date is the one an operation requires.
///
/// - Parameters:
///   - expected: The epoch the operation requires.
///   - actual: The epoch of the value.
/// - Throws: ``CoordinateError/epochMismatch(expected:actual:)`` if the epochs differ.
@inline(__always) func checkEpoch(expected: Instant<TT>, actual: Instant<TT>) throws(CoordinateError) {
	guard expected == actual else { throw .epochMismatch(expected: expected, actual: actual) }
}
