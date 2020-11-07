#! /usr/bin/env python
from collections import defaultdict

import lxml.etree as ET
from mwtemplates import TemplateEditor


def load_ids(path):
    with open(path) as f:
        ids = set()
        for line in f:
            ids.add(int(line))
    return ids


def load_pages(ids_path, xml_path):
    ret = {}
    ids = load_ids(ids_path)
    # TODO: Flag entries with multiple VN etymologies, Non-Sino readings
    for event, el in ET.iterparse(xml_path):
        e = el
        if ET.QName(e).localname != 'page':
            continue
        _id = int(e.find('{*}id').text)
        if  _id in ids:
            title = e.find('{*}title').text
            text = e.find('./{*}revision/{*}text').text
            ret[title] = text
            if len(ret) % 100 == 0:
                print('Processed %05d pages out of %05d' % (len(ret), len(ids)))
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
