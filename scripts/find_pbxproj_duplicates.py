#!/usr/bin/env python3
"""
find_pbxproj_duplicates.py

Quick scanner for common duplication patterns in Xcode .pbxproj files:
- Duplicate PBXFileReference entries pointing to the same path/name
- Duplicate file entries within the same build phase (Sources/Frameworks/Resources/CopyFiles)
- Duplicate children within the same PBXGroup
- Identical PBXShellScriptBuildPhase scripts repeated across phases

Usage:
  python3 scripts/find_pbxproj_duplicates.py /absolute/path/to/project.pbxproj

Exit code is 0 even if duplicates are found. The script prints a structured report.
"""
from __future__ import annotations
import re
import sys
from collections import defaultdict, Counter
from pathlib import Path

PBXFILE_REF_SEC = re.compile(r"/\* Begin PBXFileReference section \*/(.*?)/\* End PBXFileReference section \*/", re.S)
PBXBUILD_FILE_SEC = re.compile(r"/\* Begin PBXBuildFile section \*/(.*?)/\* End PBXBuildFile section \*/", re.S)
PBXGROUP_SEC = re.compile(r"/\* Begin PBXGroup section \*/(.*?)/\* End PBXGroup section \*/", re.S)
PHASE_SEC = re.compile(r"/\* Begin PBX(\w+?)BuildPhase section \*/(.*?)/\* End PBX\1BuildPhase section \*/", re.S)
SHELL_SEC = re.compile(r"/\* Begin PBXShellScriptBuildPhase section \*/(.*?)/\* End PBXShellScriptBuildPhase section \*/", re.S)

ID_LINE = re.compile(r"\s*([0-9A-F]{24}) /\* (.*?) \*/ = \{(.*?)\};", re.S)
FILE_REF_ATTRS = re.compile(r"\bisa = PBXFileReference;(?P<body>.*?)\Z", re.S)
ATTR_KV = re.compile(r"(\w+) = (.*?);")
FILE_REF_KV = re.compile(r"\bfileRef = ([0-9A-F]{24})\b")
FILES_LIST = re.compile(r"\bfiles = \((.*?)\);", re.S)
CHILDREN_LIST = re.compile(r"\bchildren = \((.*?)\);", re.S)
BUILD_PHASE_ISA = re.compile(r"\bisa = (PBX\w+BuildPhase);")
# Match a quoted shellScript value, allowing for escaped characters inside the quotes
SHELL_SCRIPT = re.compile(r'\bshellScript = ("(?:\\.|[^"\\])*");', re.S)

BUILD_FILE_ITEM = re.compile(r"\s*([0-9A-F]{24}) /\* .*? \*/")


def normalize_value(val: str) -> str:
    # Strip quotes if present
    val = val.strip()
    if val.startswith('"') and val.endswith('"'):
        val = val[1:-1]
    return val


def parse_sections(text: str):
    sections = {}
    for name, pat in [
        ("PBXFileReference", PBXFILE_REF_SEC),
        ("PBXBuildFile", PBXBUILD_FILE_SEC),
        ("PBXGroup", PBXGROUP_SEC),
    ]:
        m = pat.search(text)
        sections[name] = m.group(1) if m else ""

    phases = {}
    for m in PHASE_SEC.finditer(text):
        phase_kind = m.group(1)
        phases[phase_kind] = phases.get(phase_kind, "") + m.group(2)

    shell = SHELL_SEC.search(text)
    sections["PBXShellScriptBuildPhase"] = shell.group(1) if shell else ""

    return sections, phases


def parse_file_references(sec: str):
    # Returns: id -> { name, path, sourceTree }
    file_refs = {}
    for m in ID_LINE.finditer(sec):
        _id, comment, body = m.groups()
        if "PBXFileReference" not in body:
            continue
        attrs = dict((k, normalize_value(v)) for k, v in ATTR_KV.findall(body))
        file_refs[_id] = {
            "comment": comment,
            "name": attrs.get("name"),
            "path": attrs.get("path"),
            "sourceTree": attrs.get("sourceTree"),
        }
    return file_refs


def parse_build_files(sec: str):
    # Returns: id -> fileRef
    build_files = {}
    for m in ID_LINE.finditer(sec):
        _id, _comment, body = m.groups()
        if "PBXBuildFile" not in body:
            continue
        ref = FILE_REF_KV.search(body)
        if ref:
            build_files[_id] = ref.group(1)
    return build_files


