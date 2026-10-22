#!/usr/bin/env python3
#
# SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
# SPDX-License-Identifier: MIT
#
# Part of https://github.com/sbooth/Astronomia
#

"""Generates C source for Astronomia's built-in ephemeris data from published series.

The series are written as C arrays, which the C compiler turns into read-only data in seconds;
the same values as Swift array literals take minutes to compile. Values are written as
hexadecimal floating-point literals, so they are exact.

Commands:

  vsop2013 DIRECTORY
      The VSOP2013 planetary solution (Simon et al. 2013) in DIRECTORY, the files
      VSOP2013p1.dat to VSOP2013p9.dat. Writes one C file per body to the output directory.

      Terms are kept when their amplitude, times the largest |T| of the span to the power of
      the term's power of time, is at least the body's threshold; for the semimajor axis the
      amplitude is relative to the axis. T is TDB in thousands of Julian years from J2000.0.
      The default span, J1000.0 to J3000.0, and thresholds keep the geocentric error from
      truncation near 0.5 mas, or below the solution's own error. The coarser precision
      levels have fixed thresholds, multiples of the default ones.

      Each term is written as its phase at J2000.0 and frequency, the sums of its integer
      multipliers times the mean longitudes and mean motions of VSOP2013.f, in the same order
      and precision, followed by its sine and cosine coefficients. The mean motion term of
      the mean longitude is left out, as VSOP2013.f leaves it out; the evaluator adds the
      body's mean motion separately.

  elpmpp02 DIRECTORY
      The ELP/MPP02 lunar solution (Chapront and Francou 2003) in DIRECTORY, the files
      ELP_MAIN.S1 to ELP_MAIN.S3 and ELP_PERT.S1 to ELP_PERT.S3. Writes ELPMPP02.c to the
      output directory.

      Terms are kept when their amplitude, times the largest |T| of the span to the power of
      the term's power of time, is at least the threshold of the variable: an angle, in
      arcseconds, for longitude and latitude, and a distance, in kilometers, for distance.
      T is TDB in Julian centuries from J2000.0. The default span, J1000.0 to J3000.0, and
      thresholds keep the error from truncation near 0.2 mas in direction and 10 m in
      distance. The coarser precision levels have fixed thresholds, multiples of the default
      ones.

      Each term is written as in the files, with its integer multipliers of the fundamental
      arguments, because the arguments depend on the fit of the solution, to lunar laser
      ranging or to DE405, which the evaluator chooses. The terms of the main problem keep
      the partial derivatives by which the fit corrects their amplitudes.

  iau2006 DIRECTORY
      The IAU 2006 precession and IAU 2000A_R06 nutation series of the IERS Conventions
      (2010), Chapter 5, in DIRECTORY, the files tab5.3a.txt, tab5.3b.txt, and tab5.2d.txt.
      Writes IAU2006.c to the output directory.

      Each table is written as in the file: its polynomial part, if any, then its terms by
      power of time j, each with its sine and cosine coefficients in microarcseconds and its
      integer multipliers of the fourteen fundamental arguments l, l', F, D, Ω, the mean
      longitudes of Mercury to Neptune, and p_A. Terms are kept when their amplitude, times
      the largest |t| of the span to the power j, is at least the threshold, where t is TT in
      Julian centuries from J2000.0. The default threshold, 0, keeps every term of the tables,
      whose own cutoff is 0.1 microarcsecond. The coarser precision levels have fixed
      thresholds.

Precision levels:

  Each series is written with its terms in order of decreasing amplitude, scaled as for the
  threshold, and with the number of leading terms kept at each of five precision levels, the
  first every term written. A coarser level's terms are a subset of a finer one's, so the
  levels need no more data than the finest; the evaluator sums a series' leading terms. The
  span, the thresholds of each level, and the counts are written with the data.

  The first level is the data as generated, whose thresholds the options set. The four
  coarser levels have fixed thresholds, calibrated so that each stays within the bound its
  name promises: 10 mas, 0.1", 1", and 10". Finer thresholds for the first level make it
  more accurate without changing the others, and a threshold looser than the second level's
  is an error, because the levels would no longer nest.

Examples:

  Scripts/generate-ephemeris-data.py vsop2013 VSOP2013/solution \\
      --output Sources/CAstronomiaData/VSOP2013
  Scripts/generate-ephemeris-data.py elpmpp02 ELPMPP02 \\
      --output Sources/CAstronomiaData/ELPMPP02
  Scripts/generate-ephemeris-data.py iau2006 IERS2010 \\
      --output Sources/CAstronomiaData/IAU2006

Run a command with --help for its options.
"""

