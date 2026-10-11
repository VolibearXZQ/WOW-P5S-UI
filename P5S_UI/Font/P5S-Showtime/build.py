"""Build P5S Showtime from the user's OFL Fugaz One source. Requires fonttools.

Only Latin A-Z/a-z and digits 0-9 are redesigned. Reference outlines are
never imported. Positive optical tilt means the top leans to the right.
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
SOURCE = HERE.parent / 'FugazOne-Regular.ttf'
OUTPUT = HERE.parent / 'P5S-Showtime-Regular.ttf'
FAMILY = 'P5S Showtime'

def build():
    font = TTFont(SOURCE, recalcTimestamp=False)
    cmap = font.getBestCmap()
    glyph_set = font.getGlyphSet()
    tilts = json.loads((HERE / 'tilt-map.json').read_text('utf-8'))
    assert set(tilts) == set('0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz')
    # Snapshot and decompose BEFORE editing: accented composites must not
    # silently inherit a newly tilted base while keeping their old accents.
    outlines = {}
    for name in font.getGlyphOrder():
        pen = DecomposingRecordingPen(glyph_set)
        glyph_set[name].draw(pen)
        outlines[name] = pen
    targets = {cmap[ord(c)]: (c, angle) for c, angle in tilts.items()}
    report = []
    for name in font.getGlyphOrder():
        pen = TTGlyphPen(None)
        if name in targets:
            char, angle = targets[name]
            original = font['glyf'][name]
            original.recalcBounds(font['glyf'])
            # Fugaz's I stem shifts 126 units over a height of 720 units.
            # Undo that shear before a true rotation, so crossbars also tilt.
            shear = 126 / 720
            rad = math.radians(angle)
            c, s = math.cos(rad), math.sin(rad)
            matrix = Transform(c, -s, s-c*shear, c+s*shear, 0, 0)
            outlines[name].replay(TransformPen(pen, matrix))
            glyph = pen.glyph()
            glyph.recalcBounds(font['glyf'])
            old_advance, old_lsb = font['hmtx'][name]
            old_rsb = old_advance-original.xMax
            left = max(24, min(48, old_lsb))
            right = max(24, min(48, old_rsb))
            dx = left-glyph.xMin
            dy = original.yMin-glyph.yMin
            # Align lowest point to the existing baseline/descender floor.
            # New sidebearings reserve room for the rotated ink bounding box.
            glyph.coordinates.translate((dx, dy))
            glyph.recalcBounds(font['glyf'])
            advance = glyph.xMax + right
            font['hmtx'][name] = (advance, glyph.xMin)
            report.append({'character':char,'tilt_degrees':angle,
                           'advance':advance,'left':left,'right':right})
        else:
            outlines[name].replay(pen)
            glyph = pen.glyph()
        font['glyf'][name] = glyph
    # Old hints and signatures describe the source outlines and are invalid
    # for the transformed face. Let the rasterizer render the new outlines.
    for tag in ['fpgm','prep','cvt ','hdmx','LTSH','VDMX','DSIG','FFTM']:
        if tag in font:
            del font[tag]
    font['gasp'].gaspRange = {65535: 15}
    for glyph in font['glyf'].glyphs.values():
        glyph.removeHinting()
    name_table = font['name']
    replacement = {
        1:FAMILY, 2:'Regular', 3:'1.000;P5SX;P5SShowtime-Regular',
        4:FAMILY+' Regular', 5:'Version 1.000', 6:'P5SShowtime-Regular',
        16:FAMILY, 17:'Regular',
        10:'Custom P5S face derived from Fugaz One. Individually tilted ASCII letters and digits. SIL OFL 1.1.',
    }
    # Remove obsolete source-only family/style identifiers on every platform.
    name_table.names = [n for n in name_table.names if n.nameID not in set(replacement)|{18,21,22}]
    for name_id,value in replacement.items():
        name_table.setName(value,name_id,3,1,0x409)
        name_table.setName(value,name_id,1,0,0)
    font['head'].fontRevision=1.0
    font['head'].macStyle &= ~3
    font['head'].flags &= ~0x1C
    font['post'].italicAngle=0
    font['OS/2'].fsSelection=(font['OS/2'].fsSelection & ~0x21)|0x40
    all_bounds=[]
    for g in font['glyf'].glyphs.values():
        g.recalcBounds(font['glyf'])
        if g.numberOfContours:
            all_bounds.append((g.yMin,g.yMax))
    low=min(y[0] for y in all_bounds);high=max(y[1] for y in all_bounds)
    font['OS/2'].usWinAscent=max(font['OS/2'].usWinAscent,high)
    font['OS/2'].usWinDescent=max(font['OS/2'].usWinDescent,-low)
    font['hhea'].ascent=max(font['hhea'].ascent,high)
    font['hhea'].descent=min(font['hhea'].descent,low)
    # Fixed modification time makes repeated builds reproducible.
    font['head'].modified=3874521600
    font.save(OUTPUT)
    result={
        'family':FAMILY,'version':'1.000',
        'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
        'output_sha256':hashlib.sha256(OUTPUT.read_bytes()).hexdigest(),
        'glyphs':len(font.getGlyphOrder()),'characters':len(cmap),
        'modified_characters':len(targets),'tilts':report,
        'scope':'ASCII letters and digits; no Chinese glyphs added; no addon integration',
        'game_verification':'pending',
    }
    (HERE/'build-report.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:v for k,v in result.items() if k!='tilts'},ensure_ascii=False))

if __name__ == '__main__':
    build()
