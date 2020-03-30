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
	size_t[2] good = [gridPatternW, gridPatternH], bad = [size_t.max, size_t.max];
	{
		stderr.writefln("monocre: Detecting renderer maximum size...");

		// When to keep searching on an axis
		bool farEnough(size_t good, size_t bad) { return bad == size_t.max || (good + 1 < bad && (bad - good) * 4 > bad); }

		while (((good[0] - 1) / 2) * ((good[1] - 1) / 2) < chars.length && // area covers all chars?
			(farEnough(good[0], bad[0]) || farEnough(good[1], bad[1]))) // both axes close enough?
		{
			foreach (axis; 0 .. 2)
			{
				if (!farEnough(good[axis], bad[axis]))
					continue;
				auto next = bad[axis] == size_t.max
					? good[axis] * 2
					: (good[axis] + bad[axis]) / 2;
				auto size = good;
				size[axis] = next;
				stderr.writef("monocre: Trying %d x %d... ", size[0], size[1]);
				try
				{
					foreach (value; only(false, true))
					{
						bool[][] pattern = [[value].replicate(size[0])].replicate(size[1]);
						auto tryImage = patternLines(pattern).render(renderer, false);
						enforce(checkSpec(tryImage, spec, pattern), only("Negative", "Positive")[value] ~ " test failed");
					}

					stderr.writeln("OK");
					good[axis] = next;
				}
				catch (Exception e)
				{
					stderr.writefln("Not OK (%s)", e.msg);
					bad[axis] = next;
				}
			}
		}
		if (chars.reduce!max >= 0x80)
		{
			// UTF-8-encoded Unicode characters may use more limit space
			// than the ASCII characters we tested above.
			// Ensure that there is room for these characters
			// by reducing our computed size.
			good[0] = max(gridPatternW, good[0] / 2);
			good[1] = max(gridPatternH, good[1] / 2);
		}
		stderr.writefln("monocre: Using %d x %d.", good[0], good[1], good);
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
