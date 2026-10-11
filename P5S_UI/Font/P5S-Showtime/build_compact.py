"""Build the compact companion without rewriting the standard font.

Requires fonttools, Pillow and numpy. Licensed under SIL OFL 1.1.
ASCII alphanumeric spacing is optically fitted using actual ink profiles.
Glyph shapes remain unchanged. Matching GPOS and legacy kern tables provide
pair adjustments for modern and older font renderers respectively.
"""
from pathlib import Path
import hashlib
import json
import math
import numpy as np
from PIL import ImageFont
from fontTools.ttLib import TTFont, newTable
from fontTools.ttLib.tables.otBase import ValueRecord
from fontTools.ttLib.tables._k_e_r_n import KernTable_format_0
from fontTools.otlLib.builder import buildPairPosGlyphs

HERE = Path(__file__).resolve().parent
SOURCE = HERE.parent / 'P5S-Showtime-Regular.ttf'
OUTPUT = HERE.parent / 'P5S-Showtime-Compact.ttf'
FAMILY = 'P5S Showtime Compact'
CHARS = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'
SIDEBEARING = 6
INK_GAP = 6
VERTICAL_GUARD = 3
MAX_PAIR_TUCK = 180


def ink_profiles(font):
    """At 1000 ppem, one sample pixel equals one design unit of this face.

    Left/right envelopes include all nonzero coverage and are expanded in
    y to keep diagonally adjacent corners apart. Empty rows use infinities.
    These are optical spacing measurements, not replacement glyph contours.
    """
    assert font['head'].unitsPerEm == 1000
    raster = ImageFont.truetype(str(SOURCE), 1000)
    cmap = font.getBestCmap()
    profiles = {}
    for char in CHARS:
        glyph = font['glyf'][cmap[ord(char)]]
        mask, offset = raster.getmask2(char, anchor='ls')
        pixels = np.asarray(mask).reshape(mask.size[1], mask.size[0])
        left = np.full(1900, np.inf)
        right = np.full(1900, -np.inf)
        for row in range(pixels.shape[0]):
            cols = np.flatnonzero(pixels[row] > 0)
            if len(cols):
                y = 1200 + offset[1] + row
                assert VERTICAL_GUARD <= y < len(left) - VERTICAL_GUARD
                left[y] = cols[0] + offset[0] - glyph.xMin
                right[y] = cols[-1] + 1 + offset[0] - glyph.xMin
        guarded_left, guarded_right = left.copy(), right.copy()
        for shift in range(-VERTICAL_GUARD, VERTICAL_GUARD + 1):
            guarded_left = np.minimum(guarded_left, np.roll(left, shift))
            guarded_right = np.maximum(guarded_right, np.roll(right, shift))
        profiles[char] = (glyph.xMax - glyph.xMin, guarded_left, guarded_right)
    return profiles


def set_pair_spacing(font, profiles):
    """Replace target pairs, preserve all other existing GPOS pair values."""
    cmap = font.getBestCmap()
    lookups = font['GPOS'].table.LookupList.Lookup
    assert len(lookups) == 1 and lookups[0].LookupType == 2
    lookup = lookups[0]
    values = {}
    for subtable in lookup.SubTable:
        assert subtable.Format == 1
        assert subtable.ValueFormat1 == 4 and subtable.ValueFormat2 == 0
        for first, pair_set in zip(subtable.Coverage.glyphs, subtable.PairSet):
            for pair in pair_set.PairValueRecord:
                values[first, pair.SecondGlyph] = pair.Value1.XAdvance
    adjustments = {}
    for a in CHARS:
        width, _, right = profiles[a]
        for b in CHARS:
            _, left, _ = profiles[b]
            available = float(np.min(width + SIDEBEARING * 2 + left - right))
            adjustment = max(-MAX_PAIR_TUCK, min(0, math.ceil(INK_GAP - available)))
            assert available + adjustment >= INK_GAP
            values[cmap[ord(a)], cmap[ord(b)]] = adjustment
            adjustments[a + b] = adjustment
    pairs = {}
    for pair, amount in values.items():
        value = ValueRecord()
        value.XAdvance = amount
        pairs[pair] = (value, None)
    lookup.SubTable = buildPairPosGlyphs(pairs, font.getReverseGlyphMap())
    lookup.SubTableCount = len(lookup.SubTable)
    legacy = newTable('kern')
    legacy.version = 0
    table = KernTable_format_0()
    table.version, table.coverage = 0, 1
    table.kernTable = {pair: value for pair, value in values.items() if value}
    legacy.kernTables = [table]
    font['kern'] = legacy
    return adjustments


