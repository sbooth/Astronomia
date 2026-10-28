//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// Errors that can occur when reading a text PCK, a SPICE planetary constants kernel.
public enum PCKError: Error, Hashable, Sendable {
	/// The file couldn't be opened or mapped into memory, with the system's error number, an
	/// `errno` value such as `ENOENT` if the file doesn't exist. Files can't be mapped on
	/// platforms other than Apple's and Linux, where the number is `ENOSYS`; read the file's
	/// text and create the PCK from it instead.
	case cannotOpenFile(errno: Int32)
	/// The file is a binary kernel, as a binary PCK of the orientation of the Earth or the
	/// Moon, which isn't read, or an SPK file.
	case binaryKernel
	/// The file's data can't be read, with the number of the line, from 1, where it fails, or
	/// where an assignment that doesn't end starts.
	case invalidSyntax(line: Int)
}
