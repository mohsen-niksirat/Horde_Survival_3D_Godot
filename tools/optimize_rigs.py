"""Optimize large rigged GLB models by removing unused animations and compacting buffers.
Usage: python tools/optimize_rigs.py
"""
import json, struct
from pathlib import Path

KEEP_ANIMATIONS = {
    'Idle', 'Walking_A', 'Running_A',
    'Unarmed_Idle', 'Walking', 'Running',
    'Death_A'
}

def optimize_glb(path: Path, keep_anims: set):
    raw = path.read_bytes()
    magic, version, total_len = struct.unpack_from('<4sII', raw, 0)
    assert magic == b'glTF' and version == 2
    
    # parse chunks
    json_len, json_type = struct.unpack_from('<II', raw, 12)
    assert json_type == 0x4E4F534A # JSON
    doc = json.loads(raw[20:20+json_len])
    
    bin_offset = 20 + json_len
    if bin_offset % 4 != 0:
        bin_offset += 4 - (bin_offset % 4)
        
    bin_data = b''
    if bin_offset < len(raw):
        bin_len, bin_type = struct.unpack_from('<II', raw, bin_offset)
        assert bin_type == 0x004E4942 # BIN
        bin_data = raw[bin_offset+8:bin_offset+8+bin_len]

    # Filter animations
    old_anims = doc.get('animations', [])
    new_anims = [a for a in old_anims if a.get('name') in keep_anims]
    doc['animations'] = new_anims

    # Collect all referenced accessors
    used_accessors = set()
    for mesh in doc.get('meshes', []):
        for prim in mesh.get('primitives', []):
            if 'indices' in prim:
                used_accessors.add(prim['indices'])
            for attr, acc_idx in prim.get('attributes', {}).items():
                used_accessors.add(acc_idx)
            for target in prim.get('targets', []):
                for attr, acc_idx in target.items():
                    used_accessors.add(acc_idx)
    for skin in doc.get('skins', []):
        if 'inverseBindMatrices' in skin:
            used_accessors.add(skin['inverseBindMatrices'])
    for anim in new_anims:
        for s in anim.get('samplers', []):
            used_accessors.add(s['input'])
            used_accessors.add(s['output'])

    # Build new accessors and mapping
    old_accessors = doc.get('accessors', [])
    accessor_map = {}
    new_accessors = []
    for old_idx in sorted(used_accessors):
        if old_idx < len(old_accessors):
            accessor_map[old_idx] = len(new_accessors)
            new_accessors.append(old_accessors[old_idx])

    # Remap accessor references
    for mesh in doc.get('meshes', []):
        for prim in mesh.get('primitives', []):
            if 'indices' in prim and prim['indices'] in accessor_map:
                prim['indices'] = accessor_map[prim['indices']]
            for attr in list(prim.get('attributes', {}).keys()):
                prim['attributes'][attr] = accessor_map[prim['attributes'][attr]]
            for target in prim.get('targets', []):
                for attr in list(target.keys()):
                    target[attr] = accessor_map[target[attr]]
    for skin in doc.get('skins', []):
        if 'inverseBindMatrices' in skin and skin['inverseBindMatrices'] in accessor_map:
            skin['inverseBindMatrices'] = accessor_map[skin['inverseBindMatrices']]
    for anim in new_anims:
        for s in anim.get('samplers', []):
            s['input'] = accessor_map[s['input']]
            s['output'] = accessor_map[s['output']]
    doc['accessors'] = new_accessors

    # Collect referenced bufferViews
    used_bufferviews = set()
    for acc in new_accessors:
        if 'bufferView' in acc:
            used_bufferviews.add(acc['bufferView'])
    for img in doc.get('images', []):
        if 'bufferView' in img:
            used_bufferviews.add(img['bufferView'])

    old_bviews = doc.get('bufferViews', [])
    bview_map = {}
    new_bviews = []
    new_bin_data = bytearray()

    for old_idx in sorted(used_bufferviews):
        if old_idx < len(old_bviews):
            bv = dict(old_bviews[old_idx])
            offset = bv.get('byteOffset', 0)
            length = bv['byteLength']
            data = bin_data[offset:offset+length]
            
            # Align buffer offset to 4 bytes
            align = len(new_bin_data) % 4
            if align != 0:
                new_bin_data.extend(b'\x00' * (4 - align))
            
            new_offset = len(new_bin_data)
            new_bin_data.extend(data)
            
            bv['byteOffset'] = new_offset
            bv['buffer'] = 0
            bview_map[old_idx] = len(new_bviews)
            new_bviews.append(bv)

    # Remap bufferView in accessors and images
    for acc in new_accessors:
        if 'bufferView' in acc:
            acc['bufferView'] = bview_map[acc['bufferView']]
    for img in doc.get('images', []):
        if 'bufferView' in img:
            img['bufferView'] = bview_map[img['bufferView']]
    doc['bufferViews'] = new_bviews

    # Update buffers
    doc['buffers'] = [{'byteLength': len(new_bin_data)}]

    # Re-encode GLB
    json_bytes = json.dumps(doc, separators=(',', ':')).encode('utf-8')
    json_pad = (4 - (len(json_bytes) % 4)) % 4
    json_bytes += b' ' * json_pad

    bin_pad = (4 - (len(new_bin_data) % 4)) % 4
    new_bin_data += b'\x00' * bin_pad

    total_size = 12 + 8 + len(json_bytes) + 8 + len(new_bin_data)
    out = bytearray()
    out.extend(struct.pack('<4sII', b'glTF', 2, total_size))
    out.extend(struct.pack('<II', len(json_bytes), 0x4E4F534A))
    out.extend(json_bytes)
    out.extend(struct.pack('<II', len(new_bin_data), 0x004E4942))
    out.extend(new_bin_data)

    path.write_bytes(out)
    saved = len(raw) - len(out)
    pct = (saved / len(raw)) * 100
    print(f'Optimized {path.name}: {len(raw):,} -> {len(out):,} bytes (saved {saved:,} bytes, {pct:.1f}%)')

def main():
    root = Path(__file__).resolve().parents[1]
    targets = [
        root / 'assets/models/kaykit/heroes/adventurer_mage.glb',
        root / 'assets/models/kaykit/heroes/adventurer_knight.glb',
        root / 'assets/models/kaykit/heroes/adventurer_rogue.glb',
        root / 'assets/models/kaykit/monsters/skeleton_warrior.glb',
    ]
    for target in targets:
        if target.exists():
            optimize_glb(target, KEEP_ANIMATIONS)

if __name__ == '__main__':
    main()
