#!/usr/bin/env python3
#
# SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
# SPDX-License-Identifier: MIT
#
# Part of https://github.com/sbooth/Astronomia
#

"""Generates C source for Astronomia's built-in star data from published catalogs.

The data is written as C arrays, which the C compiler turns into read-only data in seconds.
Values are written as hexadecimal floating-point literals, so they are exact.

Commands:

  named-stars NAMES HIPPARCOS BSC
      The stars with names approved by the IAU Working Group on Star Names (WGSN) that are in
      Hipparcos, with the astrometry of Hipparcos, the New Reduction (van Leeuwen 2007), and
      the radial velocities of the Bright Star Catalogue, 5th Revised Ed. (Hoffleit and
      Warren 1991). Writes NamedStars.c to the output directory.

      NAMES is the WGSN's IAU Catalog of Star Names as CSV, exported from
      https://exopla.net/star-names/modern-iau-star-names/. HIPPARCOS is hip2.dat, or
      hip2.dat.gz, of CDS catalog I/311, and BSC is catalog, or catalog.gz, of CDS catalog
      V/50.

      A name is kept when it has a Hipparcos number that is in hip2.dat. Its star is given by
      the right ascension, declination, parallax, and proper motions of hip2.dat, in the ICRS
      at epoch J1991.25, as written there; a parallax that isn't positive is written as 0,
      for none. Hipparcos's accelerations of the 7- and 9-parameter solutions are left out.

      The star's Bright Star number is that of its designation, if the designation is an HR
      number, or else that of the Bright Star Catalogue star within the match radius of the
      Hipparcos place, moved to J2000.0, whose V magnitude is nearest the Hipparcos magnitude
      and within the match tolerance, if every other such star's is farther by the match
      margin; the components of a double star may match neither. A designated HR number whose
      star is farther than the match radius is an error. A few designations of the CSV are
      corrected first, as the script notes. The radial velocity is that of the Bright
      Star Catalogue, in whole kilometers per second, or 0 if the star has none there.

      The stars are written in order of their names, compared without diacritics or case, with
      each name's ASCII form, without its diacritics, for lookups.

Examples:

  Scripts/generate-star-data.py named-stars IAU-Catalog_of_Star_Names.csv hip2.dat.gz \\
      catalog.gz --output Sources/CAstronomiaData/Stars

Run a command with --help for its options.
"""

import argparse
import csv
import gzip
import hashlib
import math
import os
import re
import sys
import unicodedata

SPDX_HEADER = [
	"//",
	"// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>",
	"// SPDX-License-Identifier: MIT",
	"//",
	"// Part of https://github.com/sbooth/Astronomia",
	"//",
	"",
]

# The columns of the WGSN's CSV export, by header.
NAME_COLUMNS = {
	"name": "proper names",
	"designation": "Designation",
	"hip": "HIP",
	"bayer": "Bayer ID",
	"constellation": "Constellation",
	"date": "Date of Adoption",
}

MATCH_RADIUS = 60.0  # arcseconds
MATCH_MAGNITUDE = 1.5
MATCH_MARGIN = 0.3  # magnitudes

# Corrections of the WGSN's CSV export, by name, checked against the Bright Star Catalogue and
# Hipparcos: the Hipparcos number is right, and the HR number of the designation isn't.
CORRECTIONS = {
	# ε And is HR 163, 1" from HIP 3031; HR 671 is HD 14213, 26° away.
	"Anunitu": {"designation": "HR 163"},
	# 112 Psc is HR 582, 1" from HIP 9353; HR 7203 is HD 176884, 104° away.
	"Zibbatu": {"designation": "HR 582"},
}
HIPPARCOS_EPOCH = 1991.25
ARCSECONDS_PER_RADIAN = 180 * 3600 / math.pi


def fail(message: str) -> None:
	sys.exit(f"error: {message}")


def open_text(path: str, encoding: str = "ascii"):
	if path.endswith(".gz"):
		return gzip.open(path, "rt", encoding=encoding, newline="")
	return open(path, "r", encoding=encoding, newline="")


def digest(path: str) -> str:
	with open(path, "rb") as file:
		return hashlib.sha256(file.read()).hexdigest()


