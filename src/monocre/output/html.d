/**
 * Implements HTML output.
 *
 * License:
 *   This Source Code Form is subject to the terms of
 *   the Mozilla Public License, v. 2.0. If a copy of
 *   the MPL was not distributed with this file, You
 *   can obtain one at http://mozilla.org/MPL/2.0/.
 *
 * Authors:
 *   Vladimir Panteleev <vladimir@thecybershadow.net>
 */

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
				if (last.bg != c.bg || last.fg != c.fg || last.variant !is c.variant)
				{
					if (last)
						sink(`</span>`);
					if (c)
					{
						sink(`<span style="background-color: `);
						formatCSSColor(c.bg, sink);
						sink(`; color: `);
						formatCSSColor(c.fg, sink);
						sink(`;`);
						formatVariants(c.variant.parseVariant!CSSVariant, sink);
						sink(`">`);
					}
					last = c;
				}
				sink.formattedWrite!"&#x%x;"(uint(c ? c.c : ' '));
			}
			if (last)
				sink("</span>");
			sink("\n");
		}
		sink(`</pre>`);
	}
	sink(`</html>`);
}
