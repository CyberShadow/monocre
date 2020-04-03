module monocre.output.html;

import std.format;

import monocre.charimage;
import monocre.output;
import monocre.output.css;

void outputHTML(in ref CharImage i, Sink sink)
{
	sink(`<html>`);
	foreach (layer; i.layers)
	{
		sink.formattedWrite!`<pre style="position: absolute; top: %dpx; left: %dpx">`
			(layer.x0, layer.y0);
		foreach (y, row; layer.chars)
		{
			CharImage.Char last;
			foreach (x, c; row)
			{
				if (last && (last.bg != c.bg || last.fg != c.fg))
					sink(`</span>`);
				if (c && (last.bg != c.bg || last.fg != c.fg))
				{
					sink(`<span style="background-color: `);
					formatCSSColor(c.bg, sink);
					sink(`; color: `);
					formatCSSColor(c.fg, sink);
					sink(`;">`);
				}
				sink.formattedWrite!"&#x%x;"(uint(c ? c.c : ' '));
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
