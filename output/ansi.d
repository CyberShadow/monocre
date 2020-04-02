module monocre.output.ansi;

import std.conv;
import std.format;

import monocre.charimage;

void outputANSI(in ref CharImage i, void delegate(string) sink, string function(CharImage.Color, bool fg) formatColor)
{
	foreach (layer; i.layers)
		foreach (y, row; layer.chars)
		{
			CharImage.Char last;
			foreach (x, c; row)
			{
				if (last.bg != c.bg)
					sink(c && c.bg.a ? formatColor(c.bg, false) : "\x1B[49m");
				if (last.fg != c.fg)
					sink(c && c.fg.a ? formatColor(c.fg, true ) : "\x1B[39m");
				sink(c ? c.c.to!string : " ");
			}
			sink("\x1B[39m\n");
		}
}

string formatRGBColor(CharImage.Color color, bool fg)
{
	return "\x1B[%d;2;%d;%d;%dm".format(
		fg ? 38 : 48, color.r, color.g, color.b);
}
