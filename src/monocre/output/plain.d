/**
 * Implements plain text output.
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

module monocre.output.plain;

import std.algorithm.iteration;
import std.conv;
import std.range;

import monocre.charimage;

void outputPlain(in ref CharImage i, void delegate(string) sink)
{
	foreach (layer; i.layers)
		sink(layer.chars
			.map!(row => row
				.map!(c => c.c == dchar.init ? ' ' : c.c)
				.chain("\n"d)
			)
			.joiner
			.to!string
		);
}
