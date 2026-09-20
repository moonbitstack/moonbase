// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// Why a string could not be decoded, and where.
///
/// Decoding fails for four reasons and each of them names the offending index,
/// because "it did not decode" is not enough to fix a malformed document. The
/// old spelling returned `None` and said nothing; callers who only want that
/// much can still write `try? decode(s)`.
pub(all) suberror Malformed {
  /// A character outside the alphabet, at this index.
  Bad(at~ : Int, char~ : Char)
  /// The input ends in the middle of a group.
  Truncated(at~ : Int)
  /// Padding where it cannot be, or too much of it.
  Padding(at~ : Int)
  /// A checksum that does not match what the payload says it should be.
  Checksum(at~ : Int)
} derive(Eq, Debug)

///|
pub extend Malformed with Eq::{equal, not_equal}

///|
pub extend Malformed with Debug::{to_repr}

///|
/// Why an alphabet could not be built.
///
/// Separate from [`Malformed`] on purpose: a malformed input is the caller's
/// data, a malformed alphabet is the caller's code.
pub(all) suberror BadAlphabet {
  /// A character that is not ASCII, at this index in the alphabet.
  NotAscii(at~ : Int, char~ : Char)
  /// A character that appears twice, which makes the mapping ambiguous.
  Repeated(at~ : Int, char~ : Char)
  /// Fewer than two digits, which is not a positional system.
  TooFew(count~ : Int)
} derive(Eq, Debug)

///|
pub extend BadAlphabet with Eq::{equal, not_equal}

///|
pub extend BadAlphabet with Debug::{to_repr}
