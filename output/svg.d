module monocre.output.svg;

import std.algorithm.comparison;
import std.algorithm.iteration;
import std.conv;
import std.format;

import ae.utils.xmlbuild;

import monocre.charimage;
import monocre.output.css;

void outputSVG(in ref CharImage i, void delegate(string) sink)
{
	auto svg = newXml().svg();
	svg["xmlns"] = "http://www.w3.org/2000/svg";
	svg["version"] = "1.1";
	auto svgW = i.layers.map!(layer => layer.x0 + layer.w * layer.chars.map!(row => row.length).reduce!max).reduce!max;
	auto svgH = i.layers.map!(layer => layer.y0 + layer.h * layer.chars.length                            ).reduce!max;
	svg["width"] = svgW.text;
	svg["height"] = svgH.text;

	auto bg = svg.g();
	auto fg = svg.g([
		"style" : "text-anchor: middle; dominant-baseline: middle;",
	]);
	foreach (layer; i.layers)
		foreach (y, row; layer.chars)
			foreach (x, c; row)
				if (c)
				{
					bg.rect([
						"x" : (layer.x0 + x * layer.w).text,
						"y" : (layer.y0 + y * layer.h).text,
						"width" : (layer.w).text,
						"height" : (layer.h).text,
						"fill" : c.bg.formatCSSColor(),
					]);
					if (c.c != ' ')
						fg.text([
							"x" : (layer.x0 + (x + 0.5) * layer.w).text,
							"y" : (layer.y0 + (y + 0.5) * layer.h).text,
							"fill" : c.fg.formatCSSColor(),
						])[] = c.c.to!string;
				}

	sink(svg.toPrettyString);
}
