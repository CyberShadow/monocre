module monocre.charimage;

import ae.utils.graphics.color;

/// OCR'd image
struct CharImage
{
	alias Color = BGRA;
	struct Char
	{
		dchar c; // when ==dchar.init, nothing was recognized at this position
		Color bg, fg;
		string variant;
	}

	struct Layer
	{
		sizediff_t x0, y0;
		size_t w, h;
		Char[][] chars;
	}
	Layer[] layers;
}
