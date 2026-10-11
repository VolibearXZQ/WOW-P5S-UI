"""Build P5S Rhythm Bold 1.000, standard spacing, from Fredoka Bold 2.001.

Modified for P5S on 2026-10-11. Licensed under SIL OFL 1.1; see OFL.txt.
Requires fonttools. Reference outlines are never read or imported.
"""
from pathlib import Path
import hashlib
import json
import math
from fontTools.ttLib import TTFont
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.pens.recordingPen import DecomposingRecordingPen
from fontTools.pens.transformPen import TransformPen
from fontTools.misc.transform import Transform
from fontTools.misc.roundTools import otRound
from fontTools.ttLib.tables.otBase import ValueRecord
from fontTools.otlLib.builder import buildPairPosGlyphs

HERE = Path(__file__).resolve().parent
SOURCE = HERE.parent / 'Fredoka-Bold.ttf'
OUTPUT = HERE.parent / 'P5S-Rhythm-Bold.ttf'
FAMILY = 'P5S Rhythm'
SOURCE_HASH = 'd5b9534228a0359dad311598dd57e3d14111ce44aee9d8aac6aeca349bcbffea'


def pair_amount(lookup, first, second):
    """Resolve the first applicable subtable, including explicit zero pairs."""
    for table in lookup.SubTable:
        if first not in table.Coverage.glyphs:
            continue
        assert table.ValueFormat1 == 4 and table.ValueFormat2 == 0
        if table.Format == 1:
            record = table.PairSet[table.Coverage.glyphs.index(first)]
            for pair in record.PairValueRecord:
                if pair.SecondGlyph == second:
                    return pair.Value1.XAdvance
        else:
            assert table.Format == 2
            a = table.ClassDef1.classDefs.get(first, 0)
            b = table.ClassDef2.classDefs.get(second, 0)
            value = table.Class1Record[a].Class2Record[b].Value1
            return value.XAdvance if value else 0
    return 0


