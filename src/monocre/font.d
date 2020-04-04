/**
 * Defines the type holding a learned font.
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

module monocre.font;

import std.algorithm.iteration;
import std.algorithm.sorting;
import std.array;
import std.base64;
import std.conv;
import std.exception;
import std.file;
import std.typecons;

import ae.sys.file;
import ae.utils.aa;
import ae.utils.json;

struct Font
{
	size_t w, h;

	ubyte[][dchar][string] glyphs;
}

Font loadFont(string fontPath)
{
	return fontPath.readText.jsonParse!JsonFont.toFont();
}

void saveFont(ref Font font, string fontPath)
{
	fontPath.atomicWrite(JsonFont.fromFont(font).toPrettyJson);
}

struct JsonFont
{
	size_t width, height;

	OrderedMap!(string, string)[string] glyphs;

	static JsonFont fromFont(Font font)
	{
		return JsonFont(
			font.w, font.h,
			font.glyphs.byKeyValue.map!(kvVariant =>
				tuple(kvVariant.key,
					kvVariant.value.byKeyValue
					.array
					.sort!((a, b) => a.key < b.key)
					.map!(kvGlyph =>
						tuple(kvGlyph.key.to!string, Base64.encode(kvGlyph.value).assumeUnique)
					)
					.orderedMap
				)
			)
			.assocArray
		);
	}

	Font toFont()
	{
		return Font(
			width, height,
			glyphs.byKeyValue.map!(kvVariant =>
				tuple(kvVariant.key,
					kvVariant.value.byKeyValue.map!(kvGlyph =>
						tuple(kvGlyph.key.to!dchar, Base64.decode(kvGlyph.value))
					)
					.assocArray
				)
			)
			.assocArray
		);
	}
}
