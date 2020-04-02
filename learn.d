module learn;

import std.algorithm.comparison;
import std.algorithm.iteration;
import std.algorithm.searching;
import std.algorithm.sorting;
import std.array;
import std.conv;
import std.exception;
import std.file;
import std.format;
import std.functional : not;
import std.process;
import std.range;
import std.stdio;
import std.uni;
import std.utf;

import ae.sys.file;
import ae.utils.aa;
import ae.utils.array;
import ae.utils.graphics.image;
import ae.utils.path;

import common;

void learn(string fontPath, string variant, string[] renderer, dchar[] chars)
{
	enforce(chars.length, "Must specify at least one character to learn");
	chars.sort();

	Font font;
	if (fontPath.exists)
	{
		stderr.writefln("monocre: Loading existing font from %s...", fontPath);
		font = fontPath.loadFont();
	}
	else
		stderr.writefln("monocre: Font file %s does not exist, will create new font.", fontPath);

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
	size_t[2] maxSize;
	{
		size_t[2] good = [gridPatternW, gridPatternH], bad = [size_t.max, size_t.max];
		stderr.writefln("monocre: Detecting renderer maximum size...");

		// When to keep searching on an axis
		bool farEnough(size_t good, size_t bad) { return bad == size_t.max || (good + 1 < bad && (bad - good) * 4 > bad); }

		size_t targetArea = chars.length;
		// UTF-8-encoded Unicode characters may use more limit space
		// than the ASCII characters we tested above.
		// Ensure that there is room for these characters
		// by reducing our computed size.
		if (chars.reduce!max >= 0x80)
			targetArea *= 5;
		targetArea *= 3 * 3; // for the 3x3 pattern in the next step
		// Do not try to render more than 65535 characters at once
		targetArea = min(targetArea, 0xFFFF);
		// Do not try to render more pixels than 64K*64K
		targetArea = min(targetArea, (0x1_0000_0000 / (spec.w * spec.h)).to!size_t);

		while (good[0] * good[1] < targetArea && // area covers all chars?
			(farEnough(good[0], bad[0]) || farEnough(good[1], bad[1]))) // both axes close enough?
		{
			auto axis = good[0] < good[1] ? 0 : 1;
			if (!farEnough(good[axis], bad[axis]))
				axis = 1 - axis;

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
		stderr.writefln("monocre: Using %d x %d.", good[0], good[1]);
		maxSize = good;
	}

	// 3. Find origin / glyph bounds
	{
		stderr.writefln("monocre: Detecting origin / glyph bounds...");
		// Estimate initial bounds of the search window
		// from the positive matches we found from the grid detection.
		auto xMin = specs.map!(spec => spec.x0).reduce!max + 1 - spec.w;
		auto yMin = specs.map!(spec => spec.y0).reduce!max + 1 - spec.h;
		auto xMax = specs.map!(spec => spec.x0).reduce!min + 1;
		auto yMax = specs.map!(spec => spec.y0).reduce!min + 1;

		auto ww = xMax - xMin; // window width
		auto wh = yMax - yMin; // window height

		// Initial / remaining number of candidates
		size_t numOffsets = ww * wh;
		// Boolean matrix for tracking whether a candidate is viable
		auto candidateOffsets = new bool[numOffsets];
		candidateOffsets[] = true;

		// Split the rendered characters in batches,
		// and keep going until only one possibility remains
		// or we're out of characters.
		size_t pos;
		while (numOffsets > 1 && pos < chars.length)
		{
			// Render a grid of character, each character
			// repeating twice vertically and horizontally. I.e.:
			// AA BB CC ..
			// AA BB CC ..
			//          ..
			// DD EE FF ..
			// DD EE FF ..
			//          ..
			// ...........
			auto cw = cast(int)(maxSize[0] / 3);
			auto ch = cast(int)(maxSize[1] / 3);
			auto batchSize = min(cw * ch, chars.length - pos);
			auto batch = chars[pos .. pos + batchSize];
			pos += batchSize;
			stderr.writefln("monocre: Checking characters U+%04X through U+%04X...",
				uint(batch[0]), uint(batch[$-1]));

			// Draw the character matrix
			dchar[][] lines;
			foreach (cn, c; batch)
				foreach (j; 0 .. 3)
					foreach (i; 0 .. 3)
					{
						auto cx = (cn % cw) * 3 + i;
						auto cy = (cn / cw) * 3 + j;
						auto cc = i < 2 && j < 2 ? c : ' ';
						lines.getExpand(cy).getExpand(cx) = cc;
					}
			auto image = lines.render(renderer);

			// Test and exclude remaining candidate offsets
			foreach (wy; 0 .. wh)
				foreach (wx; 0 .. ww)
				{
					auto wn = wy * ww + wx; // candidate index
					if (candidateOffsets[wn])
					{
						// Image coordinates of the origin we're testing
						auto ix0 = xMin + wx;
						auto iy0 = yMin + wy;
					boundCheckLoop:
						foreach (cn; 0 .. batchSize)
						{
							// Grid coordinates of the top-left character we're testing
							auto cx0 = (cn % cw) * 3;
							auto cy0 = (cn / cw) * 3;
							// Image coordinates of the top-left character we're testing
							auto icx0 = ix0 + cx0 * spec.w;
							auto icy0 = iy0 + cy0 * spec.h;

							// Out-of-bounds means an automatic failure
							if (icx0 < 0 ||
								icy0 < 0 ||
								icx0 + spec.w * 3 > image.w ||
								icy0 + spec.h * 3 > image.h)
							{
								candidateOffsets[wn] = false;
								numOffsets--;
								break boundCheckLoop;
							}

							// Check every pixel in the character
							foreach (j; 0 .. spec.h)
								foreach (i; 0 .. spec.w)
								{
									auto p00 = image[icx0 + i         , icy0 + j         ];
									if (p00 != image[icx0 + i + spec.w, icy0 + j         ] ||
										p00 != image[icx0 + i         , icy0 + j + spec.h] ||
										p00 != image[icx0 + i + spec.w, icy0 + j + spec.h])
									{
										candidateOffsets[wn] = false;
										numOffsets--;
										break boundCheckLoop;
									}
								}
						}
					}
				}
		}

		enforce(numOffsets > 0, "Failed to detect an origin");

		auto workingOffsets = candidateOffsets.length
			.iota
			.filter!(index => candidateOffsets[index])
			.map!(index => [
					xMin + (index.to!int % ww),
					yMin + (index.to!int / ww),
				].staticArray)
			.array;
		assert(workingOffsets.length == numOffsets);

		if (numOffsets == 1)
			stderr.writefln("monocre: Found origin precisely.");
		else
		{
			stderr.writefln("monocre: Warning: Could not detect precise origin. Valid origins found are:");
			foreach (origin; workingOffsets)
				stderr.writefln("monocre: - %d,%d", origin[0], origin[1]);
			stderr.writefln("monocre: Consider adding a full-size character such as █");
			stderr.writefln("monocre: ('FULL BLOCK', U+2588) to the tested character set.");
		}
		spec.x0 = workingOffsets[0][0];
		spec.y0 = workingOffsets[0][1];
		stderr.writefln("monocre: Using origin at %d,%d.", spec.x0, spec.y0);
	}

	// 4. Record the font!

	auto fontGlyphSize = (spec.w * spec.h + 7) / 8;
	auto variantGlyphs = font.glyphs[variant] = font.glyphs.get(variant, null).nonNull;

	{
		stderr.writefln("monocre: Rendering characters...");

		// Split in patches as in step 3.
		for (size_t pos; pos < chars.length; )
		{
			auto cw = cast(int)(maxSize[0] - 1);
			auto ch = cast(int)(maxSize[1] - 1);
			auto batchSize = min(cw * ch, chars.length - pos);
			auto batch = chars[pos .. pos + batchSize];
			pos += batchSize;
			stderr.writefln("monocre: Rendering characters U+%04X through U+%04X...",
				uint(batch[0]), uint(batch[$-1]));

			// Draw the character matrix
			auto lines = (ch + 1)
				.iota
				.map!(cy =>
					(cw + 1)
					.iota
					.map!(cx =>
						cx < cw && cy < ch
						? batch.get(cy * cw + cx, ' ')
						: narrowChar
					)
					.array
				)
				.array;
			auto image = lines.render(renderer);

			auto batchBytes = new ubyte[fontGlyphSize * batchSize];

			// Record/check characters
			foreach (cy; 0 .. ch + 1)
				foreach (cx; 0 .. cw + 1)
				{
					auto ix0 = spec.x0 + cx * spec.w;
					auto iy0 = spec.y0 + cy * spec.h;
					if (cx < cw && cy < ch)
					{
						auto cn = cy * cw + cx;
						if (cn >= batchSize)
							continue;
						auto glyphBytes = batchBytes[cn * fontGlyphSize .. $][0 .. fontGlyphSize];
						size_t bit;
						foreach (j; 0 .. spec.h)
							foreach (i; 0 .. spec.w)
							{
								glyphBytes[bit / 8] |= image[ix0 + i, iy0 + j] << (bit % 8);
								bit++;
							}
						auto c = batch[cn];
						variantGlyphs[c] = glyphBytes;
					}
					else
					{
						// Check for narrowChar
						foreach (j; 0 .. spec.h)
							foreach (i; 0 .. spec.w)
								enforce(image[ix0 + i, iy0 + j] == gridImage[spec.x0 + spec.w + i, spec.y0 + spec.h + j],
									"Did not find control terminator pixel at %d,%d (caused by variable-width character?)"
									.format(ix0 + i, iy0 + j));
					}
				}
		}
	}

	saveFont(font, fontPath);
	stderr.writefln("monocre: Font file %s written.", fontPath);
}

private:

/// Some small (narrow) single-segment characters to use for the
/// initial detection.
immutable dchar[] narrowChars = ['.', 'l', '1'];

string formatInput(in dchar[][] lines)
{
	// Protect against whitespace trimming in rendering scripts
	return lines.map!(line => "|" ~ line ~ "|").join("\n").toUTF8;
}

auto render(in dchar[][] lines, string[] renderer, bool showStderr = true)
{
	version (Posix)
	{
		import core.sys.posix.signal;
		signal(SIGPIPE, SIG_IGN);
	}

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