import argparse
import decimal
import hashlib
import os
import re
import sys

SPDX_HEADER = [
	"//",
	"// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>",
	"// SPDX-License-Identifier: MIT",
	"//",
	"// Part of https://github.com/sbooth/Astronomia",
	"//",
	"",
]

# VSOP2013.f: mean longitudes at J2000.0 (radians) and mean motions (radians per thousand
# Julian years) of the 17 arguments: Mercury, Venus, EMB, Mars, Vesta, Iris, Bamberga, Ceres,
# Pallas, Jupiter, Saturn, Uranus, Neptune, Pluto's μ, and the Moon's D, F, and l.
CI0 = [
	0.4402608631669000e1, 0.3176134461576000e1, 0.1753470369433000e1, 0.6203500014141000e1,
	0.4091360003050000e1, 0.1713740719173000e1, 0.5598641292287000e1, 0.2805136360408000e1,
	0.2326989734620000e1, 0.5995461070350000e0, 0.8740185101070000e0, 0.5481225395663000e1,
	0.5311897933164000e1, 0.0, 5.19846640063, 1.62790513602, 2.35555563875,
]
CI1 = [
	0.2608790314068555e5, 0.1021328554743445e5, 0.6283075850353215e4, 0.3340612434145457e4,
	0.1731170452721855e4, 0.1704450855027201e4, 0.1428948917844273e4, 0.1364756513629990e4,
	0.1361923207632842e4, 0.5296909615623250e3, 0.2132990861084880e3, 0.7478165903077800e2,
	0.3813297222612500e2, 0.3595362285049309e0, 77713.7714481804, 84334.6615717837,
	83286.9142477147,
]

BODIES = ["Mercury", "Venus", "EarthMoonBarycenter", "Mars", "Jupiter", "Saturn", "Uranus", "Neptune", "Pluto"]
# Thresholds for J1000.0 to J3000.0 at about 0.5 mas, from a study of the truncation error.
# Pluto's is looser, matching the error of its solution.
THRESHOLDS = [3.2e-11, 3.2e-12, 3.2e-12, 3.2e-12, 1e-11, 1e-11, 3.2e-11, 1e-11, 1e-10]
VARIABLES = "a λ k h q p".split()
# The number of precision levels, and the thresholds of the four coarser levels: for VSOP2013
# and ELP/MPP02, multiples of their default thresholds, and for the IAU 2006 series, in
# microarcseconds. They were chosen by measurement over J1000.0 to J3000.0 so that the error in
# the geocentric direction of the Moon and the planets other than Pluto, plus the error in the
# nutation, is within each level's bound: 10 mas, 0.1", 1", and 10". The largest errors found
# were 5.9 mas, 84 mas, 0.83", and 6.7".
LEVELS = 5
VSOP_LEVEL_FACTORS = [4, 80, 1500, 30000]
ELP_LEVEL_FACTORS = [3, 60, 1500, 30000]
IAU_LEVEL_THRESHOLDS = [50, 1500, 40000, 800000]
# The default thresholds of ELP/MPP02, in arcseconds and kilometers
ELP_ANGLE_THRESHOLD = 1e-5
ELP_DISTANCE_THRESHOLD = 1e-4
NUMBER = re.compile(r"\s*(-?\d+\.\d+)\s*([+-]\d+)\s*$")


class DataError(Exception):
	"""A problem with an input file."""


def coefficient(text: str, path: str, line_number: int) -> float:
	"""Reads a coefficient written as a mantissa and a separate exponent, "0.38 +00"."""
	match = NUMBER.match(text)
	if not match:
		raise DataError(f"{path}:{line_number}: expected a coefficient, found {text!r}")
	return float(match.group(1) + "e" + match.group(2))


