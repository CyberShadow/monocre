module monocre.monocre;

import std.algorithm.iteration;
import std.algorithm.searching;
import std.array;
import std.conv;
import std.exception;
import std.file;
import std.format;
import std.process;
import std.range;
import std.stdio;
import std.traits;
import std.typecons;

import ae.sys.file;
import ae.utils.array;
import ae.utils.funopt;
import ae.utils.graphics.image;
import ae.utils.main;
import ae.utils.path;

import monocre.charimage;
import monocre.font;
import monocre.learn : learn;
import monocre.output.ansi;
import monocre.output.html;
import monocre.output.plain;
import monocre.output.svg;
import monocre.read : read;

enum OutputFormat
{
	plain,
	ansi256,
	ansiRGB,
	html,
	svg,
}

struct Monocre
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
		Option!(string, "The variant that will be rendered (e.g. underline)") variant = null,
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

		Font font;
		if (fontPath.exists)
		{
			stderr.writefln("monocre: Loading existing font from %s...", fontPath);
			font = fontPath.loadFont();
		}
		else
			stderr.writefln("monocre: Font file %s does not exist, will create new font.", fontPath);

		auto render(in char[] text, bool silent)
		{
			version (Posix)
			{
				import core.sys.posix.signal;
				signal(SIGPIPE, SIG_IGN);
			}

			auto stdin = pipe();
			auto stdout = pipe();
			auto stderr = silent ? File(nullFileName, "wb") : .stderr;
			auto pid = spawnProcess(renderer ~ rendererArgs, stdin.readEnd, stdout.writeEnd, stderr);
			stdin.writeEnd.rawWrite(text);
			stdin.writeEnd.close();
			auto data = readFile(stdout.readEnd);
			enforce(wait(pid) == 0, "Renderer command exited with non-zero status");
			return data.viewBMP!bool;
		}

		.learn(
			font,
			variant,
			&render,
			charList,
		);

		saveFont(font, fontPath);
		stderr.writefln("monocre: Font file %s written.", fontPath);
	}

	@("Recognize characters in an image using a learned font.\n\n" ~
		"The image should be specified as a 32-bit Windows bitmap on standard input.")
	void read(
		Parameter!(string, "Path to a font created by the \"learn\" action.") fontPath,
		Option!(OutputFormat, "Output format.\n" ~
			"Options: " ~ [EnumMembers!OutputFormat].format!"%-(%s, %)" ~ "\n" ~
			"Default: plain", "FORMAT") outputFormat = OutputFormat.plain,
	)
	{
		auto image = stdin.readFile.viewBMP!(CharImage.Color);
		auto font = fontPath.loadFont();
		auto charImage = .read(image, font);

		final switch (outputFormat)
		{
			case OutputFormat.plain:
				outputPlain(charImage, &stdout.write!string);
				break;
			case OutputFormat.ansi256:
				assert(false, "TODO");
			case OutputFormat.ansiRGB:
				outputANSI(charImage, &stdout.write!string, &formatRGBColor);
				break;
			case OutputFormat.html:
				outputHTML(charImage, &stdout.write!string);
				break;
			case OutputFormat.svg:
				outputSVG(charImage, &stdout.write!string);
				break;
		}
	}
}

void entry(string[] args)
{
	funoptDispatch!Monocre(args);
}

mixin main!entry;
