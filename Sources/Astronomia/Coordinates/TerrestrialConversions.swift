//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

// Conversions between fixed and terrestrial frames. The terrestrial frames need the instant in
// both TT and UT1. A conversion at a TT instant finds UT1 from the Earth orientation, and one at
// an instant in another timescale converts it to each, so an instant already in UT1 keeps its
// value. Either throws a TimescaleConversionError if a conversion fails.

extension FixedReferenceFrame {
	/// Returns the rotation from this frame's axes to a terrestrial frame's axes at an
	/// instant.
	///
	/// To convert many positions at one instant, compute the rotation once and apply it with
	/// `*`.
	///
	/// - Parameters:
	///   - frame: The terrestrial frame to rotate to.
	///   - tt: The instant in TT.
	///   - ut1: The same instant in UT1.
	///   - earthOrientation: Observed Earth orientation to apply.
	/// - Returns: The rotation, composed through the ICRS.
	public static func rotation<Target: TerrestrialReferenceFrame>(to frame: Target.Type, at tt: Instant<TT>, ut1: Instant<UT1>, earthOrientation: EarthOrientation = .model) -> Rotation<Self, Target> {
		Target.rotationFromICRS(at: tt, ut1: ut1, earthOrientation: earthOrientation) * rotationFromICRS.inverse
	}
}

extension TerrestrialReferenceFrame {
	/// Returns the rotation from this frame's axes at an instant to a fixed frame's axes.
	///
	/// - Parameters:
	///   - tt: The instant in TT.
	///   - ut1: The same instant in UT1.
	///   - frame: The fixed frame to rotate to.
	///   - earthOrientation: Observed Earth orientation to apply.
	/// - Returns: The rotation, composed through the ICRS.
	public static func rotation<Target: FixedReferenceFrame>(at tt: Instant<TT>, ut1: Instant<UT1>, to frame: Target.Type, earthOrientation: EarthOrientation = .model) -> Rotation<Self, Target> {
		Target.rotationFromICRS * rotationFromICRS(at: tt, ut1: ut1, earthOrientation: earthOrientation).inverse
	}
}

extension Instant {
	/// Returns the instant in TT and in UT1, each converted from this instant.
	///
	/// - Parameters:
	///   - context: Observational data for converting from this instant's timescale.
	///   - earthOrientation: The source of UT1.
	func ttAndUT1(context: Scale.Context, earthOrientation: EarthOrientation) throws(TimescaleConversionError) -> (tt: Instant<TT>, ut1: Instant<UT1>) {
		let tt = try converted(to: TT.self, sourceContext: context)
		let ut1 = try converted(to: UT1.self, sourceContext: context, targetContext: earthOrientation.ut1)
		return (tt, ut1)
	}
}

extension Rotation {
	/// Returns a state rotated to the `To` frame, which turns with angular velocity `spin`
	/// relative to the `From` frame, whatever the state's epoch: v' = R v - ω × r'.
	func uncheckedApply(to state: StateVector<From>, toFrameTurningAt spin: SIMD3<Double>) -> StateVector<To> {
		let position = apply(to: state.position.vector)
		let velocity = apply(to: state.velocity.vector) - Vector3(spin.x, spin.y, spin.z).cross(position)
		return StateVector(uncheckedPosition: Position(position, frameEpoch: toFrameEpoch), velocity: Velocity(velocity, frameEpoch: toFrameEpoch))
	}

	/// Returns a state rotated to the `To` frame from the `From` frame, which turns with angular
	/// velocity `spin`, in its axes, relative to the `To` frame, whatever the state's epoch:
	/// v' = R (v + ω × r).
	func uncheckedApply(to state: StateVector<From>, fromFrameTurningAt spin: SIMD3<Double>) -> StateVector<To> {
		let inertial = state.velocity.vector + Vector3(spin.x, spin.y, spin.z).cross(state.position.vector)
		let position = Position<To>(apply(to: state.position.vector), frameEpoch: toFrameEpoch)
		return StateVector(uncheckedPosition: position, velocity: Velocity(apply(to: inertial), frameEpoch: toFrameEpoch))
	}
}

extension Position where Frame: FixedReferenceFrame {
	/// Returns the same position in a terrestrial frame at a TT instant.
	///
	/// - Parameters:
	///   - frame: The terrestrial frame to express the position in.
	///   - tt: The instant in TT.
	///   - earthOrientation: Observed Earth orientation to apply, and the source of UT1.
	/// - Returns: The position in `frame`.
	/// - Throws: A ``TimescaleConversionError`` if UT1 cannot be found.
	public func converted<Target: TerrestrialReferenceFrame>(to frame: Target.Type, at tt: Instant<TT>, earthOrientation: EarthOrientation = .model) throws(TimescaleConversionError) -> Position<Target> {
		let ut1 = try tt.converted(to: UT1.self, targetContext: earthOrientation.ut1)
		return Frame.rotation(to: frame, at: tt, ut1: ut1, earthOrientation: earthOrientation).uncheckedApply(to: self)
	}

