//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

#ifndef CASTRONOMIAFILE_H
#define CASTRONOMIAFILE_H

#include <stddef.h>

// Read-only memory mappings of files, for ephemeris kernels too large to read into memory.

/// A read-only mapping of a file into memory.
struct astronomia_mapped_file {
	/// The file's bytes, or `NULL` for an empty file.
	const void *bytes;
	/// The number of bytes.
	size_t size;
};

/// Maps a file into memory, read-only.
///
/// The file is mapped privately, so changes to it after it is mapped may or may not be seen.
/// Mappings are supported on POSIX systems, as Apple's platforms and Linux; elsewhere the
/// function fails with `ENOSYS`.
///
/// - Parameters:
///   - path: The file's path, in UTF-8.
///   - file: The mapping, set only if the file is mapped.
/// - Returns: 0 if the file is mapped, or else an `errno` value: `ENOENT` if the file doesn't
///   exist, `EACCES` if it can't be read, `EISDIR` if it is a directory, `EFBIG` if it is too
///   large to map, or another error of `open`, `fstat`, or `mmap`.
int astronomia_map_file(const char *path, struct astronomia_mapped_file *file);

/// Unmaps a file mapped by `astronomia_map_file`.
///
/// - Parameter file: The mapping.
void astronomia_unmap_file(struct astronomia_mapped_file file);

#endif
