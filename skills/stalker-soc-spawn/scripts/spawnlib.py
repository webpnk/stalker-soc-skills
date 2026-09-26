"""Minimal reader/writer for ACDC-decompiled spawn LTX files (alife_<level>.ltx, way_<level>.ltx).

A file is a sequence of sections: a "[header]" line followed by key lines. Values may be
heredocs ("key = <<END" ... "END") whose body can itself contain "[section]" lines, so the parser
tracks heredocs instead of splitting on every "[".
"""
import re

HEADER = re.compile(r"^\[([^\]]*)\]\s*$")


class Section:
    def __init__(self, header, lines):
        self.header = header          # text between the brackets
        self.lines = lines            # raw lines after the header, heredocs included

    def get(self, key):
        for ln in self.lines:
            m = re.match(r"^\s*" + re.escape(key) + r"\s*=\s*(.*)$", ln)
            if m:
                return m.group(1).strip()
        return None

    def set(self, key, value):
        for i, ln in enumerate(self.lines):
            if re.match(r"^\s*" + re.escape(key) + r"\s*=", ln):
                self.lines[i] = "%s = %s" % (key, value)
                return
        raise KeyError(key)

    def set_custom_data(self, text):
        """Replace (or add) the custom_data heredoc."""
        self.remove_custom_data()
        block = ["custom_data = <<END"] + text.strip("\n").split("\n") + ["END"]
        # vanilla puts custom_data right after object_flags in the cse_alife_object block
        for i, ln in enumerate(self.lines):
            if re.match(r"^\s*object_flags\s*=", ln):
                self.lines[i + 1:i + 1] = block
                return
        raise KeyError("object_flags")

    def remove_custom_data(self):
        """Drop the custom_data heredoc (its [logic]), leaving a plain object."""
        out, skip, tag = [], False, None
        for ln in self.lines:
            if skip:
                if ln.strip() == tag:
                    skip = False
                continue
            m = re.match(r"^\s*custom_data\s*=\s*<<(\w+)\s*$", ln)
            if m:
                skip, tag = True, m.group(1)
                continue
            out.append(ln)
        self.lines = out

    @property
    def name(self):
        return self.get("name")

    @property
    def section_name(self):
        return self.get("section_name")

    def position(self):
        return tuple(float(v) for v in self.get("position").split(","))

    def text(self):
        return "[%s]\n%s" % (self.header, "\n".join(self.lines))


def parse(path):
    with open(path, encoding="cp1251") as f:
        raw = f.read().splitlines()
    preamble, sections = [], []
    cur = None
    heredoc = None
    for ln in raw:
        if heredoc is not None:
            cur.lines.append(ln)
            if ln.strip() == heredoc:
                heredoc = None
            continue
        m = HEADER.match(ln)
        if m:
            cur = Section(m.group(1), [])
            sections.append(cur)
            continue
        hd = re.search(r"=\s*<<(\w+)\s*$", ln)
        if hd:
            heredoc = hd.group(1)
        (cur.lines if cur else preamble).append(ln)
    return preamble, sections


def write(path, preamble, sections):
    with open(path, "w", encoding="cp1251", newline="\r\n") as f:
        if preamble:
            f.write("\n".join(preamble) + "\n")
        for s in sections:
            body = s.lines
            while body and body[-1].strip() == "":
                body = body[:-1]
            f.write("[%s]\n%s\n\n" % (s.header, "\n".join(body)))
