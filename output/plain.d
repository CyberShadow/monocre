module output.plain;

import std.algorithm.iteration;
import std.conv;
import std.range;

import charimage;

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
