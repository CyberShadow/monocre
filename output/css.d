module monocre.output.css;

import std.array;
import std.format;

import monocre.output;
import monocre.charimage;

void formatCSSColor(in ref CharImage.Color c, Sink sink)
{
	if (c.a == c.a.max)
		sink.formattedWrite!"#%02X%02X%02X"(c.r, c.g, c.b);
	else
		sink.formattedWrite!"rgba(%d,%d,%d,%f)"(c.r, c.g, c.b, c.a / 255.);
}

string formatCSSColor(in ref CharImage.Color c)
{
	auto a = appender!string;
	formatCSSColor(c, &a.put!(const(char)[]));
	return a.data;
}
