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
/// orientation data, if supplied, ``DeltaTTable/modern``, ``DeltaTTable/historic``, and
/// ``DeltaTModel/espenakMeeus2006`` that covers the date. The most recent observations are
/// continued along their trend over the last year for ``Context/defaultTrendYears`` Julian
/// years; otherwise ΔT is a published value.
///
/// Where one source hands over to the next, ΔT can be discontinuous: by default by 3.7 s at
/// 1657.0, and by several seconds where the trend ends and the model begins. Where ΔT steps
/// up, UT1 instants within the step have no exact TT, and where it steps down they have two,
/// so ``toTT(_:context:)`` and ``fromTT(_:context:)`` are not exact inverses within a step's
/// width of a handover. Use
/// ``Context/continuous(earthOrientation:modernDeltaT:historicDeltaT:model:)`` to join the
/// sources continuously instead.
public enum UT1: Timescale {
	public static let abbreviation = "UT1"

	/// No Earth orientation data; ΔT from ``DeltaTTable/modern`` from 1973, continued along its
	/// trend for ``Context/defaultTrendYears`` Julian years, from ``DeltaTTable/historic`` from
	/// 1657.0, and from ``DeltaTModel/espenakMeeus2006`` elsewhere.
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

		/// Creates a UT1 context that takes ΔT from the first of Earth orientation data, ΔT
		/// tables, and a model that covers the date.
		///
		/// Whichever of `earthOrientation` and `modernDeltaT` ends later is continued along its
		/// trend over the last year for `trendYears` Julian years. Every other value comes
		/// unchanged from one source, so ΔT can be discontinuous where one source hands over to
		/// the next, including where the trend ends.
		///
		/// - Parameters:
		///   - earthOrientation: Observed and predicted Earth orientation.
		///   - modernDeltaT: Tabulated ΔT for recent decades, used outside `earthOrientation`.
		///   - historicDeltaT: Tabulated ΔT for earlier centuries, used outside the others.
		///   - model: The model used outside the data, or `nil` to require data.
		///   - trendYears: The number of Julian years to continue the most recent
		///     observations, or `nil` to use only published values.
		public init(
			earthOrientation: EarthOrientationTable? = nil,
			modernDeltaT: DeltaTTable? = .modern,
			historicDeltaT: DeltaTTable? = .historic,
			model: DeltaTModel? = .espenakMeeus2006,
			trendYears: Double? = defaultTrendYears
		) {
			let latest = Self.latestObservations(earthOrientation, modernDeltaT)
			func trend(_ source: some BoundedDeltaTSource, isLatest: Bool) -> any DeltaTSource {
				guard isLatest, let trendYears else { return source }
				return DeltaTExtrapolation(source, after: .linear(), limit: trendYears)
			}

			var sources: [any DeltaTSource] = []
			if let earthOrientation { sources.append(trend(earthOrientation, isLatest: latest == .earthOrientation)) }
			if let modernDeltaT { sources.append(trend(modernDeltaT, isLatest: latest == .modernDeltaT)) }
			if let historicDeltaT { sources.append(historicDeltaT) }
			if let model { sources.append(model) }
			self.init(deltaT: DeltaTSourceList(sources))
		}

		/// Returns a UT1 context that takes ΔT from Earth orientation data and ΔT tables, with
		/// a model offset to join them continuously.
		///
		/// ΔT comes from `earthOrientation`, `modernDeltaT`, and `historicDeltaT` within their
		/// ranges, in that order. After the end of whichever of `earthOrientation` and
		/// `modernDeltaT` ends later, and before the start of `historicDeltaT`, ΔT follows
		/// `model` offset to join the data continuously. ΔT can still step where one table hands
		/// over to the next, by milliseconds between the observations.
		///
		/// The joined values are not published values: before 1657.0, for example, ΔT is the
		/// model's plus about 3.7 s.
		///
		/// - Parameters:
		///   - earthOrientation: Observed and predicted Earth orientation.
		///   - modernDeltaT: Tabulated ΔT for recent decades.
		///   - historicDeltaT: Tabulated ΔT for earlier centuries.
		///   - model: The model used outside the data, or `nil` to require data.
		public static func continuous(
			earthOrientation: EarthOrientationTable? = nil,
			modernDeltaT: DeltaTTable? = .modern,
			historicDeltaT: DeltaTTable? = .historic,
			model: DeltaTModel? = .espenakMeeus2006
		) -> Context {
			let join = model.map { DeltaTExtrapolation.Method.following($0) }
			let latest = Self.latestObservations(earthOrientation, modernDeltaT)
			var sources: [any DeltaTSource] = []
			if let earthOrientation {
				sources.append(DeltaTExtrapolation(earthOrientation, after: latest == .earthOrientation ? join : nil))
			}
			if let modernDeltaT {
				sources.append(DeltaTExtrapolation(modernDeltaT, after: latest == .modernDeltaT ? join : nil))
			}
			if let historicDeltaT {
				sources.append(DeltaTExtrapolation(historicDeltaT, before: join, after: join))
			}
			if let model {
				sources.append(model)
			}
			return Context(deltaT: DeltaTSourceList(sources))
		}

		/// The source of the most recent observations.
		private enum LatestObservations {
			case earthOrientation
			case modernDeltaT
		}

		/// Returns which of the sources ends later, preferring Earth orientation data on a tie.
		private static func latestObservations(_ earthOrientation: EarthOrientationTable?, _ modernDeltaT: DeltaTTable?) -> LatestObservations? {
			switch (earthOrientation, modernDeltaT) {
			case let (earthOrientation?, modernDeltaT?):
				earthOrientation.coverage.upperBound >= modernDeltaT.coverage.upperBound ? .earthOrientation : .modernDeltaT
			case (_?, nil):
				.earthOrientation
			case (nil, _?):
				.modernDeltaT
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