def ascii_name(name: str) -> str:
	"""The name without diacritics, as for a lookup typed without them."""
	decomposed = unicodedata.normalize("NFKD", name)
	folded = "".join(character for character in decomposed if not unicodedata.combining(character))
	if not folded.isascii():
		fail(f"no ASCII form of the name {name!r}")
	return folded


def field(line: str, first: int, last: int) -> str:
	"""The bytes first to last, numbered from 1, of a fixed-width record, stripped."""
	return line[first - 1:last].strip()


def read_names(path: str) -> list[dict[str, str]]:
	with open_text(path, "utf-8-sig") as file:
		rows = list(csv.reader(file))
	if not rows:
		fail(f"{path}: empty")
	header = [re.sub(r"<[^>]*>", "", cell).strip().lower() for cell in rows[0]]
	indexes = {}
	for key, title in NAME_COLUMNS.items():
		if title.lower() not in header:
			fail(f"{path}: no column {title!r}")
		indexes[key] = header.index(title.lower())
	names = []
	for number, row in enumerate(rows[1:], start=2):
		if not any(cell.strip() for cell in row):
			continue
		if len(row) != len(header):
			fail(f"{path}:{number}: {len(row)} columns, not {len(header)}")
		entry = {key: unicodedata.normalize("NFC", row[index].strip()) for key, index in indexes.items()}
		if not entry["name"]:
			fail(f"{path}:{number}: no name")
		if re.search(r"[<>&]", "".join(entry.values())):
			fail(f"{path}:{number}: markup in {entry}")
		if entry["hip"] and not entry["hip"].isdigit():
			fail(f"{path}:{number}: Hipparcos number {entry['hip']!r}")
		if not re.fullmatch(r"[A-Z][A-Za-z]{2}", entry["constellation"]):
			fail(f"{path}:{number}: constellation {entry['constellation']!r}")
		names.append(entry)
	seen = set()
	for entry in names:
		if entry["name"] in seen:
			fail(f"{path}: the name {entry['name']!r} is repeated")
		seen.add(entry["name"])
	return names


def read_hipparcos(path: str) -> dict[int, dict[str, float]]:
	stars = {}
	with open_text(path) as file:
		for number, line in enumerate(file, start=1):
			line = line.rstrip("\r\n")
			if not line:
				continue
			if len(line) != 276:
				fail(f"{path}:{number}: {len(line)} bytes, not 276")
			hip = int(field(line, 1, 6))
			stars[hip] = {
				"ra": float(field(line, 16, 28)),
				"dec": float(field(line, 30, 42)),
				"plx": float(field(line, 44, 50)),
				"pmra": float(field(line, 52, 59)),
				"pmdec": float(field(line, 61, 68)),
				"hp": float(field(line, 130, 136)),
			}
	if len(stars) != 117955:
		fail(f"{path}: {len(stars)} stars, not 117,955")
	return stars


def read_bsc(path: str) -> dict[int, dict[str, float | None]]:
	stars = {}
	with open_text(path) as file:
		for number, line in enumerate(file, start=1):
			line = line.rstrip("\r\n")
			if not line:
				continue
			line = line.ljust(197)
			hr = int(field(line, 1, 4))
			if not field(line, 76, 77):
				continue  # removed from the catalog
			ra = (int(field(line, 76, 77)) + int(field(line, 78, 79)) / 60 + float(field(line, 80, 83)) / 3600) * 15
			dec = int(field(line, 85, 86)) + int(field(line, 87, 88)) / 60 + int(field(line, 89, 90)) / 3600
			if field(line, 84, 84) == "-":
				dec = -dec
			vmag = field(line, 103, 107)
			rv = field(line, 167, 170)
			stars[hr] = {
				"ra": math.radians(ra),
				"dec": math.radians(dec),
				"v": float(vmag) if vmag else None,
				"rv": float(int(rv)) if rv else None,
			}
	if len(stars) != 9096:
		fail(f"{path}: {len(stars)} stars, not 9,096")
	return stars


