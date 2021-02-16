monocre
=======

monocre is a simple OCR program for bitmap fonts.

Its distinguishing features are:

- No heuristics (it generally either produces 100% correct output, or doesn't work at all)
- Can learn arbitrary fonts using a user-supplied renderer program
- Supports arbitrary text decorations or font variants
  (HTML, SVG and ANSI output support bold/light/italic/underline/overline/strikethrough)
- Outputs plain text, ANSI color sequences, HTML, SVG, and JSON
- Preserves alpha channel

Its main limitation is that it works only with "bitmap", monospace fonts.
For monocre's purposes, these are defined as follows:

- Characters are placed on a grid, so that each character's top-left pixel
  is at `(x0 + i * w, y0 + j * h)`, where all values are non-negative integers.
- A character's pixels are fully contained within that character's grid cell
  (i.e. italic/oblique fonts which "lean out" of their cell aren't supported)
- Characters are rendered independently of their neighboring characters
  (i.e. things like ligatures aren't supported)
- Characters are rendered with one solid color,
  so that each cell contains only pixels of one foreground and one background color
  (i.e. antialiased fonts and color emojis aren't supported).

Some applications would be:

- Recognizing screenshots of terminal emulators,
  and converting them to scalable SVG images

- Recognizing screenshots of VNC sessions in order to precisely scan text
  when clipboard operations are unavailable
  (such as when VNC-ing to a Linux console session in a VM)


Example 1: ImageMagick
----------------------

In this example, we teach monocre how to recognize text rendered by ImageMagick.

Learn command:

```console
$ monocre learn \
    liberationmono-20.json \
    convert \
    +antialias \
    -background black \
    -fill white \
    -pointsize 20 \
    -font '/usr/share/fonts/liberation/LiberationMono-Regular.ttf' \
    label:@- \
    -dither None \
    -monochrome \
    bmp:-
```

This will create `liberationmono-20.json`, which we can now use to recognize text:

```console
$ convert \
    +antialias \
    -background red \
    -fill green \
    -pointsize 20 \
    -font '/usr/share/fonts/liberation/LiberationMono-Regular.ttf' \
    label:'Hello from monocre!' \
    -type TrueColorAlpha -alpha on bmp:- |
    monocre read liberationmono-20.json
monocre: New best offset: 0,0 (score=1602)
Hello from monocre
```

Re-running with `--output-format=svg` gives us a color SVG image:

![Ugly!](https://dump.thecybershadow.net/d6a14c8bd0ad7200a31b4b9b8f3189da/a.svg)

Notes:

- monocre does not set a font family or size in SVG/HTML output.
  Edit the output to set one which will look good in your use case.

- ImageMagick miscalculates the image width in the above example,
  cutting off the trailing `!` character.

- Depending on the font size, ImageMagick will align characters
  a non-integer amount of pixels apart, 
  causing `monocre` to fail to identify a character grid.

- ImageMagick has limited support for core X11 fonts (such as Misc/Fixed),
  which can be used with e.g. `-font '-misc-fixed-medium-r-*-*-13-*-*-*-*-70-*-*'`.
  However, current versions do not support Unicode - 
  UTF-8 will be rendered as mojibake.


Example 2: Terminal emulator screenshots with rxvt-unicode
----------------------------------------------------------

1. Create the script `render-urxvt-inner`:

   ```shell
   #!/bin/sh
   cat <&3
   sleep 0.1
   maim --window="$(xdotool getwindowfocus)" | 
       convert - +dither -monochrome bmp:- >&4
   ```

2. Create the script `render-urxvt`:

   ```shell
   #!/bin/sh
   ( printf %s "$1" ; cat) |
   urxvt -e ./render-urxvt-inner 3<&0 4>&1
   ```

3. To learn multiple font variants, you can run:

   ```conosle
   $ monocre learn                     urxvt.json ./render-urxvt  ''
   $ monocre learn --variant=bold      urxvt.json ./render-urxvt $'\033[1m'
   $ monocre learn --variant=underline urxvt.json ./render-urxvt $'\033[4m'
   ```

Recognizing terminal screenshots should now work:

```console
$ convert screenshot.png -type TrueColorAlpha -alpha on bmp:- | 
    monocre read --output-format=ansi256 urxvt.json
```

Notes:

- Because terminal emulators pipe the three standard streams to themselves,
  the scripts use higher file descriptors to send data across the terminal emulator boundary.

- As a general debugging tip, inserting `| tee debug.bmp ` into pipelines 
  can help show what input monocre is choking on.
