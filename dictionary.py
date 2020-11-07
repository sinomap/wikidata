#! /usr/bin/env python
from collections import defaultdict

from xml.etree import ElementTree as ET

def load_ids(path):
    with open(path) as f:
        ids = set()
        for line in f:
            ids.add(int(line))
    return ids


def load_pages(ids_path, xml_path):
    ret = {}
    ids = load_ids(ids_path)
    for event, el in ET.iterparse(xml_path):
        if not el.tag.endswith('page'):
            continue
        _id = int(el.find('{*}id').text)
        if  _id in ids:
            title = el.find('{*}title').text
            text = el.find('./{*}revision/{*}text').text
            ret[title] = text
            if len(ret) % 100 == 0:
                print('Processed %05d pages out of %05d' % (len(ret), len(ids)))
        # Note that iterparse won't free elements as it goes by default.
        # Could, probably be more aggressive, but this is sufficient to keep
        # memory usage reasonable.
        el.clear()
    return ret


if __name__ == '__main__':
    import json
    import sys
    id_file = sys.argv[1]
    in_file = sys.argv[2]
    out_file = sys.argv[3]
    pages = load_pages(id_file, in_file)
    with open(out_file, 'w') as f:
        json.dump(pages, f, ensure_ascii=False, sort_keys=True)
