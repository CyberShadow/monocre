/**
 * Defines the result of a read operation.
 *
 * License:
 *   This Source Code Form is subject to the terms of
 *   the Mozilla Public License, v. 2.0. If a copy of
 *   the MPL was not distributed with this file, You
 *   can obtain one at http://mozilla.org/MPL/2.0/.
 *
 * Authors:
 *   Vladimir Panteleev <vladimir@thecybershadow.net>
 */

module monocre.charimage;

import std.traits;

import ae.utils.graphics.color;
import ae.utils.math;

/// OCR'd image
struct CharImage
{
	alias Color = BGRA;
	struct Char
	{
		dchar c; // when ==dchar.init, nothing was recognized at this position
		Color bg, fg;
		string variant;
		bool opCast(T : bool)() const { return c != dchar.init; }
	}

	struct Layer
	{
		sizediff_t x0, y0;
		size_t w, h;
		Char[][] chars;
	}
	Layer[] layers;
}

alias ParsedVariant(Variant) = TypeForBits!(EnumMembers!Variant.length);

ParsedVariant!Variant parseVariant(Variant)(string str)
if (is(Variant == enum))
{
	import std.algorithm.iteration : map, fold;
	import std.array : split;
	import std.conv : to, ConvException;
	import std.stdio : stderr;

	alias R = typeof(return);

	static R[typeof(str.ptr)] cache;
	return cache.require(
		str.ptr,
		str.split(",").map!(
			(name)
			{
				try
					return cast(R)(1 << name.to!Variant);
				catch (ConvException e)
				{
					stderr.writefln("monocre: Warning: Ignoring unknown variant %s", name);
					return R(0);
				}
			}
		)
		.fold!((a, b) => a |= b)(R(0))
	);
}

unittest
{
	enum Variant { a, b }
	assert(parseVariant!Variant("a,b") == 3);
}