	/// Returns the same position in a terrestrial frame at an instant in any timescale.
	///
	/// - Parameters:
	///   - frame: The terrestrial frame to express the position in.
	///   - instant: The instant, which is converted to TT and UT1.
	///   - context: Observational data for converting `instant`.
	///   - earthOrientation: Observed Earth orientation to apply, and the source of UT1.
	/// - Returns: The position in `frame`.
	/// - Throws: A ``TimescaleConversionError`` if TT or UT1 cannot be found.
	public func converted<Target: TerrestrialReferenceFrame, Scale: Timescale>(to frame: Target.Type, at instant: Instant<Scale>, context: Scale.Context = Scale.defaultContext, earthOrientation: EarthOrientation = .model) throws(TimescaleConversionError) -> Position<Target> {
		let (tt, ut1) = try instant.ttAndUT1(context: context, earthOrientation: earthOrientation)
		return Frame.rotation(to: frame, at: tt, ut1: ut1, earthOrientation: earthOrientation).uncheckedApply(to: self)
	}
}

extension Position where Frame: TerrestrialReferenceFrame, Frame.Epoch == NoEpoch {
	/// Returns the same position in a fixed frame, from a terrestrial frame at a TT instant.
	///
	/// - Parameters:
	///   - frame: The fixed frame to express the position in.
	///   - tt: The instant in TT.
	///   - earthOrientation: Observed Earth orientation to apply, and the source of UT1.
	/// - Returns: The position in `frame`.
	/// - Throws: A ``TimescaleConversionError`` if UT1 cannot be found.
	public func converted<Target: FixedReferenceFrame>(to frame: Target.Type, at tt: Instant<TT>, earthOrientation: EarthOrientation = .model) throws(TimescaleConversionError) -> Position<Target> {
		let ut1 = try tt.converted(to: UT1.self, targetContext: earthOrientation.ut1)
		return Frame.rotation(at: tt, ut1: ut1, to: frame, earthOrientation: earthOrientation) * self
	}

	/// Returns the same position in a fixed frame, from a terrestrial frame at an instant in
	/// any timescale.
	///
	/// - Parameters:
	///   - frame: The fixed frame to express the position in.
	///   - instant: The instant, which is converted to TT and UT1.
	///   - context: Observational data for converting `instant`.
	///   - earthOrientation: Observed Earth orientation to apply, and the source of UT1.
	/// - Returns: The position in `frame`.
	/// - Throws: A ``TimescaleConversionError`` if TT or UT1 cannot be found.
	public func converted<Target: FixedReferenceFrame, Scale: Timescale>(to frame: Target.Type, at instant: Instant<Scale>, context: Scale.Context = Scale.defaultContext, earthOrientation: EarthOrientation = .model) throws(TimescaleConversionError) -> Position<Target> {
		let (tt, ut1) = try instant.ttAndUT1(context: context, earthOrientation: earthOrientation)
		return Frame.rotation(at: tt, ut1: ut1, to: frame, earthOrientation: earthOrientation) * self
	}
}

extension Position where Frame: TerrestrialReferenceFrame, Frame.Epoch == Instant<TT> {
	/// Returns the same position in a fixed frame, from a terrestrial frame at its epoch.
	///
	/// - Parameters:
	///   - frame: The fixed frame to express the position in.
	///   - earthOrientation: Observed Earth orientation to apply, and the source of UT1.
	/// - Returns: The position in `frame`.
	/// - Throws: A ``TimescaleConversionError`` if UT1 cannot be found.
	public func converted<Target: FixedReferenceFrame>(to frame: Target.Type, earthOrientation: EarthOrientation = .model) throws(TimescaleConversionError) -> Position<Target> {
		let ut1 = try epoch.converted(to: UT1.self, targetContext: earthOrientation.ut1)
		return Frame.rotation(at: epoch, ut1: ut1, to: frame, earthOrientation: earthOrientation).uncheckedApply(to: self)
	}
}

extension StateVector where Frame: FixedReferenceFrame {
	/// Returns the same state in a terrestrial frame at a TT instant, with the velocity
	/// relative to the turning frame.
	///
	/// - Parameters:
	///   - frame: The terrestrial frame to express the state in.
	///   - tt: The instant in TT.
	///   - earthOrientation: Observed Earth orientation to apply, and the source of UT1.
	/// - Returns: The state in `frame`.
	/// - Throws: A ``TimescaleConversionError`` if UT1 cannot be found.
	public func converted<Target: TerrestrialReferenceFrame>(to frame: Target.Type, at tt: Instant<TT>, earthOrientation: EarthOrientation = .model) throws(TimescaleConversionError) -> StateVector<Target> {
		let ut1 = try tt.converted(to: UT1.self, targetContext: earthOrientation.ut1)
		return converted(to: frame, at: tt, ut1: ut1, earthOrientation: earthOrientation)
	}

