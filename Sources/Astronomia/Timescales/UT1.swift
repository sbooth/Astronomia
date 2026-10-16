//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// Universal Time (UT1).
///
/// UT1 is the angle of Earth's rotation expressed as a time. It is not defined by a formula:
/// it follows Earth's irregular rotation and is determined by observation. It relates to TT
/// through ΔT = TT - UT1, about 69 s in 2026 and growing irregularly.
///
/// ΔT comes from the context's ``DeltaTSource``. By default that is the first of Earth
/// orientation data, if supplied, ``DeltaTTable/builtIn``, and
/// ``DeltaTModel/espenakMeeus2006`` that covers the date. The most recent observations are
/// continued along their trend over the last year for ``Context/defaultTrendYears`` Julian
/// years; otherwise ΔT is a published value.
///
/// Where one source hands over to the next, ΔT can be discontinuous: by default by 3.7 s at
/// 1657.0, and by several seconds where the trend ends and the model begins. Where ΔT steps
/// up, UT1 instants within the step have no exact TT, and where it steps down they have two,
/// so ``toTT(_:context:)`` and ``fromTT(_:context:)`` are not exact inverses within a step's
/// width of a handover. Use ``Context/continuous(earthOrientation:deltaTTable:model:)`` to
/// join the sources continuously instead.
public enum UT1: Timescale {
	public static let abbreviation = "UT1"

	/// No Earth orientation data; ΔT from ``DeltaTTable/builtIn`` from 1657.0, continued along
	/// its trend for ``Context/defaultTrendYears`` Julian years, and from
	/// ``DeltaTModel/espenakMeeus2006`` elsewhere.
	public static let defaultContext = Context()

	public static func toTT(_ julianDate: JulianDate, context: Context) throws(TimescaleConversionError) -> JulianDate {
		// TT = UT1 + ΔT(TT). Each evaluation shrinks the error by a factor of dΔT/dt,
		// at most about 2 × 10^-6 even for the model in antiquity, so four suffice.
		var tt = julianDate
		for _ in 0 ..< 4 {
			let deltaT = try deltaT(at: tt, context: context)
			do throws(JulianDateError) {
				tt = try julianDate.adding(seconds: deltaT)
			}
			catch { throw TimescaleConversionError(error) }
		}
		return tt
	}

	public static func fromTT(_ julianDate: JulianDate, context: Context) throws(TimescaleConversionError) -> JulianDate {
		// UT1 = TT - ΔT(TT)
		let deltaT = try deltaT(at: julianDate, context: context)
		do throws(JulianDateError) {
			return try julianDate.adding(seconds: -deltaT)
		}
		catch { throw TimescaleConversionError(error) }
	}
}

extension UT1 {
	/// The source of ΔT.
	public struct Context: Sendable {
		/// The source of ΔT.
		public var deltaT: any DeltaTSource

		/// Creates a UT1 context with the specified source of ΔT.
		///
		/// - Parameter deltaT: The source of ΔT.
		public init(deltaT: any DeltaTSource) {
			self.deltaT = deltaT
		}

		/// The number of Julian years for which the default context continues the most recent
		/// observations along their trend.
		///
		/// Over the observations since 1973, continuing the trend over the last year was
		/// typically within 0.05 s a year later and 0.13 s two years later, and at worst 0.3 s
		/// and 0.6 s. Holding the last value, or following the model, did worse at both.
		public static let defaultTrendYears: Double = 2

