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
