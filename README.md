# Fix `fsSelection` for `SF Mono`, `SF Pro Text` and other fonts

On Windows and Linux, intellij IDEA(and other jetbrains' products in general) query a field named `fsSlection` from font files to determine style of glyphs font files contain. Some font files may actually contain, say italic glyphs, but their `fsSlection` fields are set as if they contain regular glyphs, so if you happen to use such fonts with intellij IDEA on Windows and Linux, you will see italic glyphs where you are supposed to see regular glyphs. [Apple's SanFrancisco font is exactly this case](https://youtrack.jetbrains.com/issue/JBR-806#focus=Comments-27-2890679.0-0).

So I rolled up some scripts to fix `SF Mono` and `SF Pro Text`'s `Regular`, `RegularItalic`, `Bold`, `BoldItalic`. There is also another more general script that can fix any fonts.

### `patch_SF_Mono_SF_Pro_Text.sh`

This script patches `SF Mono` and `SF Pro Text`'s `Regular`, `RegularItalic`, `Bold`, `BoldItatlic` font files. It downloads the fonts' `.dmg` from Apple's upstream url, then patches them, then put the patched and original fonts under `<pwd>/SF_Mono_SF_Pro_Text`.

There are also font files for other styles and weights, like `SemiBold` and`Heavy` and whatnot, but I didn't fix them with this script because I don't know what is the correct `fsSelection` value for those less common weights and styles. If someone could inform me how to properly fix those fonts, I would gladly update the scripts.

Dependency:

* the other two scripts - `get_SF_Mono_SF_Pro_Text.sh` and `fix_fsSelection.sh`
* `wget`
* `7z`
* `ttx` from `fonttools`
* `xmlstarlet` from `xmlStarlet`

### `fix_fsSelection.sh`

This is the general one. Usage:

```shell
./fix_fsSelection.sh font_path font_style_bits
# font_style_bits: <bold bit><italic bit><regular bit>
#                  so, to fix for bold - 100
#                  for bold italic - 110
#                  for regular - 001
#                  for italic - 010
#                  other style bits are invalid
# example:
# ./fix_fsSelection.sh ./MyItalicFont.otf 010
```

Pretty straightforward.

Dependency:

* `ttx` from `fonttools`
* `xmlstarlet` from `xmlStarlet`
