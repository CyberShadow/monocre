/**
 * Implements JSON output.
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

module monocre.output.json;

import ae.utils.json;

import monocre.charimage;
import monocre.output;

void outputJSON(in ref CharImage i, Sink sink)
{
	static struct Writer
	{
		Sink sink;
		void put(T...)(T args)
		{
			foreach (arg; args)
				static if (is(typeof(arg) : char))
					sink((&arg)[0..1]);
				else
					sink(arg);
		}
	}
	CustomJsonSerializer!(PrettyJsonWriter!Writer) serializer;
	serializer.writer.output.sink = sink;
	serializer.put(i);
}