def parse_groups(sec: str):
    # Returns: id -> list of children ids
    groups = {}
    for m in ID_LINE.finditer(sec):
        _id, _comment, body = m.groups()
        if "PBXGroup" not in body:
            continue
        cl = CHILDREN_LIST.search(body)
        if cl:
            items = [x.strip() for x in cl.group(1).split(',') if x.strip()]
            # Each item looks like: 1234567890ABCDEF12345678 /* Name */
            child_ids = []
            for it in items:
                m2 = BUILD_FILE_ITEM.match(it)
                if m2:
                    child_ids.append(m2.group(1))
            groups[_id] = child_ids
    return groups


def parse_build_phases(phases: dict[str, str]):
    # Returns: list of (phaseIsa, phaseId, files[buildFileIds])
    results = []
    for kind, sec in phases.items():
        for m in ID_LINE.finditer(sec):
            phase_id, _comment, body = m.groups()
            isa_m = BUILD_PHASE_ISA.search(body)
            isa = isa_m.group(1) if isa_m else f"PBX{kind}BuildPhase"
            fl = FILES_LIST.search(body)
            if not fl:
                continue
            items = [x.strip() for x in fl.group(1).split(',') if x.strip()]
            build_file_ids = []
            for it in items:
                m2 = BUILD_FILE_ITEM.match(it)
                if m2:
                    build_file_ids.append(m2.group(1))
            results.append((isa, phase_id, build_file_ids))
    return results


def report_duplicates(pbx_path: Path):
    text = pbx_path.read_text(encoding="utf-8", errors="ignore")
    sections, phases = parse_sections(text)

    file_refs = parse_file_references(sections.get("PBXFileReference", ""))
    build_files = parse_build_files(sections.get("PBXBuildFile", ""))
    groups = parse_groups(sections.get("PBXGroup", ""))
    phase_entries = parse_build_phases(phases)

    print(f"Scanning: {pbx_path}")
    print("\n== Duplicate PBXFileReference by path/name ==")
    key_to_ids = defaultdict(list)
    for _id, info in file_refs.items():
        key = (info.get("path") or info.get("name") or info.get("comment") or "")
        key = key.strip()
        key_to_ids[key].append(_id)
    dups = {k: v for k, v in key_to_ids.items() if k and len(v) > 1}
    if not dups:
        print("No duplicates in PBXFileReference by path/name.")
    else:
        for k, ids in sorted(dups.items(), key=lambda x: x[0].lower()):
            print(f"- '{k}' -> {len(ids)} references: {', '.join(ids)}")

    print("\n== Duplicate entries within build phases ==")
    if not phase_entries:
        print("No build phases found.")
    else:
        any_dup = False
        for isa, phase_id, bf_ids in phase_entries:
            # Map to fileRef IDs then to path/name keys
            file_ref_ids = [build_files.get(bf) for bf in bf_ids if bf in build_files]
            counts = Counter(file_ref_ids)
            local_dups = [fr for fr, c in counts.items() if fr and c > 1]
            if local_dups:
                any_dup = True
                print(f"- {isa} {phase_id}: duplicate fileRef IDs: {local_dups}")
        if not any_dup:
            print("No duplicates within the same build phase.")

    print("\n== Duplicate children within PBXGroup ==")
    any_group_dup = False
    for gid, children in groups.items():
        counts = Counter(children)
        d = [c for c, n in counts.items() if n > 1]
        if d:
            any_group_dup = True
            print(f"- Group {gid} has duplicate children IDs: {d}")
    if not any_group_dup:
        print("No duplicate children within PBXGroup sections.")

    print("\n== Identical shellScript phases (exact content match) ==")
    # Loosely search all shellScript strings and count
    scripts = SHELL_SCRIPT.findall(sections.get("PBXShellScriptBuildPhase", ""))
    # normalize quotes-escaped newlines
    norm = [normalize_value(s).replace("\\n", "\n").strip() for s in scripts]
    counts = Counter(norm)
    dup_scripts = [s for s, n in counts.items() if s and n > 1]
    if dup_scripts:
        for s in dup_scripts:
            print("- Found repeated script (count={}):\n---\n{}\n---".format(counts[s], s[:400] + ("\n..." if len(s) > 400 else "")))
    else:
        print("No identical shellScript phases detected.")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 scripts/find_pbxproj_duplicates.py /path/to/project.pbxproj")
        sys.exit(0)
    pbx = Path(sys.argv[1]).expanduser().resolve()
    if not pbx.exists():
        print(f"File not found: {pbx}")
        sys.exit(1)
    report_duplicates(pbx)