	/// Returns the same state in a terrestrial frame at an instant in any timescale, with the
	/// velocity relative to the turning frame.
	///
	/// - Parameters:
	///   - frame: The terrestrial frame to express the state in.
	///   - instant: The instant, which is converted to TT and UT1.
	///   - context: Observational data for converting `instant`.
	///   - earthOrientation: Observed Earth orientation to apply, and the source of UT1.
	/// - Returns: The state in `frame`.
	/// - Throws: A ``TimescaleConversionError`` if TT or UT1 cannot be found.
	public func converted<Target: TerrestrialReferenceFrame, Scale: Timescale>(to frame: Target.Type, at instant: Instant<Scale>, context: Scale.Context = Scale.defaultContext, earthOrientation: EarthOrientation = .model) throws(TimescaleConversionError) -> StateVector<Target> {
		let (tt, ut1) = try instant.ttAndUT1(context: context, earthOrientation: earthOrientation)
		return converted(to: frame, at: tt, ut1: ut1, earthOrientation: earthOrientation)
	}

	/// Returns the state in a terrestrial frame at an instant in TT and UT1.
	func converted<Target: TerrestrialReferenceFrame>(to frame: Target.Type, at tt: Instant<TT>, ut1: Instant<UT1>, earthOrientation: EarthOrientation) -> StateVector<Target> {
		let rotation = Frame.rotation(to: frame, at: tt, ut1: ut1, earthOrientation: earthOrientation)
		return rotation.uncheckedApply(to: self, toFrameTurningAt: Target.angularVelocity(at: tt, earthOrientation: earthOrientation))
	}
}

extension StateVector where Frame: TerrestrialReferenceFrame {
	/// Returns the state in a fixed frame at an instant in TT and UT1.
	func converted<Target: FixedReferenceFrame>(to frame: Target.Type, at tt: Instant<TT>, ut1: Instant<UT1>, earthOrientation: EarthOrientation) -> StateVector<Target> {
		let rotation = Frame.rotation(at: tt, ut1: ut1, to: frame, earthOrientation: earthOrientation)
		return rotation.uncheckedApply(to: self, fromFrameTurningAt: Frame.angularVelocity(at: tt, earthOrientation: earthOrientation))
	}
}

extension StateVector where Frame: TerrestrialReferenceFrame, Frame.Epoch == NoEpoch {
	/// Returns the same state in a fixed frame, from a terrestrial frame at a TT instant, with
	/// the frame's rotation added to the velocity.
	///
	/// - Parameters:
	///   - frame: The fixed frame to express the state in.
	///   - tt: The instant in TT.
	///   - earthOrientation: Observed Earth orientation to apply, and the source of UT1.
	/// - Returns: The state in `frame`.
	/// - Throws: A ``TimescaleConversionError`` if UT1 cannot be found.
	public func converted<Target: FixedReferenceFrame>(to frame: Target.Type, at tt: Instant<TT>, earthOrientation: EarthOrientation = .model) throws(TimescaleConversionError) -> StateVector<Target> {
		let ut1 = try tt.converted(to: UT1.self, targetContext: earthOrientation.ut1)
		return converted(to: frame, at: tt, ut1: ut1, earthOrientation: earthOrientation)
	}

	/// Returns the same state in a fixed frame, from a terrestrial frame at an instant in any
	/// timescale, with the frame's rotation added to the velocity.
	///
	/// - Parameters:
	///   - frame: The fixed frame to express the state in.
	///   - instant: The instant, which is converted to TT and UT1.
	///   - context: Observational data for converting `instant`.
	///   - earthOrientation: Observed Earth orientation to apply, and the source of UT1.
	/// - Returns: The state in `frame`.
	/// - Throws: A ``TimescaleConversionError`` if TT or UT1 cannot be found.
	public func converted<Target: FixedReferenceFrame, Scale: Timescale>(to frame: Target.Type, at instant: Instant<Scale>, context: Scale.Context = Scale.defaultContext, earthOrientation: EarthOrientation = .model) throws(TimescaleConversionError) -> StateVector<Target> {
		let (tt, ut1) = try instant.ttAndUT1(context: context, earthOrientation: earthOrientation)
		return converted(to: frame, at: tt, ut1: ut1, earthOrientation: earthOrientation)
	}
}

extension StateVector where Frame: TerrestrialReferenceFrame, Frame.Epoch == Instant<TT> {
	/// Returns the same state in a fixed frame, from a terrestrial frame at its epoch, with the
	/// frame's rotation added to the velocity.
	///
	/// - Parameters:
	///   - frame: The fixed frame to express the state in.
	///   - earthOrientation: Observed Earth orientation to apply, and the source of UT1.
	/// - Returns: The state in `frame`.
	/// - Throws: A ``TimescaleConversionError`` if UT1 cannot be found.
	public func converted<Target: FixedReferenceFrame>(to frame: Target.Type, earthOrientation: EarthOrientation = .model) throws(TimescaleConversionError) -> StateVector<Target> {
		let ut1 = try epoch.converted(to: UT1.self, targetContext: earthOrientation.ut1)
		return converted(to: frame, at: epoch, ut1: ut1, earthOrientation: earthOrientation)
	}
}
