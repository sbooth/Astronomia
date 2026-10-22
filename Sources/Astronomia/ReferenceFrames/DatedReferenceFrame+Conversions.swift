//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

// Conversions to and from frames of date. Each recomputes the frame's rotation, which for the
// frames with nutation takes about 0.1 ms; to convert many values at one epoch, compute the
// rotation once, as with `ICRS.rotation(to:at:earthOrientation:)`, and apply it with `*`.

extension Rotation {
	/// Returns a position rotated to the `To` frame, without checking its epoch.
	///
	/// - Precondition: The position is at the rotation's `From` epoch, as when the rotation is
	///   made at the position's own epoch, or the `From` frame has no epoch.
	func uncheckedApply(to position: Position<From>) -> Position<To> {
		assert(position.frameEpoch == fromFrameEpoch, "Position is not at the rotation's From epoch")
		return Position<To>(apply(to: position.vector), frameEpoch: toFrameEpoch)
	}

	/// Returns a velocity rotated to the `To` frame, without checking its epoch.
	///
	/// - Precondition: The velocity is at the rotation's `From` epoch, or the `From` frame has
	///   no epoch.
	func uncheckedApply(to velocity: Velocity<From>) -> Velocity<To> {
		assert(velocity.frameEpoch == fromFrameEpoch, "Velocity is not at the rotation's From epoch")
		return Velocity<To>(apply(to: velocity.vector), frameEpoch: toFrameEpoch)
	}

	/// Returns a state rotated to the `To` frame, without checking its epoch.
	///
	/// - Precondition: The state is at the rotation's `From` epoch, or the `From` frame has no
	///   epoch.
	func uncheckedApply(to state: StateVector<From>) -> StateVector<To> {
		assert(state.position.frameEpoch == fromFrameEpoch, "State vector's position is not at the rotation's From epoch")
		return StateVector<To>(uncheckedPosition: uncheckedApply(to: state.position), velocity: uncheckedApply(to: state.velocity))
	}
}

extension Position where Frame: FixedReferenceFrame {
	/// Returns the same position in a frame of date.
	///
	/// - Parameters:
	///   - frame: The frame of date to express the position in.
	///   - epoch: The epoch of `frame`.
	///   - earthOrientation: Observed Earth orientation to apply.
	/// - Returns: The position in `frame` at `epoch`.
	public func converted<Target: DatedReferenceFrame>(to frame: Target.Type, at epoch: Instant<TT>, earthOrientation: EarthOrientation = .model) -> Position<Target> {
		Frame.rotation(to: frame, at: epoch, earthOrientation: earthOrientation).uncheckedApply(to: self)
	}

	/// Returns the same position in a frame of date, at an epoch in any timescale.
	///
	/// - Parameters:
	///   - frame: The frame of date to express the position in.
	///   - epoch: The epoch of `frame`, which is converted to TT.
	///   - context: Observational data for converting `epoch` to TT.
	///   - earthOrientation: Observed Earth orientation to apply.
	/// - Returns: The position in `frame` at `epoch`.
	/// - Throws: A ``TimescaleConversionError`` if `epoch` can't be converted to TT.
	public func converted<Target: DatedReferenceFrame, Scale: Timescale>(to frame: Target.Type, at epoch: Instant<Scale>, context: Scale.Context = Scale.defaultContext, earthOrientation: EarthOrientation = .model) throws(TimescaleConversionError) -> Position<Target> {
		let tt = try epoch.converted(to: TT.self, sourceContext: context)
		return converted(to: frame, at: tt, earthOrientation: earthOrientation)
	}
}

extension Position where Frame: DatedReferenceFrame {
	/// Returns the same position in a fixed frame.
	///
	/// - Parameters:
	///   - frame: The fixed frame to express the position in.
	///   - earthOrientation: Observed Earth orientation to apply, which should be that the
	///     position was converted to this frame with.
	/// - Returns: The position in `frame`.
	public func converted<Target: FixedReferenceFrame>(to frame: Target.Type, earthOrientation: EarthOrientation = .model) -> Position<Target> {
		Frame.rotation(from: epoch, to: frame, earthOrientation: earthOrientation).uncheckedApply(to: self)
	}

	/// Returns the same position in a frame of date at another, or the same, epoch.
	///
	/// - Parameters:
	///   - frame: The frame of date to express the position in.
	///   - targetEpoch: The epoch of `frame`.
	///   - earthOrientation: Observed Earth orientation to apply.
	/// - Returns: The position in `frame` at `targetEpoch`.
	public func converted<Target: DatedReferenceFrame>(to frame: Target.Type, at targetEpoch: Instant<TT>, earthOrientation: EarthOrientation = .model) -> Position<Target> {
		Frame.rotation(from: epoch, to: frame, at: targetEpoch, earthOrientation: earthOrientation).uncheckedApply(to: self)
	}

