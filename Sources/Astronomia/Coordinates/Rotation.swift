//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// A rotation of coordinate axes from one reference frame to another.
///
/// A rotation takes the coordinates of a vector in the `From` frame to its coordinates in the
/// `To` frame. The vector itself does not move; the axes do. Rotations compose with `*`,
/// applied right to left as matrices are:
///
/// ```swift
/// let ab: Rotation<A, B> = …
/// let bc: Rotation<B, C> = …
/// let ac: Rotation<A, C> = bc * ab
/// ```
///
/// The elementary rotations ``aboutX(_:)``, ``aboutY(_:)``, and ``aboutZ(_:)`` follow the
/// SOFA convention: R1(θ), R2(θ), and R3(θ) rotate the axes by θ counterclockwise about the
/// x, y, and z axes, seen from the positive end of the axis.
///
/// A rotation to or from a frame with an epoch, such as a ``DatedReferenceFrame``, is for one
/// epoch of that frame. It gives values at its `To` epoch, and a rotation from a frame with an
/// epoch applies only to values at its `From` epoch, so it rotates and composes with the
/// throwing `apply(to:)` and `composed(after:)` in place of `*`. A rotation between two epochs
/// of the same frame of date, such as precession from one date to another, is a
/// `Rotation<F, F>`.
public struct Rotation<From: ReferenceFrame, To: ReferenceFrame>: Hashable, Sendable {
	/// The rows of the rotation matrix.
	let storage: (Vector3, Vector3, Vector3)
	/// The epoch of the `From` frame, ``NoEpoch`` for a frame without one.
	let fromFrameEpoch: From.Epoch
	/// The epoch of the `To` frame, ``NoEpoch`` for a frame without one.
	let toFrameEpoch: To.Epoch

	/// Creates a rotation from the rows of an orthogonal matrix and the epochs of its frames.
	///
	/// - Precondition: The matrix is orthogonal with determinant 1.
	init(uncheckedRows r0: Vector3, _ r1: Vector3, _ r2: Vector3, fromFrameEpoch: From.Epoch, toFrameEpoch: To.Epoch) {
		storage = (r0, r1, r2)
		self.fromFrameEpoch = fromFrameEpoch
		self.toFrameEpoch = toFrameEpoch
	}

	public static func == (lhs: Rotation, rhs: Rotation) -> Bool {
		lhs.storage.0 == rhs.storage.0 && lhs.storage.1 == rhs.storage.1 && lhs.storage.2 == rhs.storage.2
			&& lhs.fromFrameEpoch == rhs.fromFrameEpoch && lhs.toFrameEpoch == rhs.toFrameEpoch
	}

	public func hash(into hasher: inout Hasher) {
		hasher.combine(storage.0)
		hasher.combine(storage.1)
		hasher.combine(storage.2)
		hasher.combine(fromFrameEpoch)
		hasher.combine(toFrameEpoch)
	}
}

extension Rotation where From.Epoch == NoEpoch, To.Epoch == NoEpoch {
	/// Creates a rotation between frames without an epoch from the rows of an orthogonal
	/// matrix.
	///
	/// - Precondition: The matrix is orthogonal with determinant 1.
	init(uncheckedRows r0: Vector3, _ r1: Vector3, _ r2: Vector3) {
		self.init(uncheckedRows: r0, r1, r2, fromFrameEpoch: NoEpoch(), toFrameEpoch: NoEpoch())
	}

	/// The rotation that leaves coordinates unchanged, as between two frames with the same
	/// axes.
	public static var identity: Rotation {
		Rotation(uncheckedRows: Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1))
	}

	/// Returns R1(θ), a rotation of the axes by `angle` about the x axis.
	///
	/// Seen from the positive end of the x axis, the y and z axes turn counterclockwise by
	/// `angle`, so a fixed vector's coordinates turn clockwise.
	///
	/// - Parameter angle: The angle of rotation.
	/// - Returns: The rotation.
	public static func aboutX(_ angle: Angle) -> Rotation {
		let (s, c) = angle.sinCos
		return Rotation(uncheckedRows: Vector3(1, 0, 0), Vector3(0, c, s), Vector3(0, -s, c))
	}

	/// Returns R2(θ), a rotation of the axes by `angle` about the y axis.
	///
	/// Seen from the positive end of the y axis, the z and x axes turn counterclockwise by
	/// `angle`, so a fixed vector's coordinates turn clockwise.
	///
	/// - Parameter angle: The angle of rotation.
	/// - Returns: The rotation.
	public static func aboutY(_ angle: Angle) -> Rotation {
		let (s, c) = angle.sinCos
		return Rotation(uncheckedRows: Vector3(c, 0, -s), Vector3(0, 1, 0), Vector3(s, 0, c))
	}

	/// Returns R3(θ), a rotation of the axes by `angle` about the z axis.
	///
	/// Seen from the positive end of the z axis, the x and y axes turn counterclockwise by
	/// `angle`, so a fixed vector's coordinates turn clockwise.
	///
	/// - Parameter angle: The angle of rotation.
	/// - Returns: The rotation.
	public static func aboutZ(_ angle: Angle) -> Rotation {
		let (s, c) = angle.sinCos
		return Rotation(uncheckedRows: Vector3(c, s, 0), Vector3(-s, c, 0), Vector3(0, 0, 1))
	}
}

