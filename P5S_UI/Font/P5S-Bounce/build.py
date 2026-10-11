"""Build P5S Bounce 1.000 from Apache-2.0 Chewy. Requires fonttools.

Modified for P5S on 2026-10-11: individually rotate ASCII letters/digits,
adjust spacing and font identity. Reference font outlines are not inputs.
See LICENSE.txt and NOTICE.txt for source attribution and redistribution.
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

HERE = Path(__file__).resolve().parent
SOURCE = HERE.parent / 'Chewy-Regular.ttf'
OUTPUT = HERE.parent / 'P5S-Bounce-Regular.ttf'
FAMILY = 'P5S Bounce'
SOURCE_HASH = '7cf75ea288f82fd20badea8ab4da7a656a96a7277c170811e813b3d3d6294147'


def build():
    assert hashlib.sha256(SOURCE.read_bytes()).hexdigest() == SOURCE_HASH, 'Unexpected Chewy source version'
    font = TTFont(SOURCE, recalcTimestamp=False)
    cmap = font.getBestCmap()
    glyph_set = font.getGlyphSet()
    tilts = json.loads((HERE / 'tilt-map.json').read_text('utf-8'))
    assert set(tilts) == set('0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz')
    # Snapshot every composite before changing its base. Accented characters
    # outside this design scope retain their original appearance and metrics.
    outlines = {}
    for name in font.getGlyphOrder():
        pen = DecomposingRecordingPen(glyph_set)
        glyph_set[name].draw(pen)
        outlines[name] = pen
    targets = {cmap[ord(char)]: (char, angle) for char, angle in tilts.items()}
    em = font['head'].unitsPerEm
    minimum, maximum = round(em * .024), round(em * .048)
    report = []
    for name in font.getGlyphOrder():
        pen = TTGlyphPen(None)
        if name in targets:
            char, angle = targets[name]
            original = font['glyf'][name]
            original.recalcBounds(font['glyf'])
            # Chewy has no uniform italic shear to undo. Rotate its native
            # upright, hand-drawn forms; positive means the top leans right.
            rad = math.radians(angle)
            c, s = math.cos(rad), math.sin(rad)
            outlines[name].replay(TransformPen(pen, Transform(c, -s, s, c, 0, 0)))
            glyph = pen.glyph()
            glyph.recalcBounds(font['glyf'])
            old_advance, old_lsb = font['hmtx'][name]
            old_rsb = old_advance - original.xMax
            left = max(minimum, min(maximum, old_lsb))
            right = max(minimum, min(maximum, old_rsb))
            glyph.coordinates.translate((left - glyph.xMin, original.yMin - glyph.yMin))
            glyph.recalcBounds(font['glyf'])
            font['hmtx'][name] = (glyph.xMax + right, glyph.xMin)
            report.append({'character': char, 'rotation_degrees': angle,
                           'advance': glyph.xMax + right, 'left': left, 'right': right})
        else:
            outlines[name].replay(pen)
            glyph = pen.glyph()
        font['glyf'][name] = glyph

    # Chewy's original kerning was measured for upright outlines. Bound its
    # negative adjustments wherever either glyph changed, avoiding collisions.
    adjusted_pairs = 0
    if 'kern' in font:
        for subtable in font['kern'].kernTables:
            for (a, b), value in list(subtable.kernTable.items()):
                if a not in targets and b not in targets:
                    continue
                ga, gb = font['glyf'][a], font['glyf'][b]
                ga.recalcBounds(font['glyf']); gb.recalcBounds(font['glyf'])
                if not ga.numberOfContours or not gb.numberOfContours:
                    continue
                gap = font['hmtx'][a][0] - ga.xMax + gb.xMin
                safe_value = max(value, minimum - gap)
                if safe_value != value:
                    subtable.kernTable[(a, b)] = safe_value
                    adjusted_pairs += 1

    for tag in ['fpgm', 'prep', 'cvt ', 'hdmx', 'LTSH', 'VDMX', 'DSIG', 'FFTM']:
        if tag in font:
            del font[tag]
    for glyph in font['glyf'].glyphs.values():
        glyph.removeHinting()
    font['gasp'].gaspRange = {65535: 15}
    replacement = {
        1: FAMILY, 2: 'Regular', 3: '1.000;P5SX;P5SBounce-Regular',
        4: FAMILY + ' Regular', 5: 'Version 1.000', 6: 'P5SBounce-Regular',
        16: FAMILY, 17: 'Regular',
        10: 'Modified for P5S on 2026-10-11 from Chewy 1.001: rotated ASCII letters and digits, revised spacing, renamed family, removed obsolete hinting. Apache License 2.0. See accompanying LICENSE.txt and NOTICE.txt.',
    }
    names = font['name']
    names.names = [n for n in names.names if n.nameID not in set(replacement) | {18, 21, 22}]
    for name_id, value in replacement.items():
        names.setName(value, name_id, 3, 1, 0x409)
        names.setName(value, name_id, 1, 0, 0)
    # Preserve original copyright, designer, attribution, trademark and license.
    font['head'].fontRevision = 1.0
    font['head'].macStyle &= ~3
    font['head'].flags &= ~0x1C
    font['post'].italicAngle = 0
    font['OS/2'].fsSelection = (font['OS/2'].fsSelection & ~0x21) | 0x40
    bounds = []
    for glyph in font['glyf'].glyphs.values():
        glyph.recalcBounds(font['glyf'])
        if glyph.numberOfContours:
            bounds.append((glyph.yMin, glyph.yMax))
    low = min(b[0] for b in bounds); high = max(b[1] for b in bounds)
    font['OS/2'].usWinAscent = max(font['OS/2'].usWinAscent, high)
    font['OS/2'].usWinDescent = max(font['OS/2'].usWinDescent, -low)
    font['hhea'].ascent = max(font['hhea'].ascent, high)
    font['hhea'].descent = min(font['hhea'].descent, low)
    font['head'].modified = 3874521600
    font.save(OUTPUT)
    result = {
        'family': FAMILY, 'version': '1.000', 'license': 'Apache-2.0',
        'source_sha256': SOURCE_HASH,
        'source_matches_google_fonts': True,
        'upstream': 'https://github.com/google/fonts/tree/main/apache/chewy',
        'output_sha256': hashlib.sha256(OUTPUT.read_bytes()).hexdigest(),
        'units_per_em': em, 'glyphs': len(font.getGlyphOrder()),
        'characters': len(cmap), 'modified_characters': len(targets),
        'kerning_pairs_adjusted': adjusted_pairs, 'tilts': report,
        'scope': 'Standard edition; ASCII letters and digits; no Chinese glyphs added; no addon integration',
        'game_verification': 'pending',
    }
    (HERE / 'build-report.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({k: v for k, v in result.items() if k != 'tilts'}, ensure_ascii=False))


if __name__ == '__main__':
    build()