def build():
    source_hash = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
    font = TTFont(SOURCE, recalcTimestamp=False)
    # Identical table packing whether optional uharfbuzz is installed or not.
    font.cfg['fontTools.ttLib.tables.otBase:USE_HARFBUZZ_REPACKER'] = False
    cmap = font.getBestCmap()
    profiles = ink_profiles(font)
    entries = []
    for char in CHARS:
        name = cmap[ord(char)]
        glyph = font['glyf'][name]
        assert not glyph.isComposite(), 'Standard face must have decomposed glyphs'
        advance, old_left = font['hmtx'][name]
        old_right = advance - glyph.xMax
        assert old_left == glyph.xMin and old_left > 0 and old_right > 0
        left = right = SIDEBEARING
        dx = left - old_left
        glyph.coordinates.translate((dx, 0))
        glyph.recalcBounds(font['glyf'])
        new_advance = glyph.xMax + right
        font['hmtx'][name] = (new_advance, left)
        entries.append({
            'character': char, 'left': left, 'right': right,
            'standard_advance': advance, 'compact_advance': new_advance,
            'translation_x': dx,
        })
    adjustments = set_pair_spacing(font, profiles)
    replacements = {
        1: FAMILY, 2: 'Regular',
        3: '1.001;P5SX;P5SShowtimeCompact-Regular',
        4: FAMILY + ' Regular', 5: 'Version 1.001',
        6: 'P5SShowtimeCompact-Regular', 16: FAMILY, 17: 'Regular',
        10: 'Optically fitted compact companion to P5S Showtime. Individually adjusted alphanumeric pairs in GPOS and legacy kern; original outlines retained. SIL OFL 1.1.',
    }
    name_table = font['name']
    name_table.names = [n for n in name_table.names if n.nameID not in replacements]
    for name_id, value in replacements.items():
        name_table.setName(value, name_id, 3, 1, 0x409)
        name_table.setName(value, name_id, 1, 0, 0)
    font['head'].fontRevision = 1.001
    font.save(OUTPUT)
    assert hashlib.sha256(SOURCE.read_bytes()).hexdigest() == source_hash
    samples = {}
    original = TTFont(SOURCE)
    for sample in ['0123456789', 'ABCDEFGHIJKLMNOPQRSTUVWXYZ',
                   'abcdefghijklmnopqrstuvwxyz', 'HP', 'SP', '100',
                   'Innovation in China']:
        standard = sum(original['hmtx'][cmap[ord(c)]][0] for c in sample)
        compact = sum(font['hmtx'][cmap[ord(c)]][0] for c in sample)
        pair_adjustment = sum(adjustments.get(a + b, 0) for a, b in zip(sample, sample[1:]))
        samples[sample] = {
            'standard_advance_units': standard,
            'compact_with_pair_spacing_units': compact + pair_adjustment,
            'compact_without_pair_spacing_units': compact,
            'width_reduction_percent': round((1 - (compact + pair_adjustment) / standard) * 100, 2),
        }
    report = {
        'family': FAMILY, 'version': '1.001', 'units_per_em': font['head'].unitsPerEm,
        'source_sha256': source_hash,
        'output_sha256': hashlib.sha256(OUTPUT.read_bytes()).hexdigest(),
        'sidebearing_units': SIDEBEARING, 'target_ink_gap_units': INK_GAP,
        'vertical_guard_units': VERTICAL_GUARD, 'max_pair_tuck_units': MAX_PAIR_TUCK,
        'pair_adjustment_count': len(adjustments),
        'kerning_tables': ['GPOS', 'kern'],
        'modified_spacing_characters': len(entries),
        'outlines': 'Unchanged shapes and y coordinates; horizontal translation only',
        'samples_standard_unkerned_vs_compact_kerned': samples, 'metrics': entries,
        'game_verification': 'pending', 'addon_integration': 'not performed',
    }
    (HERE / 'compact-build-report.json').write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({k: v for k, v in report.items() if k != 'metrics'}, indent=2))


if __name__ == '__main__':
    build()
