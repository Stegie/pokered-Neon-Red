#!/usr/bin/python
# coding: utf-8

import argparse

from extras.redtools import extract_maps as maps
from extras.redtools.map_block_dumper import map_name_cleaner as clean


def rip_map_blk(map_id):

    map_header = maps.map_headers[map_id]

    if map_header['name'] == 'FREEZE':
        return # skip this one

    address, w, h = [int(map_header[v], 16) for v in ('map_pointer', 'x', 'y')]
    size     = w * h
    blk      = maps.rom[address : address + size]
    filename = clean(map_header['name'], None)[:-2].lower()
    path     = 'maps/' + filename + '.blk'

    with open(path, 'wb') as out:
        out.write(blk)


def main(rom_name):

    maps.load_rom(rom_name)

    maps.load_map_pointers()
    maps.read_all_map_headers()

    # Cerulean houses got renamed from {2,3} to {,2}
    maps.map_headers[63]['name']  = 'Cerulean House'
    maps.map_headers[230]['name'] = 'Cerulean House (2)'

    # Route 18 Gate Upstairs got renamed
    maps.map_headers[191]['name'] = 'Route 18 Gate Upstairs'

    for map_id in maps.map_headers.keys():
        rip_map_blk(map_id)


if __name__ == '__main__':

    ap = argparse.ArgumentParser()
    ap. add_argument('rom', nargs='?', default='pokered.gbc')
    args = ap.parse_args()

    main(args.rom)
