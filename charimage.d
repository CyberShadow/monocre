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
	import std.algorithm.iteration : map, reduce;
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
		.reduce!((a, b) => a |= b)
	);
}

unittest
{
	enum Variant { a, b }
	assert(parseVariant!Variant("a,b") == 3);
}
