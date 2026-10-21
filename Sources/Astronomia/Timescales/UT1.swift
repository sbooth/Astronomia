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
/// UT1 is also the timescale for civil and astronomical times before UTC began in 1961.
/// Historical times given as UT or GMT are UT1 to within the precision of the records.
///
/// ΔT comes from the context's ``DeltaTSource``. By default that is the first of Earth
/// orientation data, if supplied, ``DeltaTTable/builtIn``, and
/// ``DeltaTModel/stephensonMorrisonHohenkerk2016`` that covers the date. The most recent
/// observations are continued along their trend over the last year for
/// ``Context/defaultTrendYears`` Julian years; otherwise ΔT is a published value.
///
/// Where one source hands over to the next, ΔT can be discontinuous: by default by about
/// 6.5 s at 1657.0, and by about 12 s where the trend ends and the model begins. Where ΔT
/// steps up, UT1 instants within the step have no exact TT, and where it steps down they have two,
/// so ``toTT(_:context:)`` and ``fromTT(_:context:)`` are not exact inverses within a step's
/// width of a handover. Use ``Context/continuous(earthOrientationTable:deltaTTable:model:)`` to
/// join the sources continuously instead. In either context, the default model itself steps
/// by about 44 s at -720, where its spline hands over to its long-term parabola as published.
public enum UT1: Timescale {
	public static let abbreviation = "UT1"

	/// No Earth orientation data; ΔT from ``DeltaTTable/builtIn`` from 1657.0, continued along
	/// its trend for ``Context/defaultTrendYears`` Julian years, and from
	/// ``DeltaTModel/stephensonMorrisonHohenkerk2016`` elsewhere.
	public static let defaultContext = Context()