def read_series(path: str, body: int) -> list[tuple[int, int, list[tuple[list[int], float, float]]]]:
	"""Returns the series in a file as (variable, power, terms), each term (multipliers, S, C)."""
	with open(path) as file:
		lines = file.read().split("\n")
	series = []
	index = 0
	while index < len(lines):
		line = lines[index]
		index += 1
		if not line.strip():
			continue
		if not line.startswith(" VSOP2013"):
			raise DataError(f"{path}:{index}: expected a series header, found {line!r}")
		fields = line.split()
		file_body, variable, power, count = (int(field) for field in fields[1:5])
		if file_body != body + 1 or not 1 <= variable <= 6 or not 0 <= power <= 20:
			raise DataError(f"{path}:{index}: unexpected header {line!r}")
		terms = []
		for _ in range(count):
			text = lines[index]
			index += 1
			# Fortran format (6x,4i3,1x,5i3,1x,4i4,1x,i6,1x,3i3,2a24)
			position = 6
			multipliers = []
			for width, fields_count, gap in ((3, 4, 1), (3, 5, 1), (4, 4, 1), (6, 1, 1), (3, 3, 0)):
				for _ in range(fields_count):
					multipliers.append(int(text[position : position + width]))
					position += width
				position += gap
			s = coefficient(text[position : position + 24], path, index)
			c = coefficient(text[position + 24 : position + 48], path, index)
			terms.append((multipliers, s, c))
		series.append((variable, power, terms))
	return series


def level_thresholds(threshold: float, coarser: list[float], name: str) -> list[float]:
	"""Returns the thresholds of every level: the data's, then the coarser levels' fixed ones."""
	if len(coarser) != LEVELS - 1 or coarser != sorted(coarser):
		raise DataError(f"expected {LEVELS - 1} increasing thresholds for the coarser levels")
	if threshold > coarser[0]:
		raise DataError(f"the threshold of {name}, {threshold:g}, is looser than the second precision level's, {coarser[0]:g}")
	return [threshold] + coarser


def level_counts(amplitudes: list[float], thresholds: list[float]) -> list[int]:
	"""Returns the number of leading amplitudes, in decreasing order, at least each threshold."""
	return [sum(1 for amplitude in amplitudes if amplitude >= threshold) for threshold in thresholds]


def c_counts(counts: list[int]) -> str:
	return "{" + ", ".join(f"{count:6}" for count in counts) + "}"


def phase_and_frequency(multipliers: list[int]) -> tuple[float, float]:
	"""Sums as VSOP2013.f does, one argument at a time from the first."""
	phase = 0.0
	frequency = 0.0
	for multiplier, longitude, motion in zip(multipliers, CI0, CI1):
		phase = phase + float(multiplier) * longitude
		frequency = frequency + float(multiplier) * motion
	return phase, frequency


