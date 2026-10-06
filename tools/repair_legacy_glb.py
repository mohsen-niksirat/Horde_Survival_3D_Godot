"""Remove only dangling external image references from legacy GLBs.
Preserves geometry, embedded images and existing PBR factors. This is a
material fallback, NOT recovery of the original missing colormap artwork.
Usage: python tools/repair_legacy_glb.py [repository-root]
"""
from pathlib import Path
import json, struct, sys


def repair(root):
    changed = []
    for path in sorted((root / 'assets/models').rglob('*.glb')):
        raw = path.read_bytes()
        magic, version, length = struct.unpack_from('<4sII', raw)
        if magic != b'glTF' or version != 2 or length != len(raw):
            raise ValueError(f'Invalid GLB: {path}')
        chunks, pos = [], 12
        while pos < len(raw):
            size, kind = struct.unpack_from('<II', raw, pos)
            chunks.append((kind, raw[pos+8:pos+8+size]))
            pos += 8 + size
        doc = json.loads(chunks[0][1])
        missing = {i for i, image in enumerate(doc.get('images', []))
                   if image.get('uri') == 'Textures/colormap.png'
                   and not (path.parent / image['uri']).exists()}
        if not missing:
            continue
        bad_textures = {i for i, tex in enumerate(doc.get('textures', []))
                        if tex.get('source') in missing}
        texture_map = {}
        kept_textures = []
        for i, tex in enumerate(doc.get('textures', [])):
            if i not in bad_textures:
                texture_map[i] = len(kept_textures)
                kept_textures.append(tex)
        def prune(node):
            if isinstance(node, dict):
                for key, value in list(node.items()):
                    if key.endswith('Texture') and isinstance(value, dict) and 'index' in value:
                        if value['index'] in bad_textures:
                            del node[key]
                        else:
                            value['index'] = texture_map[value['index']]
                    else:
                        prune(value)
            elif isinstance(node, list):
                for value in node:
                    prune(value)
        for mat in doc.get('materials', []):
            prune(mat)
        image_map = {}; kept_images = []
        for i, image in enumerate(doc.get('images', [])):
            if i not in missing:
                image_map[i] = len(kept_images); kept_images.append(image)
        for tex in kept_textures:
            if 'source' in tex:
                tex['source'] = image_map[tex['source']]
        for key, values in [('images', kept_images), ('textures', kept_textures)]:
            if values:
                doc[key] = values
            else:
                doc.pop(key, None)
        encoded = json.dumps(doc, separators=(',', ':')).encode()
        encoded += b' ' * (-len(encoded) % 4)
        chunks[0] = (chunks[0][0], encoded)
        body = b''.join(struct.pack('<II', len(data), kind) + data for kind, data in chunks)
        path.write_bytes(struct.pack('<4sII', b'glTF', 2, len(body)+12) + body)
        changed.append(str(path.relative_to(root)))
    return changed

if __name__ == '__main__':
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parents[1]
    changed = repair(root)
    print(json.dumps({'changed': changed, 'count': len(changed)}, indent=2))
