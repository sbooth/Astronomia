//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// The orientation of a set of coordinate axes.
///
/// Conforming types are caseless enums used only as type-level tags for ``Position`` and
/// ``Rotation``, as timescales are for ``Instant``. A frame fixes the directions of the axes,
/// not the origin: the same frame serves barycentric, heliocentric, and geocentric
/// positions.
///
/// A frame is fixed relative to the ICRS, a ``FixedReferenceFrame``; a celestial frame of date,
/// a ``DatedReferenceFrame``, whose axes also depend on an instant, its epoch; or a frame that
/// turns with the Earth, a ``TerrestrialReferenceFrame``.
public protocol ReferenceFrame: Sendable {
	/// The kind of epoch that fixes the frame's axes along with its definition: ``NoEpoch``
	/// for a frame that needs none, such as a fixed frame or the ``ITRS``, or an instant for a
	/// frame of date.
	associatedtype Epoch: Hashable & Sendable = NoEpoch

	/// The conventional name of the frame, such as `"ICRS"`.
	static var name: String { get }
}
