#!/usr/bin/env python3
"""Drive unresolved Tamarin proof branches through a loopback interactive server.

Start the server first, e.g.
  tamarin-prover interactive <dir> --port=3011
then:
  branch.py --port 3011 paths   <lemma> <trace>        list unresolved branch paths
  branch.py --port 3011 show    <lemma> <trace> <path>  applicable methods + constraint system
  branch.py --port 3011 apply   <lemma> <trace> <path> <index>   apply one method; prints new trace
  branch.py --port 3011 drive   <lemma> <trace> [steps] close branches by priority
Every applied method creates a new trace number. See ENVIRONMENT.md.
"""
import argparse
import html
import json
import re
import urllib.request

# Close order proven in the refined-origin migrations; the saved certificates need nothing else.
PRIORITY = [r"^contradiction", r"splitEqs", r"\(∃ pid #j\.\s*\(FreshSS", r"~~>", r"!SSValue"]


def sorry_paths(source, lemma):
    start = source.index(f"lemma {lemma} ")
    end = source.find("\nlemma ", start + 10)
    stack, out = [], []
    for line in source[start:end if end > 0 else None].split("\n"):
        m = re.match(r"^(\s*)case (\S+)", line)
        if m:
            while stack and stack[-1][0] >= len(m[1]):
                stack.pop()
            stack.append((len(m[1]), m[2]))
        if "sorry" in line:
            out.append("/".join(c for _, c in stack))
    return out


def parse_methods(page, lemma):
    head = page[: page.find("Constraint system")] if "Constraint system" in page else page
    pattern = rf'href="/thy/trace/\d+/main/method/{re.escape(lemma)}/(\d+)/[^"]*"[^>]*>(.*?)</a>(.*?)(?=<br/>\n<br/>|$)'
    return [
        (int(m[1]), re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", "", m[2] + m[3]))))
        for m in re.finditer(pattern, head, re.S)
    ]


def choose(methods):
    for pattern in PRIORITY:
        for index, text in methods:
            if re.search(pattern, text):
                return index, text
    return None


class Server:
    def __init__(self, port):
        self.base = f"http://127.0.0.1:{port}/thy/trace"

    def fetch(self, url):
        text = urllib.request.urlopen(url).read().decode()
        try:
            return json.loads(text)
        except ValueError:
            return text

    def source(self, trace):
        return self.fetch(f"{self.base}/{trace}/source")

    def page(self, lemma, trace, path):
        return self.fetch(f"{self.base}/{trace}/main/proof/{lemma}/{path}")["html"]

    def apply(self, lemma, trace, path, index):
        reply = self.fetch(f"{self.base}/{trace}/main/method/{lemma}/{index}/{path}")
        return int(re.search(r"trace/(\d+)", str(reply))[1])


def plain(page):
    return re.sub(r"\n\s*\n", "\n", html.unescape(re.sub(r"<[^>]+>", "", page.replace("<br/>", "\n"))))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawTextHelpFormatter)
    ap.add_argument("--port", type=int, default=3011)
    ap.add_argument("command", choices=["paths", "show", "apply", "drive"])
    ap.add_argument("lemma")
    ap.add_argument("trace", type=int)
    ap.add_argument("args", nargs="*")
    a = ap.parse_args()
    server = Server(a.port)
    if a.command == "paths":
        print(*sorry_paths(server.source(a.trace), a.lemma), sep="\n")
    elif a.command == "show":
        text = plain(server.page(a.lemma, a.trace, a.args[0]))
        print(text[text.find("Constraint system"):][:4000] if "Constraint system" in text else text[:4000])
        print(*[f"{i}: {t[:110]}" for i, t in parse_methods(server.page(a.lemma, a.trace, a.args[0]), a.lemma)], sep="\n")
    elif a.command == "apply":
        print("trace", server.apply(a.lemma, a.trace, a.args[0], int(a.args[1])))
    else:
        trace = a.trace
        for step in range(int(a.args[0]) if a.args else 40):
            paths = sorry_paths(server.source(trace), a.lemma)
            if not paths:
                print("DONE at trace", trace)
                return
            methods = parse_methods(server.page(a.lemma, trace, paths[0]), a.lemma)
            pick = choose(methods)
            if not pick:
                print("STUCK at", paths[0])
                print(*[f"{i}: {t[:110]}" for i, t in methods], sep="\n")
                return
            print(step, paths[0], "->", pick[0], pick[1][:60])
            trace = server.apply(a.lemma, trace, paths[0], pick[0])
        print("final trace", trace)


if __name__ == "__main__":
    main()
