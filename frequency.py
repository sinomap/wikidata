#! /usr/bin/env python
from collections import Counter
from itertools import islice
import json
import os
import string

from pathos.pools import ProcessPool
import fugashi
from pyvi import ViTokenizer, ViPosTagger


class LazyFugashiTagger(fugashi.Tagger):
    '''A lazy fugashi.Tagger that doesn't try to use Mecab, etc until first called'''
    def __init__(self):
        self.ready = False

    def __call__(self, text):
        if not self.ready:
            super().__init__()
            self.ready = True
        return super().__call__(text)


# Needs to be global (apparently) for pickling
FUGASHI_TAGGER = LazyFugashiTagger()


def jsonl_paths(root_dir):
    subdirs = os.scandir(root_dir)
    return [f.path for s in subdirs for f in os.scandir(s)]


def file_counts(path, token_fn):
    c = Counter()
    with open(path) as f:
        for line in f:
            article = json.loads(line)
            c.update(token_fn(article['text']))
    return c


def dumb_tokenize(s):
    '''Useful for testing'''
    return [word.lower().strip(string.punctuation + string.whitespace) for word in s.split(' ')]


def ja_tokenize(s):
    return [w.surface for w in FUGASHI_TAGGER(s)]


def vi_tokenize(s):
    raw_tokens = ViTokenizer.tokenize(s).split(' ')
    return [word.lower() for word in raw_tokens]


def word_freqs(root_dir, token_fn, limit=None):
    paths = jsonl_paths(root_dir)
    aggregate = Counter()
    count_fn = lambda x: file_counts(x, token_fn)
    with ProcessPool(2) as p:
        print('Using %d node(s)...' % p.nodes)
        for i, c in enumerate(p.uimap(count_fn, paths)):
            if limit and i > limit:
                break
            aggregate.update(c)
            nth = i + 1
            if nth % 100 == 0:
                print('Processed %04d files out of %04d' % (nth, len(paths)))
    return {k: v for (k,v) in aggregate.items() if v >= 3}


if __name__ == '__main__':
    import sys
    lang = sys.argv[1]
    in_dir = sys.argv[2]
    out_file = sys.argv[3]
    lang_token_fn = {'ja': ja_tokenize, 'vi': vi_tokenize}
    wf = word_freqs(in_dir, lang_token_fn.get(lang, dumb_tokenize))
    with open(out_file, 'w') as f:
        json.dump(wf, f, ensure_ascii=False, sort_keys=True)
