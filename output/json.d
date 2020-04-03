module monocre.output.json;

import ae.utils.json;

import monocre.charimage;

void outputJSON(in ref CharImage i, void delegate(string) sink)
{
	sink(i.toPrettyJson);
}