def vsop2013(args: argparse.Namespace) -> None:
	span = max(abs(args.start - 2000), abs(args.end - 2000)) / 1000
	thresholds = args.thresholds or THRESHOLDS
	if len(thresholds) != 9:
		raise DataError("expected nine thresholds, one per body")
	factors = args.level_factors or VSOP_LEVEL_FACTORS
	os.makedirs(args.output, exist_ok=True)
	summary = []
	for body, name in enumerate(BODIES):
		path = os.path.join(args.directory, f"VSOP2013p{body + 1}.dat")
		with open(path, "rb") as file:
			digest = hashlib.sha256(file.read()).hexdigest()
		series = read_series(path, body)
		levels = level_thresholds(thresholds[body], [THRESHOLDS[body] * factor for factor in factors], name)

		semimajor_axis = next(terms[0][2] for variable, power, terms in series if variable == 1 and power == 0)
		kept_series = []
		kept_terms = []
		total = 0
		for variable, power, terms in series:
			if variable == 2 and power == 1:
				# The mean motion, which the evaluator adds separately
				terms = terms[1:]
			total += len(terms)
			scale = span ** power / (semimajor_axis if variable == 1 else 1)
			scaled = sorted((((term[1] ** 2 + term[2] ** 2) ** 0.5 * scale, term) for term in terms), key=lambda pair: -pair[0])
			kept = [(amplitude, term) for amplitude, term in scaled if amplitude >= thresholds[body]]
			if kept:
				counts = level_counts([amplitude for amplitude, _ in kept], levels)
				kept_series.append((variable, power, counts))
				kept_terms += [term for _, term in kept]

		symbol = "astronomia_vsop2013_" + re.sub(r"(?<!^)(?=[A-Z])", "_", name).lower()
		lines = list(SPDX_HEADER)
		lines += [
			"// Generated by Scripts/generate-ephemeris-data.py vsop2013. Do not edit.",
			f"// Source: VSOP2013p{body + 1}.dat, https://ftp.imcce.fr/pub/ephem/planets/vsop2013/solution/",
			f"// SHA-256: {digest}",
			f"// {name}: {len(kept_terms):,} of {total:,} terms, threshold {thresholds[body]:g}, "
			f"J{args.start:g} to J{args.end:g}",
			"// Terms at each precision level: " + ", ".join(f"{sum(counts[level] for _, _, counts in kept_series):,}" for level in range(LEVELS)),
			"",
			'#include "CAstronomiaData.h"',
			"",
			"// Variable (1 to 6 for a, λ, k, h, q, p), power of time, and number of terms at each",
			"// precision level",
			"static const struct astronomia_vsop_series series[] = {",
		]
		for variable, power, counts in kept_series:
			lines.append(f"\t{{{variable}, {power:2}, {c_counts(counts)}}}, // {VARIABLES[variable - 1]} T^{power}")
		lines += [
			"};",
			"",
			"// Phase at J2000.0 (radians), frequency (radians per thousand Julian years), S, C",
			"static const struct astronomia_vsop_term terms[] = {",
		]
		for multipliers, s, c in kept_terms:
			phase, frequency = phase_and_frequency(multipliers)
			lines.append("\t{" + ", ".join(value.hex() for value in (phase, frequency, s, c)) + "},")
		lines += [
			"};",
			"",
			f"const struct astronomia_vsop_series_data {symbol} = {{",
			"\tsizeof(series) / sizeof(series[0]), series,",
			"\tsizeof(terms) / sizeof(terms[0]), terms,",
			f"\t{float(args.start).hex()}, {float(args.end).hex()},",
			"\t{" + ", ".join(float(threshold).hex() for threshold in levels) + "},",
			"};",
			"",
		]
		with open(os.path.join(args.output, f"VSOP2013{name}.c"), "w") as file:
			file.write("\n".join(lines))
		summary.append(f"{name}: {len(kept_terms):,} of {total:,} terms")
	print("\n".join(summary), file=sys.stderr)


ELP_VARIABLES = ["longitude", "latitude", "distance"]


def elp_number(text: str, path: str, line_number: int) -> float:
	"""Reads a Fortran number, whose exponent may be written with D."""
	try:
		return float(text.replace("D", "e").replace("d", "e"))
	except ValueError:
		raise DataError(f"{path}:{line_number}: expected a number, found {text!r}") from None


def elp_count(line: str, path: str, line_number: int, expected: str) -> list[int]:
	"""Reads the counts of a series header, "MAIN PROBLEM. LONGITUDE.       1023"."""
	if not line.startswith(expected):
		raise DataError(f"{path}:{line_number}: expected a header {expected!r}, found {line!r}")
	try:
		return [int(field) for field in line[25:].split()]
	except ValueError:
		raise DataError(f"{path}:{line_number}: unexpected header {line!r}") from None


def read_elp_main(path: str, variable: int) -> list[tuple[list[int], float, list[float]]]:
	"""Returns the terms of a main problem file, each (multipliers, amplitude, partials)."""
	with open(path) as file:
		lines = file.read().split("\n")
	(count,) = elp_count(lines[0], path, 1, f"MAIN PROBLEM. {ELP_VARIABLES[variable - 1].upper()}.")
	terms = []
	for index in range(1, count + 1):
		text = lines[index]
		# Fortran format (4i3,2x,f13.5,5f12.2); the files' seventh column is unused
		try:
			multipliers = [int(text[3 * i : 3 * i + 3]) for i in range(4)]
		except ValueError:
			raise DataError(f"{path}:{index + 1}: expected multipliers, found {text!r}") from None
		amplitude = elp_number(text[14:27], path, index + 1)
		partials = [elp_number(text[27 + 12 * i : 39 + 12 * i], path, index + 1) for i in range(5)]
		terms.append((multipliers, amplitude, partials))
	return terms


