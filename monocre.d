import std.algorithm.iteration;
import std.algorithm.searching;
import std.array;
import std.conv;
import std.format;
import std.range;
import std.traits;
import std.typecons;

import ae.utils.array;
import ae.utils.funopt;
import ae.utils.main;

import learn : learn;

enum OutputFormat
{
	plain,
	ansi,
	html,
	svg,
}

struct Actions
{
static:
	@(`Learn a new font using a given renderer program.

The renderer program should read UTF-8-encoded text from standard input,
and produce a 1-bit Windows bitmap with a rendering of the text.
Space (U+0020) and line feed (U+000A) characters are expected to work as usual.

The learned font is written to the path specified by FONT-PATH.
If the file exists, the new information is merged with the old one,
allowing to update the font with new glyphs.`)
	void learn(
		string fontPath,
		string renderer, string[] rendererArgs = null,
		Option!(string, "Range of characters (Unicode code points).\n" ~
			"Example: \"32-126,1024-1279\" (ASCII + Cyrillic)\n" ~
			"Example: \"U+2580-U+259F\" (Block Elements)\n" ~
			"Default: \"32-126\" (ASCII)", "RANGE") chars = "32-127",
	)
	{
		dchar[] charList = chars.value
			.split(",")
			.map!((r) {
				auto parts = r.findSplit("-");
				uint start, end;
				uint parse(string s) { return s.skipOver("0x") || s.skipOver("U+") ? s.to!uint(16) : s.to!uint; }
				if (parts[1].length)
					list(start, end) = tuple(parse(parts[0]), parse(parts[2]));
				else
					start = end = parts[0].to!uint;
				return iota(start, end + 1);
			})
			.joiner
			.map!(n => dchar(n))
			.array;

		.learn(
			fontPath,
			renderer ~ rendererArgs,
			charList,
		);
	}

	@(`Recognize characters in an image using a learned font.

The image should be specified as a 24-bit or 32-bit Windows bitmap on standard input.`)
	void read(
		Parameter!(string, "Path to a font created by the \"learn\" action.") fontPath,
		Option!(OutputFormat, "Output format.\n" ~
			"Options: " ~ [EnumMembers!OutputFormat].format!"%-(%s, %)" ~ "\n" ~
			"Default: plain", "FORMAT") outputFormat = OutputFormat.plain,
	)
	{
		// outputs:
		// - plain text
		// - ANSI
		// - HTML
		// - SVG
	}
}

void monocre(string[] args)
{
	funoptDispatch!Actions(args);
}

mixin main!monocre;
