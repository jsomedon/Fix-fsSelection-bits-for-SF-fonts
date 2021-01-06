## You fix WHAT?

I know, Jimmy, I know. 😅 Some questions for you first:

* Do you use jetbrains' ide?
* Do you use them on like Linux or Windows?
* Do you use some macOS fonts with it, like `SF Mono`?
* Oh, you do? I see, you have great taste just like me. 😎 Is your font still regular? Is it italic? Or maybe bold? 😅

See, that's the problem I am trying to fix with this post. I use jetbrains' Clion with`SF Mono` on Linux, that font is supposed to render regular style, but it always renders italic style. And it's not just about jetbrains, nor `SF Mono`, nor Linux. Seems like other fonts have similar issues with other programs on other OSes. Turns out the root cause is actually way much simpler than I thought, it's less of technical issue but more of conventional thing I guess? (Which makes the whole problem easy to understand but difficult to get rid of - after all, technology is often easy to deal with, it's human factor that often makes things unpredictable and not always easy to reason about.)

We'll talk about why that happens and how we are going to fix that. And of course you will get to know that `fsSelection` thing.

## Okay. So, what was your issue again?

My issue is that, I want to use `SF Mono` in Clion in regular style, but Clion renders the font in italic style. Wasn't the most pleasant experience of figuring out what's going on, but it turns out jetbrains use following logic to set regular font variation:

* on macOS, if the filename only contains like "regular" (with no "bold" or "italic") then that's the one.
* on Linux & Windows, pick the style & weight based on the font file's `fsSelection` field.

## Ah, I see that`fsSelection`, so you can check on that value huh?

Now we are talking! 😄 So yeah it's some kind of field, you could parse from the font file, manually if you will, but I used some tools. The field tells you many things, but we are only interest if the containing glyphs' style is bold or italic or just plain regular, and this field can tell us about this.

But it really is some field and nobody is stopping you to put value you want in it. If a font file containing italic glyphs wants to lie about the style and say "my glyphs are all regular, no italic at all", it can say so in that field. And that's exactly what's going on in my case, the `SF-Mono-RegularItalic.otf` is the italic variation, but its `fsSelection` field says it contains regular glyphs.

Actually let's take a look at `SF Mono`'s regular, italic, bold, bold italic variations' `fsSelection` values:

`SF Mono variation`|`fsSelection`
---|---
`SF-Mono-Bold.otf`|`00000000 00100000`
`SF-Mono-BoldItalic.otf`|`00000000 00100001`
`SF-Mono-Regular.otf`|`00000000 01000000`
`SF-Mono-RegularItalic.otf`|`00000000 01000000`

So as you see this tabl

## What, expect me to make some sense of some random `0`'s and `1`'s all of sudden.

😅 Ah, nooooo, which is why I am going to give you another diagram and a little bit of explanations about what those `0`'s and `1`'s mean..

```text
// example fsSelection value, serialized
00000000 01100001
          ^^    ^
          ||    |
          ||    0th bit for italic
          |5th bit for bold
          6th bit for regular
```

* in a font file, `fsSelection` is just an unsigned 16 bits integer type. Serializing a font file using `ttx` gives xml version of font file, and the `fsSelection` field would become 17 chars long string like this in diagram: two strings that each representing 8 bits, with a space in between. The rightmost is the 0th bit and leftmost the 15th bit, like how binary works. Each bits means something, but in this post we are interested in 0th, 5th, 6th bits.
* 0th: 1 means the corresponding font's glyphs are italic. 0 means no italic glyphs in the font.
* 5th: 1 means the font's glyphs are bold; 0 means not
* 6th: 1 regular, 0 no

## Wait, is this example even valid? (And why do you write fewer words?)

(Why waste time, say lot word, when few word do trick? When me president, they see, they see. 😎)

And you are right, the example value is not valid. A font is bold and italic and regular at the sametime?? That's just nonsense. I made it up just for the sake of explaining, but in real life values like this should cause undefined behavior.

Anyway, now we know what those bits mean, let's pick up from where we left off -- see what those bits look like in `SF Mono`'s bold, bold italic, regular, and italic variations.

## So how did you get those data again?

An I didn't talked about it did I? Here's what I did:

* `SF Mono` fonts can be downloaded from apple's official site
* then I serialized font files to `.ttx` file(it really is just `.xml` file) using `ttx`(from `fonttools` package)
* the field is on path `ttFont/OS_2/fsSelection`, I used `xmlStarlet` but TBH I think just `grep`ing should work fine 😅

So let's really go over that table now. Line by line. First we see bold variation and bold italic variation:

`SF Mono variation`|`fsSelection`
---|---
`SF-Mono-Bold.otf`|`00000000 00100000`
`SF-Mono-BoldItalic.otf`|`00000000 00100001`

Looks reasonable, bold variation only has 5th bit(for bold) set, and bold italic variation has both 0th(for italic) and 5th set. Now let's see what regular looks like:

`SF Mono variation`|`fsSelection`
---|---
`SF-Mono-Regular.otf`|`00000000 01000000`

As expected, only 6th bit for regular is set. Now italic:

`SF Mono variation`|`fsSelection`
---|---
`SF-Mono-RegularItalic.otf`|`00000000 01000000`

## Huh? 😅

Yeah. A font file, containing italic glyphs, says that "my glyphs are plain regular, no italic no bold whatsoever" in its `fsSelection` field. Who knows why. But there you have this guy bluffing so loud.

## Okay.. so how does CLion decide between them two?

I am not entirely sure, though it seems that CLion simply doesn't care at all, but rather it seems like it's just looking for each font variations' `fsSelection` one by one, see if the value is `00000000 01000000`, and pick whatever comes up first. And if you sort `SF Mono`'s variations by filename, the italic one `SF-Mono-RegularItalic.otf` surely comes before the regular one `SF-Mono-Regular.otf`. In that case, CLion definitely picks the bluffing one -- the italic variation. I didn't bother reading actual java code to verify this, buts seems the logic works like this based on a few trials of setting fonts in CLion.

What's interesting is that, if you change to openjdk's jre for CLion(the default jre is jetbrains' custom built jre, version 11 whatnot) then `SF Mono` works fine. (But I also use SF Pro Text for CLion's interface font and that font was still rendered italic in openjdk's jre, so my guess is different jre checks for font file in different order)

There seems to be other issues that could possibly be related with incorrect fsSelection values, like these. What a mess.

## So how did you fix the issue?

I manually corrected those three bits for font files that I am interested, that is `SF Mono` and `SF Pro Text`'s bold, bold italic, regular, italic variations. The procedure follows like this:

* convert the `.otf` into `.ttx`:

```shell
ttx font.otf # should give u font.ttx
```

* edit the `fsSelection`, I used `xmlStarlet`, but things like `sed` should do fine, or even just manually edit in `vim` should do:

```shell
# R as the bit for regular
# B as the bit for bold
# I as the bit for italic
xml ed -L -u "ttFont/OS_2/fsSelection/@value" -v "00000000 0RB0000I" font.ttx
```

* edit the `macStyle` field based on `fsSelection` -- so there is another field `macStyle` in font file, it's also a 16 bit unsigned integer, and we are interested in two bits: 
    * `macStyle`'s 0th bit should be same as `fsSelection`'s 5th bit(that is the bit for bold)
    * `macStyle`'s 1st bit should be same as `fsSelection`'s 0th bit(that is the bit for italic)

```text
# R as the bit for regular
# B as the bit for bold
# I as the bit for italic

# the layout out two fields would be like this

# fsSelect
00000000 0RB0000I

# macStyle
00000000 000000IB

# So for example, if a font file has fsSelection
00000000 00000001

# then its macStyle should be
00000000 00000010
```

```shell
# I as the bit for italic
# B as the bit for bold
xml ed -L -u "ttFont/head/macStyle/@value" -v "00000000 000000IB" font.ttx
```

* compile the `.ttx` into `.otf`

```shell
ttx font.ttx # may get font.otf.1 if font.otf exists
```

That's it.

## Hmm. Looks like a decent solution.

Well, I couldn't find any documentation on how to properly set bits and fields for weights that's less common than regular/bold, like thin, light, medium, semibold and heavy, so those are still kinda unsolved problem. I am hoping someone more knowledgeable than me would catch this post in future and inform me proper ways to deal with those weights. But until than, the fix covered in this post should be okay-ish for programs like jetbrains' ide, where having common weights like bold, regular, italics are just good enough.

I also included a script in repo, it's for patching `SF Mono` and `SF Pro Text`'s regular, italic, bold, bold italic variations.

So I guess that's it for today.