def build():
    assert hashlib.sha256(SOURCE.read_bytes()).hexdigest() == SOURCE_HASH
    font = TTFont(SOURCE, recalcTimestamp=False)
    font.cfg['fontTools.ttLib.tables.otBase:USE_HARFBUZZ_REPACKER'] = False
    assert 'fvar' not in font and font['OS/2'].usWeightClass == 700
    cmap = font.getBestCmap()
    tilts = json.loads((HERE/'tilt-map.json').read_text('utf-8'))
    assert set(tilts) == set('0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz')
    targets = {cmap[ord(c)]: (c, angle) for c, angle in tilts.items()}
    gs = font.getGlyphSet()
    outlines = {}
    for name in font.getGlyphOrder():
        pen = DecomposingRecordingPen(gs); gs[name].draw(pen); outlines[name] = pen
    transforms, report = {}, []
    for name in font.getGlyphOrder():
        pen = TTGlyphPen(None)
        if name in targets:
            char, angle = targets[name]
            original = font['glyf'][name]; original.recalcBounds(font['glyf'])
            rad = math.radians(angle); c, s = math.cos(rad), math.sin(rad)
            matrix = Transform(c, -s, s, c, 0, 0)
            outlines[name].replay(TransformPen(pen, matrix))
            glyph = pen.glyph(); glyph.recalcBounds(font['glyf'])
            advance, old_lsb = font['hmtx'][name]
            left = max(24, min(48, old_lsb))
            right = max(24, min(48, advance - original.xMax))
            dx, dy = left - glyph.xMin, original.yMin - glyph.yMin
            glyph.coordinates.translate((dx, dy)); glyph.recalcBounds(font['glyf'])
            transforms[name] = Transform(c, -s, s, c, dx, dy)
            font['hmtx'][name] = (glyph.xMax + right, left)
            report.append({'character': char, 'rotation_degrees': angle,
                           'left': left, 'right': right, 'advance': glyph.xMax + right})
        else:
            outlines[name].replay(pen); glyph = pen.glyph()
        font['glyf'][name] = glyph

    # Upright kerning no longer matches rotated characters. Standard spacing
    # uses the new sidebearings for every pair touching a redesigned glyph.
    # Retain unrelated class/explicit pair behavior, lookup flags and scripts.
    removed_pairs = 0
    for lookup in font['GPOS'].table.LookupList.Lookup[:2]:
        assert lookup.LookupType == 2
        pairs = {}
        firsts = set(g for table in lookup.SubTable for g in table.Coverage.glyphs)
        for a in sorted(firsts):
            for b in font.getGlyphOrder():
                amount = pair_amount(lookup, a, b)
                if a in targets or b in targets:
                    removed_pairs += bool(amount)
                elif amount:
                    value = ValueRecord(); value.XAdvance = amount
                    pairs[a, b] = (value, None)
        lookup.SubTable = buildPairPosGlyphs(pairs, font.getReverseGlyphMap())
        lookup.SubTableCount = len(lookup.SubTable)
    # Keep combining-mark attachment on the transformed base outline.
    anchor_count = 0
    for lookup in font['GPOS'].table.LookupList.Lookup:
        if lookup.LookupType != 4:
            continue
        for table in lookup.SubTable:
            for name, record in zip(table.BaseCoverage.glyphs, table.BaseArray.BaseRecord):
                if name in transforms:
                    for anchor in record.BaseAnchor:
                        if anchor is not None:
                            assert anchor.Format == 1
                            x, y = transforms[name].transformPoint((anchor.XCoordinate, anchor.YCoordinate))
                            anchor.XCoordinate, anchor.YCoordinate = otRound(x), otRound(y)
                            anchor_count += 1
    # Prevent default/discretionary Latin ligatures from replacing tilted
    # letters with old upright joined shapes. Other features remain intact.
    removed_ligatures = 0
    for index in (3, 7):
        lookup = font['GSUB'].table.LookupList.Lookup[index]
        assert lookup.LookupType == 4
        for table in lookup.SubTable:
            for first, ligatures in list(table.ligatures.items()):
                keep = []
                for ligature in ligatures:
                    if any(g in targets for g in [first] + ligature.Component):
                        removed_ligatures += 1
                    else:
                        keep.append(ligature)
                if keep:
                    table.ligatures[first] = keep
                else:
                    del table.ligatures[first]
    for tag in ('prep','fpgm','cvt ','hdmx','LTSH','VDMX','DSIG','FFTM','STAT'):
        if tag in font:
            del font[tag]
    for glyph in font['glyf'].glyphs.values():
        glyph.removeHinting()
    font['gasp'].gaspRange = {65535: 15}
    names = font['name']
    replacements = {
        1: FAMILY, 2: 'Bold', 3: '1.000;P5SX;P5SRhythm-Bold',
        4: FAMILY+' Bold', 5: 'Version 1.000', 6: 'P5SRhythm-Bold',
        16: FAMILY, 17: 'Bold',
        10: 'Modified for P5S on 2026-10-11 from Fredoka Bold 2.001: individually rotated ASCII letters and digits, standard spacing, adjusted base mark anchors and Latin ligatures, renamed family, removed obsolete hints and source static-axis metadata. SIL Open Font License 1.1; see OFL.txt.',
    }
    names.names = [n for n in names.names if n.nameID not in set(replacements)|{18,21,22,25} and n.nameID < 256]
    for nid, value in replacements.items():
        names.setName(value, nid, 3, 1, 0x409); names.setName(value, nid, 1, 0, 0)
    font['head'].fontRevision = 1.0
    font['head'].macStyle = (font['head'].macStyle & ~2) | 1
    font['head'].flags &= ~0x1C
    font['OS/2'].fsSelection = (font['OS/2'].fsSelection & ~0x41) | 0x20
    font['post'].italicAngle = 0
    bounds = []
    for glyph in font['glyf'].glyphs.values():
        glyph.recalcBounds(font['glyf'])
        if glyph.numberOfContours:
            bounds.append((glyph.yMin, glyph.yMax))
    low = min(x[0] for x in bounds); high = max(x[1] for x in bounds)
    font['OS/2'].usWinAscent = max(font['OS/2'].usWinAscent, high)
    font['OS/2'].usWinDescent = max(font['OS/2'].usWinDescent, -low)
    font['hhea'].ascent = max(font['hhea'].ascent, high)
    font['hhea'].descent = min(font['hhea'].descent, low)
    font['head'].modified = 3874521600
    font.save(OUTPUT)
    result = {
        'family': FAMILY, 'style': 'Bold', 'edition': 'standard', 'version': '1.000',
        'license': 'SIL OFL 1.1', 'source_sha256': SOURCE_HASH,
        'output_sha256': hashlib.sha256(OUTPUT.read_bytes()).hexdigest(),
        'glyphs': len(font.getGlyphOrder()), 'characters': len(cmap),
        'modified_characters': len(targets), 'removed_old_kerning_pairs': removed_pairs,
        'transformed_base_mark_anchors': anchor_count, 'disabled_ligature_rules': removed_ligatures,
        'tilts': report, 'game_verification': 'pending', 'addon_integration': 'not performed',
    }
    (HERE/'build-report.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:v for k,v in result.items() if k!='tilts'},ensure_ascii=False))


if __name__ == '__main__':
    build()
