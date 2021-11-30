# WikiData

This project pulls some data from Wikipedia and Wiktionary that may be useful for computational linguistics usage, particularly for Sinoxenic loanwords in CJKV languages.

There are two types of data currently produced:

## Word frequency data

This is currently available in Vietnamese and Japanese (e.g. `ja-wf-2020-11-07.json.zip`).
Word counts are collected for all words used in [vi.wikipedia.org](https://vi.wikipedia.org) and [ja.wikipedia.org](https://ja.wikipedia.org)
respectively. Tools such as MeCab are used to analyze sentences and break them down into individual words
(which is not trivial in either language).

## Dictionary entries

Currently only for Sino-Vietnamese words, all entries from [en.wiktionary.org](https://en.wiktionary.org) for "Sino-Vietnamese" words are extracted
into a file (e.g.  `vi-dict-2020-11-07.json.zip`) that is much easier to work with than the raw dump files.

## License
Code in this projected is available under a GPLv3 license (see the LICENSE file).
Output data is made available under a [CC-BY-SA 3.0 license](https://creativecommons.org/licenses/by-sa/3.0/).