def read_elp_perturbations(path: str, variable: int) -> list[tuple[int, list[tuple[float, float, list[int]]]]]:
	"""Returns the series of a perturbations file as (power, terms), each term (S, C, multipliers)."""
	with open(path) as file:
		lines = file.read().split("\n")
	series = []
	index = 0
	for power in range(4):
		count, file_power = elp_count(lines[index], path, index + 1, f"PERTURBATIONS. {ELP_VARIABLES[variable - 1].upper()}.")
		if file_power != power:
			raise DataError(f"{path}:{index + 1}: expected power {power}, found {file_power}")
		index += 1
		terms = []
		for _ in range(count):
			text = lines[index]
			index += 1
			# Fortran format (i5,2d20.13,16i3); the last three multipliers are unused
			s = elp_number(text[5:25], path, index)
			c = elp_number(text[25:45], path, index)
			try:
				multipliers = [int(text[45 + 3 * i : 48 + 3 * i]) for i in range(16)]
			except ValueError:
				raise DataError(f"{path}:{index}: expected multipliers, found {text!r}") from None
			if any(multipliers[13:]):
				raise DataError(f"{path}:{index}: unexpected multipliers {multipliers[13:]}")
			terms.append((s, c, multipliers[:13]))
		series.append((power, terms))
	return series


def c_int8_list(values: list[int]) -> str:
	if any(not -128 <= value <= 127 for value in values):
		raise DataError(f"multipliers out of range: {values}")
	return "{" + ", ".join(str(value) for value in values) + "}"


def elpmpp02(args: argparse.Namespace) -> None:
	span = max(abs(args.start - 2000), abs(args.end - 2000)) / 100
	thresholds = [args.angle_threshold, args.angle_threshold, args.distance_threshold]
	factors = args.level_factors or ELP_LEVEL_FACTORS
	angle_levels = level_thresholds(args.angle_threshold, [ELP_ANGLE_THRESHOLD * factor for factor in factors], "longitude and latitude")
	distance_levels = level_thresholds(args.distance_threshold, [ELP_DISTANCE_THRESHOLD * factor for factor in factors], "distance")
	os.makedirs(args.output, exist_ok=True)

	digests = []
	main_series = []
	main_terms = []
	perturbation_series = []
	perturbation_terms = []
	summary = []
	for variable in (1, 2, 3):
		threshold = thresholds[variable - 1]
		for kind in ("MAIN", "PERT"):
			path = os.path.join(args.directory, f"ELP_{kind}.S{variable}")
			with open(path, "rb") as file:
				digests.append((os.path.basename(path), hashlib.sha256(file.read()).hexdigest()))
		path = os.path.join(args.directory, f"ELP_MAIN.S{variable}")
		levels = distance_levels if variable == 3 else angle_levels
		terms = read_elp_main(path, variable)
		kept = sorted((term for term in terms if abs(term[1]) >= threshold), key=lambda term: -abs(term[1]))
		main_series.append((variable, 0, level_counts([abs(term[1]) for term in kept], levels)))
		main_terms += kept
		total = len(terms)
		count = len(kept)

		path = os.path.join(args.directory, f"ELP_PERT.S{variable}")
		for power, terms in read_elp_perturbations(path, variable):
			scaled = sorted((((term[0] ** 2 + term[1] ** 2) ** 0.5 * span ** power, term) for term in terms), key=lambda pair: -pair[0])
			kept = [(amplitude, term) for amplitude, term in scaled if amplitude >= threshold]
			total += len(terms)
			count += len(kept)
			if kept:
				perturbation_series.append((variable, power, level_counts([amplitude for amplitude, _ in kept], levels)))
				perturbation_terms += [term for _, term in kept]
		summary.append(f"{ELP_VARIABLES[variable - 1].capitalize()}: {count:,} of {total:,} terms")

	lines = list(SPDX_HEADER)
	lines += ["// Generated by Scripts/generate-ephemeris-data.py elpmpp02. Do not edit."]
	lines += ["// Source: ELP/MPP02 (Chapront and Francou 2003), as distributed with ELPMPP02.for"]
	lines += [f"// SHA-256 {digest}  {name}" for name, digest in digests]
	lines += [
		f"// {len(main_terms) + len(perturbation_terms):,} terms, thresholds {args.angle_threshold:g}\" and "
		f"{args.distance_threshold:g} km, J{args.start:g} to J{args.end:g}",
		"// Terms at each precision level: " + ", ".join(f"{sum(counts[level] for _, _, counts in main_series + perturbation_series):,}" for level in range(LEVELS)),
		"",
		'#include "CAstronomiaData.h"',
		"",
		"// Variable (1 to 3 for longitude, latitude, distance), power of time, and number of terms at",
		"// each precision level",
		"static const struct astronomia_elp_series main_series[] = {",
	]
	for variable, power, counts in main_series:
		lines.append(f"\t{{{variable}, {power}, {c_counts(counts)}}}, // {ELP_VARIABLES[variable - 1]}")
	lines += [
		"};",
		"",
		"// Amplitude, partial derivatives B1 to B5, multipliers of D, F, l, l'",
		"static const struct astronomia_elp_main_term main_terms[] = {",
	]
	for multipliers, amplitude, partials in main_terms:
		partial_list = ", ".join(value.hex() for value in partials)
		lines.append(f"\t{{{amplitude.hex()}, {{{partial_list}}}, {c_int8_list(multipliers)}}},")
	lines += [
		"};",
		"",
		"// Variable (1 to 3 for longitude, latitude, distance), power of time, and number of terms at",
		"// each precision level",
		"static const struct astronomia_elp_series perturbation_series[] = {",
	]
	for variable, power, counts in perturbation_series:
		lines.append(f"\t{{{variable}, {power}, {c_counts(counts)}}}, // {ELP_VARIABLES[variable - 1]} T^{power}")
	lines += [
		"};",
		"",
		"// S, C, multipliers of D, F, l, l', Mercury to Neptune, and ζ",
		"static const struct astronomia_elp_perturbation_term perturbation_terms[] = {",
	]
	for s, c, multipliers in perturbation_terms:
		lines.append(f"\t{{{s.hex()}, {c.hex()}, {c_int8_list(multipliers)}}},")
	lines += [
		"};",
		"",
		"const struct astronomia_elp_series_data astronomia_elpmpp02 = {",
		"\tsizeof(main_series) / sizeof(main_series[0]), main_series,",
		"\tsizeof(main_terms) / sizeof(main_terms[0]), main_terms,",
		"\tsizeof(perturbation_series) / sizeof(perturbation_series[0]), perturbation_series,",
		"\tsizeof(perturbation_terms) / sizeof(perturbation_terms[0]), perturbation_terms,",
		f"\t{float(args.start).hex()}, {float(args.end).hex()},",
		"\t{" + ", ".join(float(threshold).hex() for threshold in angle_levels) + "},",
		"\t{" + ", ".join(float(threshold).hex() for threshold in distance_levels) + "},",
		"};",
		"",
	]
	with open(os.path.join(args.output, "ELPMPP02.c"), "w") as file:
		file.write("\n".join(lines))
	print("\n".join(summary), file=sys.stderr)