extension Rotation where From.Epoch == Instant<TT> {
	/// The epoch of the `From` frame of date, at which values must be to be rotated.
	public var fromEpoch: Instant<TT> {
		fromFrameEpoch
	}
}

extension Rotation where To.Epoch == Instant<TT> {
	/// The epoch of the `To` frame of date, at which rotated values are.
	public var toEpoch: Instant<TT> {
		toFrameEpoch
	}
}

extension Rotation {
	/// Returns a rotation with these rows between other frames, at their epochs.
	///
	/// Rotations of dated frames are built from elementary rotations between fixed frames,
	/// then given their frames and epochs with this.
	///
	/// - Parameters:
	///   - fromFrameEpoch: The epoch of the new `From` frame.
	///   - toFrameEpoch: The epoch of the new `To` frame.
	/// - Returns: The rotation with the same matrix.
	func relabeled<NewFrom: ReferenceFrame, NewTo: ReferenceFrame>(fromFrameEpoch: NewFrom.Epoch, toFrameEpoch: NewTo.Epoch) -> Rotation<NewFrom, NewTo> {
		Rotation<NewFrom, NewTo>(uncheckedRows: storage.0, storage.1, storage.2, fromFrameEpoch: fromFrameEpoch, toFrameEpoch: toFrameEpoch)
	}

	/// The rows of the rotation matrix.
	///
	/// The matrix times a column of `From` coordinates gives the `To` coordinates. With the
	/// `simd` module, `simd_double3x3(rows:)` builds the same matrix from these rows.
	public var rows: (SIMD3<Double>, SIMD3<Double>, SIMD3<Double>) {
		(storage.0.simd3, storage.1.simd3, storage.2.simd3)
	}

	/// Returns the coordinates of a vector in the `To` frame, given its coordinates in the
	/// `From` frame.
	func apply(to vector: Vector3) -> Vector3 {
		Vector3(storage.0.dot(vector), storage.1.dot(vector), storage.2.dot(vector))
	}

	/// Returns the coordinates of a vector in the `From` frame, given its coordinates in the
	/// `To` frame.
	func applyInverse(to vector: Vector3) -> Vector3 {
		storage.0 * vector.x + storage.1 * vector.y + storage.2 * vector.z
	}
}

extension Rotation {
	/// The rotation from the `To` frame back to the `From` frame.
	///
	/// The inverse of a rotation matrix is its transpose, so this is exact.
	public var inverse: Rotation<To, From> {
		Rotation<To, From>(
			uncheckedRows: Vector3(storage.0.x, storage.1.x, storage.2.x),
			Vector3(storage.0.y, storage.1.y, storage.2.y),
			Vector3(storage.0.z, storage.1.z, storage.2.z),
			fromFrameEpoch: toFrameEpoch,
			toFrameEpoch: fromFrameEpoch
		)
	}
}

extension Rotation where From.Epoch == NoEpoch {
	/// Returns the rotation that applies `rhs` and then `lhs`.
	///
	/// - Parameters:
	///   - lhs: The rotation applied second.
	///   - rhs: The rotation applied first.
	/// - Returns: The composed rotation.
	public static func * <Start: ReferenceFrame>(lhs: Rotation<From, To>, rhs: Rotation<Start, From>) -> Rotation<Start, To> {
		lhs.uncheckedComposed(after: rhs)
	}

	/// Returns a position's coordinates in the `To` frame.
	///
	/// - Parameters:
	///   - lhs: The rotation.
	///   - rhs: A position in the `From` frame.
	/// - Returns: The same position in the `To` frame.
	public static func * (lhs: Rotation, rhs: Position<From>) -> Position<To> {
		Position<To>(lhs.apply(to: rhs.vector), frameEpoch: lhs.toFrameEpoch)
	}
}

extension Rotation where From.Epoch == Instant<TT> {
	/// Returns the rotation that applies another rotation and then this one.
	///
	/// - Parameter other: The rotation applied first, to the `From` frame at this rotation's
	///   `From` epoch.
	/// - Returns: The composed rotation.
	/// - Throws: ``CoordinateError/epochMismatch`` if `other` gives values at another epoch.
	public func composed<Start: ReferenceFrame>(after other: Rotation<Start, From>) throws(CoordinateError) -> Rotation<Start, To> {
		try checkSameEpoch(fromEpoch, other.toEpoch)
		return uncheckedComposed(after: other)
	}

	/// Returns a position in the `From` frame of date expressed in the `To` frame.
	///
	/// - Parameter position: A position at the rotation's `From` epoch.
	/// - Returns: The same position in the `To` frame.
	/// - Throws: ``CoordinateError/epochMismatch`` if the position is at another epoch.
	public func apply(to position: Position<From>) throws(CoordinateError) -> Position<To> {
		try checkSameEpoch(fromEpoch, position.epoch)
		return Position<To>(apply(to: position.vector), frameEpoch: toFrameEpoch)
	}
}

extension Rotation {
	/// Returns the rotation that applies `other` and then this one, whatever their epochs.
	func uncheckedComposed<Start: ReferenceFrame>(after other: Rotation<Start, From>) -> Rotation<Start, To> {
		Rotation<Start, To>(
			uncheckedRows: other.applyInverse(to: storage.0),
			other.applyInverse(to: storage.1),
			other.applyInverse(to: storage.2),
			fromFrameEpoch: other.fromFrameEpoch,
			toFrameEpoch: toFrameEpoch
		)
	}
}
