"""Validate a portable selection-sample library; does not judge art or grant rights."""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import xml.etree.ElementTree as ET

class LibraryError(ValueError):
    pass

def require(ok, message):
    if not ok:
        raise LibraryError(message)

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def fingerprint(files):
    return hashlib.sha256(json.dumps(files, sort_keys=True, separators=(',', ':')).encode()).hexdigest()

def no_links(path):
    for p in (path, *path.parents):
        require(not p.is_symlink() and not (hasattr(p, 'is_junction') and p.is_junction()), f'Linked path: {p}')

def local(root, name):
    require(isinstance(name, str) and bool(name), 'Empty path')
    parts = PurePosixPath(name)
    require(not parts.is_absolute() and '..' not in parts.parts and not any(c in name for c in '\\:%?#') and '.' not in parts.parts, f'Unsafe path: {name}')
    p = root / name
    no_links(p)
    require(p.resolve().is_relative_to(root.resolve()), f'Escaped path: {name}')
    require(p.is_file(), f'Missing file: {name}')
    return p

def svg_references(text):
    # Namespace declarations identify XML vocabulary; they are not fetched assets.
    require('<!DOCTYPE' not in text.upper(), 'Unsupported SVG document type')
    try:
        tree = ET.fromstring(text)
    except ET.ParseError as error:
        raise LibraryError('Invalid SVG: '+str(error)) from error
    ids = {node.get('id') for node in tree.iter() if node.get('id')}
    refs = []
    for node in tree.iter():
        tag = node.tag.rsplit('}', 1)[-1]
        require(tag not in ('script', 'foreignObject'), 'Unsupported active SVG content')
        for key, value in node.attrib.items():
            if key.rsplit('}', 1)[-1] in ('href', 'src'):
                refs.append(value)
            refs.extend(re.findall(r'url\(\s*["\']?([^"\')]+)', value, re.I))
        if tag == 'style':
            css = ''.join(node.itertext())
            require('@import' not in css.lower(), 'Unsupported SVG CSS import')
            refs.extend(re.findall(r'url\(\s*["\']?([^"\')]+)', css, re.I))
    external = []
    for ref in refs:
        ref = ref.strip()
        if ref.startswith('#'):
            require(ref[1:] in ids, 'Missing SVG fragment: '+ref)
        else:
            require(not re.match(r'(?:[a-z][a-z0-9+.-]*:|//)', ref, re.I), 'External SVG reference: '+ref)
            external.append(ref)
    return external


def validate(root):
    root = Path(root).absolute(); no_links(root)
    manifest = local(root, 'manifest.json')
    data = json.loads(manifest.read_text(encoding='utf-8'))
    require(data.get('schemaVersion') == 1, 'schemaVersion')
    require(bool(data.get('libraryId')) and re.fullmatch(r'\d+\.\d+\.\d+', str(data.get('libraryVersion'))), 'library identity')
    entries = data.get('entries'); require(isinstance(entries, list) and bool(entries), 'Empty entries')
    seen = set()
    for e in entries:
        key = (e.get('sampleId'), e.get('version'))
        require(re.fullmatch(r'[a-z][a-z0-9-]*', str(key[0])) and re.fullmatch(r'\d+\.\d+\.\d+', str(key[1])) and key not in seen, f'Invalid/duplicate ID: {key}'); seen.add(key)
        for field in ('kind', 'tags', 'description', 'candidateSelector', 'comparisonConditions', 'editableParameters', 'provenance'):
            require(bool(e.get(field)), f'Missing {field}: {key}')
        files = e.get('sourceFiles'); require(isinstance(files, dict) and bool(files), 'sourceFiles')
        require('manifest.json' not in files, 'Manifest cannot self-hash')
        for name, sha in files.items():
            require(re.fullmatch('[a-f0-9]{64}', str(sha)), f'Invalid hash: {name}')
            require(digest(local(root, name)) == sha, f'Hash mismatch: {name}')
        preview = e.get('previewPath'); require(preview in files, 'Preview outside source closure')
        dependencies = e.get('dependencies', {})
        require(bool(dependencies.get('runtime')) and dependencies.get('external') == [], 'Undeclared/external dependencies')
        rights = e.get('rights', {})
        require(rights.get('status') == 'cleared-for-workflow-reuse' and bool(rights.get('basis')) and rights.get('externalElements') == [] and bool(rights.get('limitations')), 'Rights not cleared')
        v = e.get('verification', {})
        require(v.get('status') == 'independent-source-pass' and re.fullmatch('[a-f0-9]{64}', str(v.get('reviewSHA256'))) and v.get('sourceFingerprint') == fingerprint(files) and bool(v.get('environment')), 'Missing/stale independent source review')
        provenance=e['provenance']
        require(bool(provenance.get('creator')) and bool(provenance.get('tools')) and bool(provenance.get('originCandidate')) and re.fullmatch('[a-f0-9]{64}', str(provenance.get('originManifestSHA256'))), 'Missing provenance')
        originals=provenance.get('originalSourceHashes', {})
        require(sorted(originals.values()) == sorted(files.values()), 'Original source identity differs')
        # Static reference closure. Linked paths, external URLs and undeclared references fail closed.
        reachable=set(); pending=[preview]
        while pending:
            name=pending.pop()
            if name in reachable: continue
            reachable.add(name);p=local(root,name)
            if p.suffix not in ('.html','.js','.css','.svg'): continue
            text=p.read_text(encoding='utf-8')
            if p.suffix == '.svg':
                refs=svg_references(text)
            else:
                require(not re.search(r'(?:https?:|file:|data:|//cdn\.)',text), f'External reference in {name}')
                refs=re.findall(r'(?:src|href)\s*=\s*["\']([^"\']+)["\']',text)
                refs+=re.findall(r'url\(\s*["\']?([^"\')]+)',text)
            for ref in refs:
                rel=(PurePosixPath(name).parent / ref).as_posix()
                local(root,rel);require(rel in files,f'Undeclared reference: {rel}')
                pending.append(rel)
        require(reachable == set(files), f'Unreachable source closure: {set(files)-reachable}')
        selector=e['candidateSelector']
        html=local(root,preview).read_text(encoding='utf-8')
        if e['kind'] == 'motion':
            match=re.fullmatch(r'figure\[data-motion="([a-z][a-z0-9-]*)"\]',selector)
            require(match is not None and f'data-motion="{match.group(1)}"' in html, 'Missing candidate selector')
        elif e['kind'] == 'button-shape':
            match=re.fullmatch(r'#(B[0-9]{2})',selector)
            require(match is not None and len(re.findall(r'<figure\b[^>]*\bid="'+re.escape(match.group(1))+r'"',html)) == 1, 'Missing/wrong static candidate selector')
            require(all(e['comparisonConditions'].get(k) for k in ('previewViewport','sampleSize','faceSize','label','locale','font')), 'Static comparison conditions')
        else:
            raise LibraryError('Unknown sample kind: '+str(e['kind']))
    return {'status':'valid-selection-library','entries':len(entries),'libraryVersion':data['libraryVersion'],'projectApproval':False}

if __name__ == '__main__':
    parser=argparse.ArgumentParser();parser.add_argument('root',nargs='?',default=str(Path(__file__).resolve().parents[1]/'assets/sample-library'))
    args=parser.parse_args()
    try: print(json.dumps(validate(args.root)))
    except (LibraryError, OSError, ValueError, TypeError, KeyError) as error: parser.exit(1, str(error)+'\n')
