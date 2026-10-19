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
      truncation near 0.5 mas, or below the solution's own error.

      Each term is written as its phase at J2000.0 and frequency, the sums of its integer
      multipliers times the mean longitudes and mean motions of VSOP2013.f, in the same order
      and precision, followed by its sine and cosine coefficients. The mean motion term of
      the mean longitude is left out, as VSOP2013.f leaves it out; the evaluator adds the
      body's mean motion separately.

Example:

  Scripts/generate-ephemeris-data.py vsop2013 VSOP2013/solution \\
      --output Sources/AstronomiaData/VSOP2013

Run a command with --help for its options.
"""

import argparse
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
	os.makedirs(args.output, exist_ok=True)
	summary = []
	for body, name in enumerate(BODIES):
		path = os.path.join(args.directory, f"VSOP2013p{body + 1}.dat")
		with open(path, "rb") as file:
			digest = hashlib.sha256(file.read()).hexdigest()
		series = read_series(path, body)

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
			kept = [term for term in terms if (term[1] ** 2 + term[2] ** 2) ** 0.5 * scale >= thresholds[body]]
			if kept:
				kept_series.append((variable, power, len(kept)))
				kept_terms += kept

		symbol = "astronomia_vsop2013_" + re.sub(r"(?<!^)(?=[A-Z])", "_", name).lower()
		lines = list(SPDX_HEADER)
		lines += [
			"// Generated by Scripts/generate-ephemeris-data.py vsop2013. Do not edit.",
			f"// Source: VSOP2013p{body + 1}.dat, https://ftp.imcce.fr/pub/ephem/planets/vsop2013/solution/",
			f"// SHA-256: {digest}",
			f"// {name}: {len(kept_terms):,} of {total:,} terms, threshold {thresholds[body]:g}, "
			f"J{args.start:g} to J{args.end:g}",
			"",
			'#include "AstronomiaData.h"',
			"",
			"// Variable (1 to 6 for a, λ, k, h, q, p), power of time, and number of terms",
			"static const struct astronomia_vsop_series series[] = {",
		]
		for variable, power, count in kept_series:
			lines.append(f"\t{{{variable}, {power:2}, {count:6}}}, // {VARIABLES[variable - 1]} T^{power}")
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
			f"const struct astronomia_vsop_series_set {symbol} = {{",
			"\tsizeof(series) / sizeof(series[0]), series,",
			"\tsizeof(terms) / sizeof(terms[0]), terms,",
			"};",
			"",
		]
		with open(os.path.join(args.output, f"VSOP2013{name}.c"), "w") as file:
			file.write("\n".join(lines))
		summary.append(f"{name}: {len(kept_terms):,} of {total:,} terms")
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
	command.set_defaults(generate=vsop2013)
	args = parser.parse_args()
	try:
		args.generate(args)
	except DataError as error:
		sys.exit(f"error: {error}")


if __name__ == "__main__":
	main()