# The tables of the IERS Conventions (2010), Chapter 5: file, symbol, description, and the
# unit of the polynomial part, in microarcseconds, or None for a table without one.
IAU_TABLES = [
	("tab5.3a.txt", "nutation_longitude", "Nutation in longitude, Δψ", None),
	("tab5.3b.txt", "nutation_obliquity", "Nutation in obliquity, Δε", None),
	("tab5.2d.txt", "s_plus_half_xy", "The CIO locator s plus XY/2", 1),
]
IAU_HEADER = re.compile(r"^\s*j\s*=\s*(\d+)\s+(?:Number\s+of\s+terms|Nb\s+of\s+terms)\s*=\s*(\d+)\s*$")
IAU_POLYNOMIAL_TERM = re.compile(r"([+-]?)\s*(\d+(?:\.\d*)?)\s*(?:t(?:\^(\d))?)?")


def read_iau_polynomial(lines: list[str], path: str, unit: int) -> list[float]:
	"""Returns the coefficients of t^0 to t^5 of a table's polynomial part, in microarcseconds."""
	for index, line in enumerate(lines):
		if line.startswith("Polynomial part"):
			break
	else:
		raise DataError(f"{path}: expected a polynomial part")
	text = next((line for line in lines[index + 1 :] if line.strip()), "")
	coefficients = [decimal.Decimal(0)] * 6
	position = 0
	text = text.strip()
	while position < len(text):
		match = IAU_POLYNOMIAL_TERM.match(text, position)
		if not match or match.end() == position:
			raise DataError(f"{path}:{index + 2}: unexpected polynomial {text!r}")
		sign, value, power = match.groups()
		has_t = "t" in match.group(0)
		degree = int(power) if power else (1 if has_t else 0)
		if not 0 <= degree <= 5:
			raise DataError(f"{path}:{index + 2}: unexpected power of t in {text!r}")
		coefficients[degree] = decimal.Decimal(sign + value) * unit
		position = match.end()
		while position < len(text) and text[position] == " ":
			position += 1
	return [float(coefficient) for coefficient in coefficients]


