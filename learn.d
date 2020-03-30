module learn;

import std.algorithm.comparison;
import std.algorithm.iteration;
import std.algorithm.searching;
import std.exception;
import std.functional : not;
import std.process;
import std.range;
import std.stdio;
import std.uni;
import std.utf;

import ae.sys.file;
import ae.utils.graphics.image;
import ae.utils.path;

void learn(string fontPath, string[] renderer, dchar[] chars)
{
	enforce(chars.length, "Must specify at least one character to learn");

	// 1. Find grid (rough x0,y0 and character size)
	stderr.writeln("monocre: Detecting grid...");

	dchar narrowChar = chain(narrowChars.filter!(c => chars.canFind(c)), chars.filter!(not!isWhite).front.only).front;
	// Use a grid large enough so that it's not ambiguous with some random decoration,
	// but small enough that it does not exceed the rendered bitmap size.
	enum gridPatternW = 1 + 7 + 1;
	enum gridPatternH = 1 + 5 + 1;
	auto gridPattern =
		gridPatternH.iota.map!(j =>
			gridPatternW.iota.map!(i =>
				i > 0 && i + 1 < gridPatternW && j > 0 && j + 1 < gridPatternH && (i + 1) != j
			).array
		).array;
	dchar[][] patternLines(bool[][] pattern) { return pattern.map!(map!(cell => cell ? narrowChar : ' ')).map!array.array; }
	auto gridImage = patternLines(gridPattern)
		.array
		.render(renderer);

	static struct Spec
	{
		int x0, y0, w, h;
		Color bg, fg;
	}
	Spec[] specs;
	static bool checkSpec(OutputImage image, Spec spec, bool[][] pattern)
	{
		auto patternW = pattern[0].length;
		auto patternH = pattern   .length;

		enforce(spec.x0 + spec.w * (patternW - 1) < image.w, "Image width too small");
		enforce(spec.y0 + spec.h * (patternH - 1) < image.h, "Image height too small");

		if (spec.fg == spec.bg)
			return false; // invisible text on a solid background is unfalsifiable

		debug(learn_grid) stderr.writefln("monocre: Trying: x=%d y=%d w=%d h=%d bg=%s fg=%s", spec.tupleof);

		foreach (j; 0 .. patternH)
			foreach (i; 0 .. patternW)
			{
				auto x = spec.x0 + i * spec.w;
				auto y = spec.y0 + j * spec.h;
				auto color = image[cast(int)x, cast(int)y];
				auto expectedColor = pattern[j][i] ? spec.fg : spec.bg;
				if (color != expectedColor)
				{
					debug(learn_grid) stderr.writefln("monocre: Expected %s, found %s at char %d,%d pixel %d,%d",
						expectedColor, color, i, j, x, y);
					return false;
				}
			}
		return true;
	}

	foreach (x0; 0 .. gridImage.w)
		foreach (y0; 0 .. gridImage.h)
			foreach (w; 1 .. (gridImage.w - x0 - 1) / (gridPatternW - 1) + 1)
				foreach (h; 1 .. (gridImage.h - y0 - 1) / (gridPatternH - 1) + 1)
				{
					auto spec = Spec(x0, y0, w, h, gridImage[x0, y0], gridImage[x0 + w, y0 + h]);
					if (checkSpec(gridImage, spec, gridPattern))
					{
						stderr.writefln("monocre: Found grid: x=%d y=%d w=%d h=%d",
							spec.x0, spec.y0, spec.w, spec.h);
						specs ~= spec;
					}
				}

	enforce(specs.length, "Could not detect a character grid!");
	foreach (spec; specs)
		enforce(spec.w == specs[0].w && spec.h == specs[0].h,
			"Found grids with several distinct glyph sizes!");
	auto spec = specs[0];

	// 2. Find renderer limits
	int maxW, maxH;
	foreach (axis; 0 .. 2)
	{
		stderr.writefln("monocre: Detecting renderer maximum %s...", only("width", "height")[axis]);
		auto good = only(gridPatternW, 1)[axis];
		auto maxChars = chars.length * 2 + 1; // max. chars we'll want to put on one axis
		if (axis)
		{
			auto maxWChars = (maxW - 1) / 2; // undo maxChars calculation above
			maxChars = min(maxChars, (chars.length + maxWChars - 1) / maxWChars);
		}
		auto upperLimit = max(good, min(0x7fff / only(spec.w, spec.h)[axis] - 3, maxChars));
		upperLimit++; // one past, so that the first "next" is at the limit
		auto bad = upperLimit;
		while (good + 1 < bad && (bad - good) * 4 > bad)
		{
			auto next = bad == upperLimit ? upperLimit - 1 : (good + bad) / 2;
			stderr.writef("monocre: Trying %d... ", next);
			try
			{
				foreach (value; only(false, true))
				{
					bool[][] pattern;
					if (axis == 0) // X
						pattern = [[value].replicate(next)];
					else
						pattern = [[value].replicate(maxW)].replicate(next);
					auto tryImage = patternLines(pattern).render(renderer, false);
					enforce(checkSpec(tryImage, spec, pattern), only("Negative", "Positive")[value] ~ " test failed");
				}

				stderr.writeln("OK");
				good = next;
			}
			catch (Exception e)
			{
				stderr.writefln("Not OK (%s)", e.msg);
				bad = next;
			}
		}
		if (axis == 0)
		{
			// Be conservative, and leave the renderer enough "room" for vertical expansion
			// (when the limit is dictated by image area / memory).
			good = max(gridPatternW, good / 4);
		}
		stderr.writefln("monocre: Using maximum %s = %d.", only("width", "height")[axis], good);
		*only(&maxW, &maxH)[axis] = good;
	}

	// 3. Find real origin
	// if (image.w == spec.w * (1 + gridPatternW + 1) && image.h == spec.h * gridPatternH)
	// {
	// 	stderr.writefln("monocre: Image is exact size");
	// 	spec.x0 = spec.y0 = 0;
	// }
	// else
	// {
		
	// }

	// 3. find extents
	
}

private:

/// Some small (narrow) single-segment characters to use for the
/// initial detection.
immutable dchar[] narrowChars = ['.', 'l', '1'];

string formatInput(in dchar[][] lines)
{
	// Protect against whitespace trimming in rendering scripts
	return lines.map!(line => "|" ~ line ~ "|\n").join.toUTF8;
}

auto render(in dchar[][] lines, string[] renderer, bool showStderr = true)
{
	auto stdin = pipe();
	auto stdout = pipe();
	auto stderr = showStderr ? .stderr : File(nullFileName, "wb");
	auto pid = spawnProcess(renderer, stdin.readEnd, stdout.writeEnd, stderr);
	stdin.writeEnd.rawWrite(lines.formatInput);
	stdin.writeEnd.close();
	auto data = readFile(stdout.readEnd);
	enforce(wait(pid) == 0, "Renderer command exited with non-zero status");
	return data.viewBMP!bool;
}

alias OutputImage = typeof(render(null, null));
alias Color = ViewColor!OutputImage;