def separation(ra1: float, dec1: float, ra2: float, dec2: float) -> float:
	"""The angle between two directions, in arcseconds."""
	a = math.sin((dec2 - dec1) / 2) ** 2 + math.cos(dec1) * math.cos(dec2) * math.sin((ra2 - ra1) / 2) ** 2
	return 2 * math.asin(min(1, math.sqrt(a))) * ARCSECONDS_PER_RADIAN


def place_at_j2000(star: dict[str, float]) -> tuple[float, float]:
	"""The Hipparcos place moved to J2000.0 by its proper motion, to first order."""
	years = 2000 - HIPPARCOS_EPOCH
	dec = star["dec"] + star["pmdec"] * years / 1000 / ARCSECONDS_PER_RADIAN
	ra = star["ra"] + star["pmra"] * years / 1000 / ARCSECONDS_PER_RADIAN / math.cos(star["dec"])
	return ra, dec


def bright_star_match(ra: float, dec: float, hp: float, bsc: dict[int, dict[str, float | None]], args: argparse.Namespace) -> tuple[int | None, bool]:
	"""The HR number of the Bright Star Catalogue star that is the Hipparcos star, or None, and
	whether there were candidates but no match.

	The candidates are the stars within the match radius of the Hipparcos place at J2000.0
	whose V magnitude is within the match tolerance of the Hipparcos magnitude. The match is
	the candidate whose magnitude is nearest, if every other's is farther by at least the
	margin, as the components of a double star, a few arcseconds apart, may not be.
	"""
	candidates = []
	for number, star in bsc.items():
		if star["v"] is None or abs(star["v"] - hp) > args.match_magnitude:
			continue
		if separation(ra, dec, star["ra"], star["dec"]) <= args.match_radius:
			candidates.append((abs(star["v"] - hp), number))
	candidates.sort()
	if not candidates:
		return None, False
	if len(candidates) > 1 and candidates[1][0] - candidates[0][0] < args.match_margin:
		return None, True
	return candidates[0][1], False


def c_string(text: str) -> str:
	return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


def c_double(value: float) -> str:
	return value.hex()