def read_iau_table(path: str) -> list[tuple[int, list[tuple[float, float, list[int]]]]]:
	"""Returns a table's series as (power, terms), each term (S, C, multipliers)."""
	with open(path) as file:
		lines = file.read().split("\n")
	series = []
	expected_index = 1
	index = 0
	while index < len(lines):
		match = IAU_HEADER.match(lines[index])
		index += 1
		if not match:
			continue
		power, count = int(match.group(1)), int(match.group(2))
		if power != len(series):
			raise DataError(f"{path}:{index}: expected j = {len(series)}, found j = {power}")
		terms = []
		while len(terms) < count:
			if index >= len(lines):
				raise DataError(f"{path}: expected {count} terms for j = {power}, found {len(terms)}")
			fields = lines[index].split()
			index += 1
			if not fields or not fields[0].isdigit():
				continue
			if len(fields) != 17 or int(fields[0]) != expected_index:
				raise DataError(f"{path}:{index}: expected term {expected_index}, found {lines[index - 1]!r}")
			expected_index += 1
			terms.append((float(fields[1]), float(fields[2]), [int(field) for field in fields[3:]]))
		series.append((power, terms))
	if not series:
		raise DataError(f"{path}: expected series")
	return series


def iau2006(args: argparse.Namespace) -> None:
	span = max(abs(args.start - 2000), abs(args.end - 2000)) / 100
	levels = level_thresholds(args.threshold, args.level_thresholds or IAU_LEVEL_THRESHOLDS, "the IAU 2006 series")
	os.makedirs(args.output, exist_ok=True)
	lines = list(SPDX_HEADER)
	lines += [
		"// Generated by Scripts/generate-ephemeris-data.py iau2006. Do not edit.",
		"// Source: IERS Conventions (2010), Chapter 5, https://iers-conventions.obspm.fr",
	]
	tables = []
	for file_name, symbol, description, unit in IAU_TABLES:
		path = os.path.join(args.directory, file_name)
		with open(path, "rb") as file:
			lines.append(f"// SHA-256 {hashlib.sha256(file.read()).hexdigest()}  {file_name}")
		with open(path) as file:
			polynomial = read_iau_polynomial(file.read().split("\n"), path, unit) if unit else [0.0] * 6
		tables.append((file_name, symbol, description, polynomial, read_iau_table(path)))
	lines += [
		f"// Threshold {args.threshold:g} microarcsecond, J{args.start:g} to J{args.end:g}",
		"// Thresholds of the precision levels: " + ", ".join(f"{threshold:g}" for threshold in levels) + " microarcseconds",
		"",
		'#include "CAstronomiaData.h"',
		"",
	]
	summary = []
	for file_name, symbol, description, polynomial, series in tables:
		kept_series = []
		kept_terms = []
		total = 0
		for power, terms in series:
			total += len(terms)
			scaled = sorted((((term[0] ** 2 + term[1] ** 2) ** 0.5 * span ** power, term) for term in terms), key=lambda pair: -pair[0])
			kept = [(amplitude, term) for amplitude, term in scaled if amplitude >= args.threshold]
			if kept:
				kept_series.append((power, level_counts([amplitude for amplitude, _ in kept], levels)))
				kept_terms += [term for _, term in kept]
		lines += [
			f"// {description}, from {file_name}: {len(kept_terms):,} of {total:,} terms; at each precision level, "
			+ ", ".join(f"{sum(counts[level] for _, counts in kept_series):,}" for level in range(LEVELS)),
			"",
			"// Power of time and number of terms at each precision level",
			f"static const struct astronomia_iau_series {symbol}_series[] = {{",
		]
		lines += [f"\t{{{power}, {c_counts(counts)}}}," for power, counts in kept_series]
		lines += [
			"};",
			"",
			"// S, C (microarcseconds), multipliers of l, l', F, D, Ω, Mercury to Neptune, and p_A",
			f"static const struct astronomia_iau_term {symbol}_terms[] = {{",
		]
		lines += [f"\t{{{s.hex()}, {c.hex()}, {c_int8_list(multipliers)}}}," for s, c, multipliers in kept_terms]
		lines += [
			"};",
			"",
			f"const struct astronomia_iau_series_data astronomia_iau2006_{symbol} = {{",
			"\t{" + ", ".join(value.hex() for value in polynomial) + "},",
			f"\tsizeof({symbol}_series) / sizeof({symbol}_series[0]), {symbol}_series,",
			f"\tsizeof({symbol}_terms) / sizeof({symbol}_terms[0]), {symbol}_terms,",
			"\t{" + ", ".join(float(threshold).hex() for threshold in levels) + "},",
			f"\t{float(args.start).hex()}, {float(args.end).hex()},",
			"};",
			"",
		]
		summary.append(f"{description}: {len(kept_terms):,} of {total:,} terms")
	with open(os.path.join(args.output, "IAU2006.c"), "w") as file:
		file.write("\n".join(lines))
	print("\n".join(summary), file=sys.stderr)


