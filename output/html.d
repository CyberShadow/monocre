module monocre.output.html;

import std.format;

import monocre.charimage;

void outputHTML(in ref CharImage i, void delegate(string) sink)
{
	sink(`<html>`);
	foreach (layer; i.layers)
	{
		sink(`<pre style="position: absolute; top: %dpx; left: %dpx">`
			.format(layer.x0, layer.y0));
		foreach (y, row; layer.chars)
		{
			CharImage.Char last;
			foreach (x, c; row)
			{
				if (last && (last.bg != c.bg || last.fg != c.fg))
					sink(`</span>`);
				if (c && (last.bg != c.bg || last.fg != c.fg))
					sink(`<span style="background-color: rgba(%d,%d,%d,%f); color: rgba(%d,%d,%d,%f);">`
						.format(
							c.bg.r, c.bg.g, c.bg.b, c.bg.a / 255.,
							c.fg.r, c.fg.g, c.fg.b, c.fg.a / 255.,
						));
				sink("&#x%x;".format(uint(c ? c.c : ' ')));
				last = c;
			}
			if (last)
				sink("</span>");
			sink("\n");
		}
		sink(`</pre>`);
	}
	sink(`</html>`);
}