def named_stars(args: argparse.Namespace) -> None:
	names = read_names(args.names)
	hipparcos = read_hipparcos(args.hipparcos)
	bsc = read_bsc(args.bsc)

	stars = []
	missing = []
	unmatched = []
	for entry in names:
		if not entry["hip"]:
			continue
		hip = int(entry["hip"])
		if hip not in hipparcos:
			missing.append(entry)
			continue
		star = hipparcos[hip]
		ra, dec = place_at_j2000(star)
		entry = dict(entry, **CORRECTIONS.get(entry["name"], {}))
		designated = re.fullmatch(r"HR (\d+)", entry["designation"])
		hr = None
		if designated:
			hr = int(designated.group(1))
			if hr not in bsc:
				fail(f"{entry['name']}: HR {hr} isn't in the Bright Star Catalogue")
			distance = separation(ra, dec, bsc[hr]["ra"], bsc[hr]["dec"])
			if distance > args.match_radius:
				fail(f"{entry['name']}: HR {hr} is {distance:.0f}\" from HIP {hip}")
		else:
			hr, ambiguous = bright_star_match(ra, dec, star["hp"], bsc, args)
			if ambiguous:
				unmatched.append(entry)
		rv = bsc[hr]["rv"] if hr is not None else None
		stars.append({
			"name": entry["name"],
			"ascii": ascii_name(entry["name"]),
			"designation": entry["designation"],
			"bayer": entry["bayer"],
			"constellation": entry["constellation"],
			"hip": hip,
			"hr": hr or 0,
			"ra": star["ra"],
			"dec": star["dec"],
			"plx": star["plx"] if star["plx"] > 0 else 0.0,
			"pmra": star["pmra"],
			"pmdec": star["pmdec"],
			"rv": rv or 0.0,
			"hp": star["hp"],
		})
	stars.sort(key=lambda star: (star["ascii"].casefold(), star["name"]))
	keys = [star["ascii"].casefold() for star in stars]
	if len(set(keys)) != len(keys):
		fail("two names are the same without diacritics or case")

	for entry in missing:
		print(f"note: {entry['name']}: HIP {entry['hip']} isn't in hip2.dat", file=sys.stderr)
	for entry in unmatched:
		print(f"note: {entry['name']}: {entry['designation']} matches more than one star of the Bright Star Catalogue", file=sys.stderr)
	without_hip = sum(1 for entry in names if not entry["hip"])
	with_hr = sum(1 for star in stars if star["hr"])
	with_rv = sum(1 for star in stars if star["rv"])
	print(f"{len(stars)} of {len(names)} names; {without_hip} without a Hipparcos number, {len(missing)} not in hip2.dat; {with_hr} with an HR number, {with_rv} with a radial velocity", file=sys.stderr)

	lines = list(SPDX_HEADER)
	lines.append("// Generated by Scripts/generate-star-data.py named-stars. Do not edit.")
	lines.append("// Sources:")
	lines.append("//   IAU Catalog of Star Names, IAU Division C Working Group on Star Names (WGSN),")
	lines.append("//     https://exopla.net/star-names/modern-iau-star-names/")
	lines.append("//   Hipparcos, the New Reduction (van Leeuwen 2007), CDS I/311")
	lines.append("//   Bright Star Catalogue, 5th Revised Ed. (Hoffleit and Warren 1991), CDS V/50")
	for path in (args.names, args.hipparcos, args.bsc):
		lines.append(f"// SHA-256 {digest(path)}  {os.path.basename(path)}")
	latest = max(entry["date"] for entry in names)
	lines.append(f"// {len(stars)} of {len(names)} names, the latest adopted {latest}")
	lines.append("")
	lines.append('#include "CAstronomiaData.h"')
	lines.append("")
	lines.append("// Name, ASCII name, designation, Bayer or Flamsteed designation, constellation, HIP, HR,")
	lines.append("// right ascension and declination (radians), parallax (mas), proper motions in right")
	lines.append("// ascension times the cosine of the declination and in declination (mas/yr), radial")
	lines.append("// velocity (km/s), Hipparcos magnitude")
	lines.append("static const struct astronomia_named_star stars[] = {")
	for star in stars:
		strings = ", ".join(c_string(star[key]) for key in ("name", "ascii", "designation", "bayer", "constellation"))
		values = ", ".join(c_double(star[key]) for key in ("ra", "dec", "plx", "pmra", "pmdec", "rv", "hp"))
		lines.append(f"\t{{{strings}, {star['hip']}, {star['hr']}, {values}}},")
	lines.append("};")
	lines.append("")
	lines.append("const struct astronomia_named_star_data astronomia_named_stars = {")
	lines.append(f"\t{len(stars)},")
	lines.append("\tstars,")
	lines.append("};")
	os.makedirs(args.output, exist_ok=True)
	with open(os.path.join(args.output, "NamedStars.c"), "w", encoding="utf-8", newline="\n") as file:
		file.write("\n".join(lines) + "\n")


def main() -> None:
	parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	commands = parser.add_subparsers(dest="command", required=True)
	command = commands.add_parser("named-stars", help="the stars named by the IAU that are in Hipparcos")
	command.add_argument("names", help="the IAU Catalog of Star Names, as CSV")
	command.add_argument("hipparcos", help="hip2.dat or hip2.dat.gz of CDS I/311")
	command.add_argument("bsc", help="catalog or catalog.gz of CDS V/50")
	command.add_argument("--output", required=True, help="the directory to write NamedStars.c to")
	command.add_argument("--match-radius", type=float, default=MATCH_RADIUS, metavar="ARCSECONDS", help=f"the greatest distance of a Bright Star Catalogue star from the Hipparcos place at J2000.0 (default: {MATCH_RADIUS:g})")
	command.add_argument("--match-magnitude", type=float, default=MATCH_MAGNITUDE, metavar="MAGNITUDES", help=f"the greatest difference of the V magnitude of a star matched by place from its Hipparcos magnitude (default: {MATCH_MAGNITUDE:g})")
	command.add_argument("--match-margin", type=float, default=MATCH_MARGIN, metavar="MAGNITUDES", help=f"the least amount by which the magnitude of every other candidate must be farther from the Hipparcos magnitude than the match's (default: {MATCH_MARGIN:g})")
	command.set_defaults(function=named_stars)
	args = parser.parse_args()
	args.function(args)


if __name__ == "__main__":
	main()
