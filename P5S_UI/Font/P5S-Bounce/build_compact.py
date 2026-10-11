"""P5S Bounce Compact 1.000. Modified for P5S on 2026-10-11.

Apache-2.0; see LICENSE.txt and NOTICE.txt. Requires fonttools, Pillow, numpy.
Uses Showtime Compact's optical spacing policy, scaled to Bounce's 1024 UPM.
Only spacing and font identity change; standard outlines retain their shape.
"""
from pathlib import Path
import hashlib
import json
import math
import numpy as np
from PIL import ImageFont
from fontTools.ttLib import TTFont, newTable
from fontTools.ttLib.tables._k_e_r_n import KernTable_format_0
from fontTools.feaLib.builder import addOpenTypeFeaturesFromString

HERE = Path(__file__).resolve().parent
SOURCE = HERE.parent / 'P5S-Bounce-Regular.ttf'
OUTPUT = HERE.parent / 'P5S-Bounce-Compact.ttf'
CHARS = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'
FAMILY = 'P5S Bounce Compact'


def build():
    source_hash = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
    font = TTFont(SOURCE, recalcTimestamp=False)
    font.cfg['fontTools.ttLib.tables.otBase:USE_HARFBUZZ_REPACKER'] = False
    em = font['head'].unitsPerEm
    side, gap, guard, tuck = [round(em * value / 1000) for value in (6, 6, 3, 180)]
    cmap = font.getBestCmap()
    raster = ImageFont.truetype(str(SOURCE), em)
    # One raster pixel per design unit; use all antialias coverage.
    baseline = font['OS/2'].usWinAscent + guard + 10
    rows = baseline + font['OS/2'].usWinDescent + guard + 10
    profiles = {}
    metrics = []
    for char in CHARS:
        name = cmap[ord(char)]
        glyph = font['glyf'][name]
        mask, offset = raster.getmask2(char, anchor='ls')
        pixels = np.asarray(mask).reshape(mask.size[1], mask.size[0])
        left, right = np.full(rows, np.inf), np.full(rows, -np.inf)
        for row in range(pixels.shape[0]):
            columns = np.flatnonzero(pixels[row] > 0)
            if len(columns):
                y = baseline + offset[1] + row
                assert guard <= y < rows - guard
                left[y] = columns[0] + offset[0] - glyph.xMin
                right[y] = columns[-1] + 1 + offset[0] - glyph.xMin
        profiles[char] = (
            glyph.xMax - glyph.xMin,
            np.minimum.reduce([np.roll(left, shift) for shift in range(-guard, guard + 1)]),
            np.maximum.reduce([np.roll(right, shift) for shift in range(-guard, guard + 1)]),
        )
        advance, lsb = font['hmtx'][name]
        assert not glyph.isComposite() and lsb == glyph.xMin
        dx = side - lsb
        glyph.coordinates.translate((dx, 0))
        glyph.recalcBounds(font['glyf'])
        font['hmtx'][name] = (glyph.xMax + side, side)
        metrics.append({'character': char, 'translation_x': dx,
                        'standard_advance': advance, 'compact_advance': glyph.xMax + side})

    # Bounce's source has legacy kern only. Preserve unrelated pairs, then
    # provide identical values in new OpenType GPOS and legacy kern tables.
    assert 'GPOS' not in font
    assert len(font['kern'].kernTables) == 1
    original_pairs = dict(font['kern'].kernTables[0].kernTable)
    pairs = dict(original_pairs)
    for a in CHARS:
        width, _, right = profiles[a]
        for b in CHARS:
            _, left, _ = profiles[b]
            available = float(np.min(width + 2 * side + left - right))
            adjustment = max(-tuck, min(0, math.ceil(gap - available)))
            assert available + adjustment >= gap
            pairs[cmap[ord(a)], cmap[ord(b)]] = adjustment
    # Explicit glyph pairs avoid accidental class-based spacing changes.
    statements = '\n'.join(f'pos {a} {b} {value};' for (a, b), value in sorted(pairs.items()))
    addOpenTypeFeaturesFromString(font, 'languagesystem DFLT dflt;\nlanguagesystem latn dflt;\nfeature kern {\n' + statements + '\n} kern;')
    legacy = newTable('kern'); legacy.version = 0
    table = KernTable_format_0(); table.version = 0; table.coverage = 1
    table.kernTable = {pair: value for pair, value in pairs.items() if value}
    legacy.kernTables = [table]; font['kern'] = legacy
    replacements = {
        1: FAMILY, 2: 'Regular', 3: '1.000;P5SX;P5SBounceCompact-Regular',
        4: FAMILY + ' Regular', 5: 'Version 1.000', 6: 'P5SBounceCompact-Regular',
        16: FAMILY, 17: 'Regular',
        10: 'Modified for P5S on 2026-10-11 from Chewy 1.001 via P5S Bounce: individually rotated ASCII letters/digits; compact sidebearings and optical pair spacing in GPOS and kern; renamed family. Apache License 2.0. See LICENSE.txt and NOTICE.txt.',
    }
    names = font['name']
    names.names = [n for n in names.names if n.nameID not in replacements]
    for nid, value in replacements.items():
        names.setName(value, nid, 3, 1, 0x409); names.setName(value, nid, 1, 0, 0)
    font['head'].fontRevision = 1.0
    font.save(OUTPUT)
    assert hashlib.sha256(SOURCE.read_bytes()).hexdigest() == source_hash
    original = TTFont(SOURCE)
    samples = {}
    for text in ['0123456789', 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz', 'HP', 'SP', '100', 'Innovation in China']:
        glyphs = [cmap[ord(c)] for c in text]
        glyph_pairs = list(zip(glyphs, glyphs[1:]))
        standard = sum(original['hmtx'][g][0] for g in glyphs) + sum(original_pairs.get(p, 0) for p in glyph_pairs)
        compact_raw = sum(font['hmtx'][g][0] for g in glyphs)
        compact = compact_raw + sum(pairs.get(p, 0) for p in glyph_pairs)
        samples[text] = {'standard_kerned_units': standard, 'compact_kerned_units': compact,
                         'compact_without_kerning_units': compact_raw,
                         'reduction_percent': round(100 * (1 - compact / standard), 2)}
    report = {
        'family': FAMILY, 'version': '1.000', 'license': 'Apache-2.0',
        'source_sha256': source_hash, 'output_sha256': hashlib.sha256(OUTPUT.read_bytes()).hexdigest(),
        'units_per_em': em, 'sidebearing_units': side, 'target_ink_gap_units': gap,
        'vertical_guard_units': guard, 'max_pair_tuck_units': tuck,
        'target_pair_count': len(CHARS)**2, 'kerning_tables': ['GPOS', 'kern'],
        'modified_spacing_characters': len(metrics), 'metrics': metrics, 'samples': samples,
        'outlines': 'Horizontal translation only; shapes, tilt and vertical coordinates unchanged',
        'addon_integration': 'not performed', 'game_verification': 'pending',
    }
    (HERE/'compact-build-report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print(json.dumps({k: v for k, v in report.items() if k != 'metrics'}, indent=2))


if __name__ == '__main__':
    build()
