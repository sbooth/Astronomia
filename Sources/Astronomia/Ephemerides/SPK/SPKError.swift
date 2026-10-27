//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// Errors that can occur when reading an SPK file, the format of JPL's ephemerides.
public enum SPKError: Error, Hashable, Sendable {
	/// The file couldn't be opened or mapped into memory, with the system's error number, an
	/// `errno` value such as `ENOENT` if the file doesn't exist. Files can't be mapped on
	/// platforms other than Apple's and Linux, where the number is `ENOSYS`; read the file's
	/// bytes and create the kernel from them instead.
	case cannotOpenFile(errno: Int32)
	/// The data isn't an SPK file, or its structure is damaged, as a file cut short.
	case invalidFile
	/// The file's numbers aren't IEEE 754 binary, in either byte order, as for a file from a
	/// VAX.
	case unsupportedFormat
	/// The file was damaged in transfer, as by FTP in text mode, which changes its line
	/// endings.
	case damagedInTransfer
	/// The files don't give a body the ephemeris needs, relative to the solar system
	/// barycenter, with the body's NAIF ID.
	case missingBody(naifID: Int)
}