	public static func toTT(_ julianDate: JulianDate, context: Context) throws(TimescaleConversionError) -> JulianDate {
		// TT = UT1 + ΔT(TT), with the TT found by the source
		guard let deltaT = context.deltaT.deltaT(atUT1: julianDate) else { throw .deltaTUnavailable }
		guard deltaT.isFinite else { throw .nonFiniteValue }
		do throws(JulianDateError) {
			return try julianDate.adding(seconds: deltaT)
		}
		catch { throw TimescaleConversionError(error) }
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
		/// Whichever of `earthOrientationTable` and `deltaTTable` ends later is continued along its
		/// trend over the last year for ``defaultTrendYears`` Julian years. Every other value
		/// comes unchanged from one source, so ΔT can be discontinuous where one source hands
		/// over to the next, including where the trend ends.
		///
		/// To use other tables for different eras, combine their entries into one table, or
		/// pass a ``DeltaTSourceList`` to ``init(deltaT:)``.
		///
		/// - Parameters:
		///   - earthOrientationTable: Observed and predicted Earth orientation.
		///   - deltaTTable: Tabulated ΔT, used outside `earthOrientationTable`.
		///   - model: The model used outside the data, or `nil` to require data.
		public init(
			earthOrientationTable: EarthOrientationTable? = nil,
			deltaTTable: DeltaTTable? = .builtIn,
			model: DeltaTModel? = .stephensonMorrisonHohenkerk2016
		) {
			self.init(uncheckedEarthOrientationTable: earthOrientationTable, deltaTTable: deltaTTable, model: model, trendYears: Self.defaultTrendYears)
		}

		/// Creates a UT1 context like ``init(earthOrientationTable:deltaTTable:model:)``,
		/// continuing the most recent observations along their trend for `trendYears` Julian
		/// years.
		///
		/// - Parameters:
		///   - earthOrientationTable: Observed and predicted Earth orientation.
		///   - deltaTTable: Tabulated ΔT, used outside `earthOrientationTable`.
		///   - model: The model used outside the data, or `nil` to require data.
		///   - trendYears: The number of Julian years to continue the most recent
		///     observations, or `nil` to use only published values.
		/// - Throws: ``TimescaleConversionError/invalidExtrapolationLimit`` if `trendYears` is
		///   not finite and nonnegative.
		public init(
			earthOrientationTable: EarthOrientationTable? = nil,
			deltaTTable: DeltaTTable? = .builtIn,
			model: DeltaTModel? = .stephensonMorrisonHohenkerk2016,
			trendYears: Double?
		) throws(TimescaleConversionError) {
			if let trendYears {
				guard trendYears.isFinite, trendYears >= 0 else { throw .invalidExtrapolationLimit }
			}
			self.init(uncheckedEarthOrientationTable: earthOrientationTable, deltaTTable: deltaTTable, model: model, trendYears: trendYears)
		}

		/// Creates a UT1 context with a trend length already known to be valid.
		///
		/// - Precondition: `trendYears` satisfies the requirements of
		///   ``init(earthOrientationTable:deltaTTable:model:trendYears:)``.
		init(
			uncheckedEarthOrientationTable earthOrientationTable: EarthOrientationTable?,
			deltaTTable: DeltaTTable?,
			model: DeltaTModel?,
			trendYears: Double?
		) {
			let latest = Self.latestObservations(earthOrientationTable, deltaTTable)
			var sources: [any DeltaTSource] = []
			/// Appends `source`, followed by its trend if it has the most recent observations.
			func append(_ source: some DeltaTSource, isLatest: Bool) {
				sources.append(source)
				guard isLatest, let trendYears else { return }
				// A limit too far to represent leaves the trend unlimited.
				let end = source.coverage.upperBound
				let limit = (try? end.adding(days: trendYears * daysPerJulianYear)) ?? .max
				// A valid table gives a finite ΔT throughout, so the trend can always be made.
				if let trend = try? LinearDeltaTExtrapolation(after: source, through: limit) {
					sources.append(trend)
				}
			}

			if let earthOrientationTable { append(earthOrientationTable, isLatest: latest == .earthOrientationTable) }
			if let deltaTTable { append(deltaTTable, isLatest: latest == .deltaTTable) }
			if let model { sources.append(model) }
			self.init(deltaT: DeltaTSourceList(sources))
		}

		/// Returns a UT1 context that takes ΔT from Earth orientation data and a ΔT table, with
		/// a model offset to join them continuously.
		///
		/// ΔT comes from `earthOrientationTable`, then `deltaTTable`, within their ranges.
		/// Before the start of whichever starts earlier, and after the end of whichever ends
		/// later, ΔT follows `model` offset to join the data continuously. ΔT can still step
		/// where `earthOrientationTable` hands over to `deltaTTable`, by milliseconds between
		/// the observations.
		///
		/// The joined values are not published values: before 1657.0, for example, ΔT is the
		/// model's plus about 6.5 s.
		///
		/// - Parameters:
		///   - earthOrientationTable: Observed and predicted Earth orientation.
		///   - deltaTTable: Tabulated ΔT.
		///   - model: The model used outside the data, or `nil` to require data.
		public static func continuous(
			earthOrientationTable: EarthOrientationTable? = nil,
			deltaTTable: DeltaTTable? = .builtIn,
			model: DeltaTModel? = .stephensonMorrisonHohenkerk2016
		) -> Context {
			let earliest = Self.earliestObservations(earthOrientationTable, deltaTTable)
			let latest = Self.latestObservations(earthOrientationTable, deltaTTable)
			var sources: [any DeltaTSource] = []
			/// Appends `source`, followed by `model` joined before its start if it starts earliest
			/// and after its end if it ends latest.
			func append(_ source: some DeltaTSource, _ observations: Observations) {
				sources.append(source)
				guard let model else { return }
				// The models cover every date, and a valid table gives a finite ΔT at its ends,
				// so the joins can always be made.
				if earliest == observations, let join = try? JoinedDeltaTSource(model, before: source) {
					sources.append(join)
				}
				if latest == observations, let join = try? JoinedDeltaTSource(model, after: source) {
					sources.append(join)
				}
			}

			if let earthOrientationTable { append(earthOrientationTable, .earthOrientationTable) }
			if let deltaTTable { append(deltaTTable, .deltaTTable) }
			if let model {
				sources.append(model)
			}
			return Context(deltaT: DeltaTSourceList(sources))
		}

		/// A source of observations.
		private enum Observations {
			case earthOrientationTable
			case deltaTTable
		}

		/// Returns which of the sources starts earlier, preferring Earth orientation data on a
		/// tie.
		private static func earliestObservations(_ earthOrientationTable: EarthOrientationTable?, _ deltaTTable: DeltaTTable?) -> Observations? {
			switch (earthOrientationTable, deltaTTable) {
			case let (earthOrientationTable?, deltaTTable?):
				earthOrientationTable.coverage.lowerBound <= deltaTTable.coverage.lowerBound ? .earthOrientationTable : .deltaTTable
			case (_?, nil):
				.earthOrientationTable
			case (nil, _?):
				.deltaTTable
			case (nil, nil):
				nil
			}
		}

		/// Returns which of the sources ends later, preferring Earth orientation data on a tie.
		private static func latestObservations(_ earthOrientationTable: EarthOrientationTable?, _ deltaTTable: DeltaTTable?) -> Observations? {
			switch (earthOrientationTable, deltaTTable) {
			case let (earthOrientationTable?, deltaTTable?):
				earthOrientationTable.coverage.upperBound >= deltaTTable.coverage.upperBound ? .earthOrientationTable : .deltaTTable
			case (_?, nil):
				.earthOrientationTable
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
