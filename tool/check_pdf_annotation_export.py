"""Independent pypdf verification after flutter test test/pdf_annotation_export_test.dart.

Requires pypdf (development QA only). Test artifacts live under .local.
Run: python tool/check_pdf_annotation_export.py
"""
from pathlib import Path
from pypdf import PdfReader, PdfWriter

root = Path(__file__).resolve().parents[1] / '.local/pdf-export-qa'
original = PdfReader(root / 'original.pdf')
exported = PdfReader(root / 'annotated.pdf')

def annotations(reader):
    return [ref.get_object() for page in reader.pages for ref in page.get('/Annots', [])]

assert not annotations(original)
items = annotations(exported)
assert [a['/Subtype'] for a in items] == ['/Highlight', '/Underline', '/StrikeOut', '/Text']
assert len({a['/NM'] for a in items}) == 4
for i, item in enumerate(items):
    assert 'café α' in item['/Contents']
    assert 'Orbit note: [[' in item['/Contents']
    assert item['/F'] & 4
    assert all(abs(float(a) - b) < .001 for a, b in zip(item['/Rect'], [40, 193.5, 300, 216]))
    assert item['/C'] == [234 / 255, 179 / 255, 8 / 255] or all(
        abs(float(a) - b) < .00001 for a, b in zip(item['/C'], [234 / 255, 179 / 255, 8 / 255]))
    if i < 3:
        assert list(item['/QuadPoints']) == [40, 216, 300, 216, 40, 193.5, 300, 193.5]
assert items[-1]['/Contents'].startswith('Resolved review')
assert [p.extract_text() for p in original.pages] == [p.extract_text() for p in exported.pages]
assert len(exported.pages[0].images) == len(original.pages[0].images) == 1

rotated = PdfReader(root / 'rotated.pdf')
rect = annotations(rotated)[0]['/Rect']
assert all(abs(float(a) - b) < .001 for a, b in zip(rect, [120.8, 54, 147.8, 210]))
assert rotated.pages[0].rotation == 90
assert list(rotated.pages[0].cropbox) == [20, 30, 380, 270]

# A different PDF writer must preserve editable annotation data on round-trip.
writer = PdfWriter(clone_from=exported)
roundtrip_path = root / 'independent-roundtrip.pdf'
writer.write(roundtrip_path)
roundtrip = annotations(PdfReader(roundtrip_path))
for before, after in zip(items, roundtrip, strict=True):
    for key in ('/Subtype', '/NM', '/Contents', '/Rect', '/C', '/F'):
        assert before[key] == after[key]
print('Independent PDF checks passed: types, Unicode, colors, geometry, rotation, images, text and editable round-trip.')
