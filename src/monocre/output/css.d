module monocre.output.css;

import ae.utils.meta;

import std.array;
import std.format;
import std.traits;

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

enum CSSVariant
{
	bold,
	light,
	italic,
	oblique,
	underline,
	strikethrough,
	overline,
}

immutable string[2][enumLength!CSSVariant] variantCSS = [
	[`font-weight`, `bold`],
	[`font-weight`, `lighter`],
	[`font-style`, `italic`],
	[`font-style`, `oblique`],
	[`text-decoration`, `underline`],
	[`text-decoration`, `line-through`],
	[`text-decoration`, `overline`],
];

void formatVariants(ParsedVariant!CSSVariant variants, Sink sink)
{
	string currentDecl;
	foreach (v; EnumMembers!CSSVariant)
	{
		auto flag = 1 << v;
		if (flag & variants)
		{
			if (currentDecl != variantCSS[v][0])
			{
				if (currentDecl)
					sink(";");
				sink(variantCSS[v][0]);
				currentDecl = variantCSS[v][0];
			}
			else
				sink(" ");
			sink(variantCSS[v][1]);
		}
	}
	if (currentDecl)
		sink(";");
}

string formatVariants(ParsedVariant!CSSVariant variants)
{
	auto a = appender!string;
	formatVariants(variants, &a.put!(const(char)[]));
	return a.data;
}