		/// Creates a UT1 context that takes ΔT from the first of Earth orientation data, a ΔT
		/// table, and a model that covers the date.
		///
		/// Whichever of `earthOrientation` and `deltaTTable` ends later is continued along its
		/// trend over the last year for `trendYears` Julian years. Every other value comes
		/// unchanged from one source, so ΔT can be discontinuous where one source hands over to
		/// the next, including where the trend ends.
		///
		/// To use other tables for different eras, combine their entries into one table, or
		/// pass a ``DeltaTSourceList`` to ``init(deltaT:)``.
		///
		/// - Parameters:
		///   - earthOrientation: Observed and predicted Earth orientation.
		///   - deltaTTable: Tabulated ΔT, used outside `earthOrientation`.
		///   - model: The model used outside the data, or `nil` to require data.
		///   - trendYears: The number of Julian years to continue the most recent
		///     observations, or `nil` to use only published values.
		public init(
			earthOrientation: EarthOrientationTable? = nil,
			deltaTTable: DeltaTTable? = .builtIn,
			model: DeltaTModel? = .espenakMeeus2006,
			trendYears: Double? = defaultTrendYears
		) {
			let latest = Self.latestObservations(earthOrientation, deltaTTable)
			func trend(_ source: some BoundedDeltaTSource, isLatest: Bool) -> any DeltaTSource {
				guard isLatest, let trendYears else { return source }
				return DeltaTExtrapolation(source, after: .linear(), limit: trendYears)
			}

			var sources: [any DeltaTSource] = []
			if let earthOrientation { sources.append(trend(earthOrientation, isLatest: latest == .earthOrientation)) }
			if let deltaTTable { sources.append(trend(deltaTTable, isLatest: latest == .deltaTTable)) }
			if let model { sources.append(model) }
			self.init(deltaT: DeltaTSourceList(sources))
		}

		/// Returns a UT1 context that takes ΔT from Earth orientation data and a ΔT table, with
		/// a model offset to join them continuously.
		///
		/// ΔT comes from `earthOrientation`, then `deltaTTable`, within their ranges. After the
		/// end of whichever ends later, and before the start of `deltaTTable`, ΔT follows
		/// `model` offset to join the data continuously. ΔT can still step where
		/// `earthOrientation` hands over to `deltaTTable`, by milliseconds between the
		/// observations.
		///
		/// The joined values are not published values: before 1657.0, for example, ΔT is the
		/// model's plus about 3.7 s.
		///
		/// - Parameters:
		///   - earthOrientation: Observed and predicted Earth orientation.
		///   - deltaTTable: Tabulated ΔT.
		///   - model: The model used outside the data, or `nil` to require data.
		public static func continuous(
			earthOrientation: EarthOrientationTable? = nil,
			deltaTTable: DeltaTTable? = .builtIn,
			model: DeltaTModel? = .espenakMeeus2006
		) -> Context {
			let join = model.map { DeltaTExtrapolation.Method.following($0) }
			let latest = Self.latestObservations(earthOrientation, deltaTTable)
			var sources: [any DeltaTSource] = []
			if let earthOrientation {
				sources.append(DeltaTExtrapolation(earthOrientation, after: latest == .earthOrientation ? join : nil))
			}
			if let deltaTTable {
				sources.append(DeltaTExtrapolation(deltaTTable, before: join, after: latest == .deltaTTable ? join : nil))
			}
			if let model {
				sources.append(model)
			}
			return Context(deltaT: DeltaTSourceList(sources))
		}

		/// The source of the most recent observations.
		private enum LatestObservations {
			case earthOrientation
			case deltaTTable
		}

		/// Returns which of the sources ends later, preferring Earth orientation data on a tie.
		private static func latestObservations(_ earthOrientation: EarthOrientationTable?, _ deltaTTable: DeltaTTable?) -> LatestObservations? {
			switch (earthOrientation, deltaTTable) {
			case let (earthOrientation?, deltaTTable?):
				earthOrientation.coverage.upperBound >= deltaTTable.coverage.upperBound ? .earthOrientation : .deltaTTable
			case (_?, nil):
				.earthOrientation
			case (nil, _?):
				.deltaTTable
			case (nil, nil):
				nil
			}
		}
	}
}

extension UT1 {
	/// Returns ΔT = TT - UT1, in seconds, at the specified TT.
	///
	/// - Parameters:
	///   - tt: A Julian Date in TT.
	///   - context: The source of ΔT.
	/// - Returns: ΔT, in seconds.
	/// - Throws:
	///   - ``TimescaleConversionError/deltaTUnavailable`` if the context's source
	///     does not cover `tt`.
	///   - ``TimescaleConversionError/nonFiniteValue`` if the source returns NaN or infinity.
	public static func deltaT(at tt: JulianDate, context: Context) throws(TimescaleConversionError) -> Double {
		guard let deltaT = context.deltaT.deltaT(at: tt) else { throw .deltaTUnavailable }
		guard deltaT.isFinite else { throw .nonFiniteValue }
		return deltaT
	}
}