def main() -> None:
	parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	commands = parser.add_subparsers(dest="command", required=True)
	command = commands.add_parser("vsop2013", help="the VSOP2013 planetary solution", description=vsop2013.__doc__)
	command.add_argument("directory", help="the directory holding VSOP2013p1.dat to VSOP2013p9.dat")
	command.add_argument("--output", required=True, help="the directory to write the C files to")
	command.add_argument("--start", type=float, default=1000, help="the first Julian epoch covered (default: 1000)")
	command.add_argument("--end", type=float, default=3000, help="the last Julian epoch covered (default: 3000)")
	command.add_argument("--thresholds", type=float, nargs=9, metavar="T", help="the nine thresholds, Mercury to Pluto")
	command.add_argument("--level-factors", type=float, nargs=LEVELS - 1, metavar="F", help="the factors of the default thresholds for the four coarser precision levels, to recalibrate them (default: 4 80 1500 30000)")
	command.set_defaults(generate=vsop2013)
	command = commands.add_parser("elpmpp02", help="the ELP/MPP02 lunar solution", description=elpmpp02.__doc__)
	command.add_argument("directory", help="the directory holding ELP_MAIN.S1 to ELP_PERT.S3")
	command.add_argument("--output", required=True, help="the directory to write the C file to")
	command.add_argument("--start", type=float, default=1000, help="the first Julian epoch covered (default: 1000)")
	command.add_argument("--end", type=float, default=3000, help="the last Julian epoch covered (default: 3000)")
	command.add_argument("--angle-threshold", type=float, default=ELP_ANGLE_THRESHOLD, metavar="ARCSECONDS", help=f"the threshold for longitude and latitude (default: {ELP_ANGLE_THRESHOLD:g})")
	command.add_argument("--distance-threshold", type=float, default=ELP_DISTANCE_THRESHOLD, metavar="KILOMETERS", help=f"the threshold for distance (default: {ELP_DISTANCE_THRESHOLD:g})")
	command.add_argument("--level-factors", type=float, nargs=LEVELS - 1, metavar="F", help="the factors of the default thresholds for the four coarser precision levels, to recalibrate them (default: 3 60 1500 30000)")
	command.set_defaults(generate=elpmpp02)
	command = commands.add_parser("iau2006", help="the IAU 2006/2000A precession-nutation series", description=iau2006.__doc__)
	command.add_argument("directory", help="the directory holding tab5.3a.txt, tab5.3b.txt, and tab5.2d.txt")
	command.add_argument("--output", required=True, help="the directory to write the C file to")
	command.add_argument("--start", type=float, default=1000, help="the first Julian epoch covered (default: 1000)")
	command.add_argument("--end", type=float, default=3000, help="the last Julian epoch covered (default: 3000)")
	command.add_argument("--threshold", type=float, default=0, metavar="MICROARCSECONDS", help="the threshold for terms (default: 0, every term)")
	command.add_argument("--level-thresholds", type=float, nargs=LEVELS - 1, metavar="MICROARCSECONDS", help="the thresholds of the four coarser precision levels, to recalibrate them (default: 50 1500 40000 800000)")
	command.set_defaults(generate=iau2006)
	args = parser.parse_args()
	try:
		args.generate(args)
	except DataError as error:
		sys.exit(f"error: {error}")


if __name__ == "__main__":
	main()