	/// Returns the same position in a frame of date at another, or the same, epoch in any
	/// timescale.
	///
	/// - Parameters:
	///   - frame: The frame of date to express the position in.
	///   - targetEpoch: The epoch of `frame`, which is converted to TT.
	///   - context: Observational data for converting `targetEpoch` to TT.
	///   - earthOrientation: Observed Earth orientation to apply.
	/// - Returns: The position in `frame` at `targetEpoch`.
	/// - Throws: A ``TimescaleConversionError`` if `targetEpoch` can't be converted to TT.
	public func converted<Target: DatedReferenceFrame, Scale: Timescale>(to frame: Target.Type, at targetEpoch: Instant<Scale>, context: Scale.Context = Scale.defaultContext, earthOrientation: EarthOrientation = .model) throws(TimescaleConversionError) -> Position<Target> {
		let tt = try targetEpoch.converted(to: TT.self, sourceContext: context)
		return converted(to: frame, at: tt, earthOrientation: earthOrientation)
	}
}

extension Velocity where Frame: FixedReferenceFrame {
	/// Returns the same velocity in a frame of date.
	///
	/// - Parameters:
	///   - frame: The frame of date to express the velocity in.
	///   - epoch: The epoch of `frame`.
	///   - earthOrientation: Observed Earth orientation to apply.
	/// - Returns: The velocity in `frame` at `epoch`.
	public func converted<Target: DatedReferenceFrame>(to frame: Target.Type, at epoch: Instant<TT>, earthOrientation: EarthOrientation = .model) -> Velocity<Target> {
		Frame.rotation(to: frame, at: epoch, earthOrientation: earthOrientation).uncheckedApply(to: self)
	}

	/// Returns the same velocity in a frame of date, at an epoch in any timescale.
	///
	/// - Parameters:
	///   - frame: The frame of date to express the velocity in.
	///   - epoch: The epoch of `frame`, which is converted to TT.
	///   - context: Observational data for converting `epoch` to TT.
	///   - earthOrientation: Observed Earth orientation to apply.
	/// - Returns: The velocity in `frame` at `epoch`.
	/// - Throws: A ``TimescaleConversionError`` if `epoch` can't be converted to TT.
	public func converted<Target: DatedReferenceFrame, Scale: Timescale>(to frame: Target.Type, at epoch: Instant<Scale>, context: Scale.Context = Scale.defaultContext, earthOrientation: EarthOrientation = .model) throws(TimescaleConversionError) -> Velocity<Target> {
		let tt = try epoch.converted(to: TT.self, sourceContext: context)
		return converted(to: frame, at: tt, earthOrientation: earthOrientation)
	}
}

extension Velocity where Frame: DatedReferenceFrame {
	/// Returns the same velocity in a fixed frame.
	///
	/// - Parameters:
	///   - frame: The fixed frame to express the velocity in.
	///   - earthOrientation: Observed Earth orientation to apply, which should be that the
	///     velocity was converted to this frame with.
	/// - Returns: The velocity in `frame`.
	public func converted<Target: FixedReferenceFrame>(to frame: Target.Type, earthOrientation: EarthOrientation = .model) -> Velocity<Target> {
		Frame.rotation(from: epoch, to: frame, earthOrientation: earthOrientation).uncheckedApply(to: self)
	}

	/// Returns the same velocity in a frame of date at another, or the same, epoch.
	///
	/// - Parameters:
	///   - frame: The frame of date to express the velocity in.
	///   - targetEpoch: The epoch of `frame`.
	///   - earthOrientation: Observed Earth orientation to apply.
	/// - Returns: The velocity in `frame` at `targetEpoch`.
	public func converted<Target: DatedReferenceFrame>(to frame: Target.Type, at targetEpoch: Instant<TT>, earthOrientation: EarthOrientation = .model) -> Velocity<Target> {
		Frame.rotation(from: epoch, to: frame, at: targetEpoch, earthOrientation: earthOrientation).uncheckedApply(to: self)
	}

