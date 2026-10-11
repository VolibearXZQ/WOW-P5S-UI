"""P5S Rhythm Compact 1.000. Modified for P5S on 2026-10-11.

SIL OFL 1.1; see OFL.txt. Requires fonttools, Pillow, numpy.
Uses Showtime Compact's optical spacing policy, at Rhythm's 1000 UPM.
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
from fontTools.otlLib.builder import buildPairPosGlyphs, buildLookup
from fontTools.ttLib.tables.otBase import ValueRecord
from fontTools.ttLib.tables import otTables

HERE = Path(__file__).resolve().parent
SOURCE = HERE.parent / 'P5S-Rhythm-Bold.ttf'
OUTPUT = HERE.parent / 'P5S-Rhythm-Compact-Bold.ttf'
CHARS = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'
FAMILY = 'P5S Rhythm Compact'


def build():
    source_hash = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
    assert source_hash == '6ce362f57a1e0d4d3ee20c10e2670b562366d15118aec2fe4ae07e3f903ff4ba', 'Unexpected standard version'
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
    translations = {}
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
        translations[name] = dx
        glyph.coordinates.translate((dx, 0))
        glyph.recalcBounds(font['glyf'])
        font['hmtx'][name] = (glyph.xMax + side, side)
        metrics.append({'character': char, 'translation_x': dx,
                        'standard_advance': advance, 'compact_advance': glyph.xMax + side})

    # Preserve existing script/mark/kerning lookups. Standard Rhythm has no
    # ASCII pair adjustment; append a dedicated pair lookup for Latin/DFLT.
    assert 'GPOS' in font and 'kern' not in font
    pairs = {}
    original_pairs = {}
    for a in CHARS:
        width, _, right = profiles[a]
        for b in CHARS:
            _, left, _ = profiles[b]
            available = float(np.min(width + 2 * side + left - right))
            adjustment = max(-tuck, min(0, math.ceil(gap - available)))
            assert available + adjustment >= gap
            pairs[cmap[ord(a)], cmap[ord(b)]] = adjustment
    records = {}
    for pair, amount in pairs.items():
        value = ValueRecord(); value.XAdvance = amount
        records[pair] = (value, None)
    gpos = font['GPOS'].table
    new_index = len(gpos.LookupList.Lookup)
    gpos.LookupList.Lookup.append(buildLookup(
        buildPairPosGlyphs(records, font.getReverseGlyphMap()), flags=8))
    gpos.LookupList.LookupCount = len(gpos.LookupList.Lookup)
    # Find the kern feature used by DFLT and Latin; never attach to Hebrew.
    feature_ids = set()
    for script_record in gpos.ScriptList.ScriptRecord:
        if script_record.ScriptTag not in ('DFLT', 'latn'):
            continue
        script = script_record.Script
        languages = ([script.DefaultLangSys] if script.DefaultLangSys else [])
        languages += [record.LangSys for record in script.LangSysRecord]
        for language in languages:
            for i in language.FeatureIndex:
                if gpos.FeatureList.FeatureRecord[i].FeatureTag == 'kern':
                    feature_ids.add(i)
    assert feature_ids
    for i in feature_ids:
        feature = gpos.FeatureList.FeatureRecord[i].Feature
        feature.LookupListIndex.append(new_index)
        feature.LookupCount = len(feature.LookupListIndex)
    # Digit-only strings select DFLT, whose source has no kern feature.
    # Give that script only the new ASCII lookup, not unrelated Latin pairs.
    new_feature = otTables.FeatureRecord()
    new_feature.FeatureTag = 'kern'
    new_feature.Feature = otTables.Feature()
    new_feature.Feature.FeatureParams = None
    new_feature.Feature.LookupListIndex = [new_index]
    new_feature.Feature.LookupCount = 1
    feature_list = gpos.FeatureList.FeatureRecord
    old_feature_count = len(feature_list)
    feature_list.append(new_feature)
    for record in gpos.ScriptList.ScriptRecord:
        if record.ScriptTag == 'DFLT':
            lang = record.Script.DefaultLangSys
            assert lang is not None
            lang.FeatureIndex.append(old_feature_count)
    # Feature records are sorted by tag; remap all script/language indices.
    ordered = sorted(enumerate(feature_list), key=lambda item: item[1].FeatureTag)
    remap = {old: new for new, (old, _) in enumerate(ordered)}
    gpos.FeatureList.FeatureRecord = [record for _, record in ordered]
    gpos.FeatureList.FeatureCount = len(ordered)
    for record in gpos.ScriptList.ScriptRecord:
        script = record.Script
        languages = ([script.DefaultLangSys] if script.DefaultLangSys else [])
        languages += [item.LangSys for item in script.LangSysRecord]
        for lang in languages:
            lang.FeatureIndex = sorted(remap[i] for i in lang.FeatureIndex)
            lang.FeatureCount = len(lang.FeatureIndex)
            if lang.ReqFeatureIndex != 0xFFFF:
                lang.ReqFeatureIndex = remap[lang.ReqFeatureIndex]
    anchor_count = 0
    for lookup in gpos.LookupList.Lookup[:new_index]:
        if lookup.LookupType == 4:
            for table in lookup.SubTable:
                for name, record in zip(table.BaseCoverage.glyphs, table.BaseArray.BaseRecord):
                    if name in translations:
                        for anchor in record.BaseAnchor:
                            if anchor is not None:
                                assert anchor.Format == 1
                                anchor.XCoordinate += translations[name]
                                anchor_count += 1
    legacy = newTable('kern'); legacy.version = 0
    table = KernTable_format_0(); table.version = 0; table.coverage = 1
    table.kernTable = {pair: value for pair, value in pairs.items() if value}
    legacy.kernTables = [table]; font['kern'] = legacy
    replacements = {
        1: FAMILY, 2: 'Bold', 3: '1.000;P5SX;P5SRhythmCompact-Bold',
        4: FAMILY + ' Bold', 5: 'Version 1.000', 6: 'P5SRhythmCompact-Bold',
        16: FAMILY, 17: 'Bold',
        10: 'Modified for P5S on 2026-10-11 from Fredoka Bold 2.001 via P5S Rhythm Bold: individually rotated ASCII letters/digits; compact sidebearings and optical pair spacing in GPOS and kern; renamed family. SIL Open Font License 1.1. See OFL.txt.',
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
        'family': FAMILY, 'version': '1.000', 'license': 'SIL OFL 1.1',
        'source_sha256': source_hash, 'output_sha256': hashlib.sha256(OUTPUT.read_bytes()).hexdigest(),
        'units_per_em': em, 'sidebearing_units': side, 'target_ink_gap_units': gap,
        'vertical_guard_units': guard, 'max_pair_tuck_units': tuck,
        'target_pair_count': len(CHARS)**2, 'kerning_tables': ['GPOS', 'kern'],
        'shifted_base_mark_anchors': anchor_count, 'modified_spacing_characters': len(metrics), 'metrics': metrics, 'samples': samples,
        'outlines': 'Horizontal translation only; shapes, tilt and vertical coordinates unchanged',
        'addon_integration': 'not performed', 'game_verification': 'pending',
    }
    (HERE/'compact-build-report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print(json.dumps({k: v for k, v in report.items() if k != 'metrics'}, indent=2))


if __name__ == '__main__':
    build()
