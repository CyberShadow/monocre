module monocre.read;

import std.algorithm.iteration;
import std.algorithm.mutation;
import std.array;
import std.exception;
import std.range.primitives;
import std.stdio : stderr;

import ae.utils.aa;
import ae.utils.array;
import ae.utils.math;

import monocre.charimage;
import monocre.font;

CharImage read(Image)(Image image, in ref Font font)
{
	auto fontGlyphSize = (font.w * font.h + 7) / 8;
	auto glyphBuf = new ubyte[fontGlyphSize];

	static struct Glyph
	{
		string variant;
		dchar c;
		bool reverse;
	}
	Glyph[ubyte[]] lookup;

	foreach (variant, glyphs; font.glyphs)
		foreach (c, bits; glyphs)
			foreach (reverse; [false, true])
			{
				auto lookupBits = reverse
					? bits.invertGlyph(fontGlyphSize)
					: bits;
				auto g = Glyph(variant, c, reverse);
				auto p = lookupBits in lookup;
				if (!p)
					lookup[lookupBits.idup] = g;
				else if (p.c > g.c)
					*p = g;
			}

	CharImage.Layer bestLayer;
	size_t bestScore;

	foreach (y0; 0 .. font.h)
		foreach (x0; 0 .. font.w)
		{
			CharImage.Layer layer;
			layer.x0 = x0;
			layer.y0 = y0;
			layer.w = font.w;
			layer.h = font.h;

			auto cw = (image.w - x0) / font.w;
			auto ch = (image.h - y0) / font.h;
			foreach (cy; 0 .. ch)
				charLoop:
				foreach (cx; 0 .. cw)
				{
					CharImage.Color[2] colors;
					size_t nColors;
					glyphBuf[] = 0;

					size_t bit;
					auto cx0 = x0 + cx * font.w;
					auto cy0 = y0 + cy * font.h;
					foreach (j; 0 .. font.h)
						foreach (i; 0 .. font.w)
						{
							auto c = image[cx0 + i, cy0 + j];
							size_t ci;
							if (nColors > 0 && c == colors[0])
								ci = 0;
							else
							if (nColors > 1 && c == colors[1])
								ci = 1;
							else
							if (nColors == colors.length)
								continue charLoop; // Too many colors!
							else
								colors[ci = nColors++] = c;

							glyphBuf[bit / 8] |= ci << (bit % 8);
							bit++;
						}

					auto g = glyphBuf in lookup;
					if (g)
					{
						if (nColors == 1)
							colors[1] = colors[0];
						if (g.reverse)
							swap(colors[0], colors[1]);
						layer.chars.getExpand(cy).getExpand(cx) = CharImage.Char(g.c, colors[0], colors[1], g.variant);
					}
				}

			auto score = getScore(layer);
			if (score > bestScore)
			{
				stderr.writefln("monocre: New best offset: %d,%d (score=%d)",
					x0, y0, score);
				bestScore = score;
				bestLayer = layer;
			}
		}

	enforce(bestScore, "No characters found!");

	CharImage result;
	result.layers = [bestLayer];
	return result;
}

inout(ubyte)[] invertGlyph(inout(ubyte)[] inBits, size_t fontGlyphSize) pure
{
	auto bits = inBits.dup;
	foreach (i, ref b; bits)
		b = flipBits(b);
	if (fontGlyphSize % 8)
		bits[fontGlyphSize / 8] &= (1 << fontGlyphSize % 8) - 1;
	return bits;
}

private:

size_t getScore(in ref CharImage.Layer layer)
{
	return layer.chars
		.map!(line => line[])
		.joiner
		.map!(c => c.c == dchar.init ? 0 : c.bg == c.fg ? 1 : 100)
		.walkLength;
}

unittest
{
	if (false)
	{
		import ae.utils.graphics.image : viewBMP;
		Font font;
		read(viewBMP!(CharImage.Color)((void[]).init), font);
	}
}