	/// Returns the same velocity in a frame of date at another, or the same, epoch in any
	/// timescale.
	///
	/// - Parameters:
	///   - frame: The frame of date to express the velocity in.
	///   - targetEpoch: The epoch of `frame`, which is converted to TT.
	///   - context: Observational data for converting `targetEpoch` to TT.
	///   - earthOrientation: Observed Earth orientation to apply.
	/// - Returns: The velocity in `frame` at `targetEpoch`.
	/// - Throws: A ``TimescaleConversionError`` if `targetEpoch` can't be converted to TT.
	public func converted<Target: DatedReferenceFrame, Scale: Timescale>(to frame: Target.Type, at targetEpoch: Instant<Scale>, context: Scale.Context = Scale.defaultContext, earthOrientation: EarthOrientation = .model) throws(TimescaleConversionError) -> Velocity<Target> {
		let tt = try targetEpoch.converted(to: TT.self, sourceContext: context)
		return converted(to: frame, at: tt, earthOrientation: earthOrientation)
	}
}

extension StateVector where Frame: FixedReferenceFrame {
	/// Returns the same state in a frame of date.
	///
	/// - Parameters:
	///   - frame: The frame of date to express the state in.
	///   - epoch: The epoch of `frame`.
	///   - earthOrientation: Observed Earth orientation to apply.
	/// - Returns: The state in `frame` at `epoch`.
	public func converted<Target: DatedReferenceFrame>(to frame: Target.Type, at epoch: Instant<TT>, earthOrientation: EarthOrientation = .model) -> StateVector<Target> {
		Frame.rotation(to: frame, at: epoch, earthOrientation: earthOrientation).uncheckedApply(to: self)
	}

	/// Returns the same state in a frame of date, at an epoch in any timescale.
	///
	/// - Parameters:
	///   - frame: The frame of date to express the state in.
	///   - epoch: The epoch of `frame`, which is converted to TT.
	///   - context: Observational data for converting `epoch` to TT.
	///   - earthOrientation: Observed Earth orientation to apply.
	/// - Returns: The state in `frame` at `epoch`.
	/// - Throws: A ``TimescaleConversionError`` if `epoch` can't be converted to TT.
	public func converted<Target: DatedReferenceFrame, Scale: Timescale>(to frame: Target.Type, at epoch: Instant<Scale>, context: Scale.Context = Scale.defaultContext, earthOrientation: EarthOrientation = .model) throws(TimescaleConversionError) -> StateVector<Target> {
		let tt = try epoch.converted(to: TT.self, sourceContext: context)
		return converted(to: frame, at: tt, earthOrientation: earthOrientation)
	}
}

extension StateVector where Frame: DatedReferenceFrame {
	/// Returns the same state in a fixed frame.
	///
	/// - Parameters:
	///   - frame: The fixed frame to express the state in.
	///   - earthOrientation: Observed Earth orientation to apply, which should be that the
	///     state was converted to this frame with.
	/// - Returns: The state in `frame`.
	public func converted<Target: FixedReferenceFrame>(to frame: Target.Type, earthOrientation: EarthOrientation = .model) -> StateVector<Target> {
		Frame.rotation(from: epoch, to: frame, earthOrientation: earthOrientation).uncheckedApply(to: self)
	}

	/// Returns the same state in a frame of date at another, or the same, epoch.
	///
	/// - Parameters:
	///   - frame: The frame of date to express the state in.
	///   - targetEpoch: The epoch of `frame`.
	///   - earthOrientation: Observed Earth orientation to apply.
	/// - Returns: The state in `frame` at `targetEpoch`.
	public func converted<Target: DatedReferenceFrame>(to frame: Target.Type, at targetEpoch: Instant<TT>, earthOrientation: EarthOrientation = .model) -> StateVector<Target> {
		Frame.rotation(from: epoch, to: frame, at: targetEpoch, earthOrientation: earthOrientation).uncheckedApply(to: self)
	}

	/// Returns the same state in a frame of date at another, or the same, epoch in any
	/// timescale.
	///
	/// - Parameters:
	///   - frame: The frame of date to express the state in.
	///   - targetEpoch: The epoch of `frame`, which is converted to TT.
	///   - context: Observational data for converting `targetEpoch` to TT.
	///   - earthOrientation: Observed Earth orientation to apply.
	/// - Returns: The state in `frame` at `targetEpoch`.
	/// - Throws: A ``TimescaleConversionError`` if `targetEpoch` can't be converted to TT.
	public func converted<Target: DatedReferenceFrame, Scale: Timescale>(to frame: Target.Type, at targetEpoch: Instant<Scale>, context: Scale.Context = Scale.defaultContext, earthOrientation: EarthOrientation = .model) throws(TimescaleConversionError) -> StateVector<Target> {
		let tt = try targetEpoch.converted(to: TT.self, sourceContext: context)
		return converted(to: frame, at: tt, earthOrientation: earthOrientation)
	}
}
