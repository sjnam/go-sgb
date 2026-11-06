#!/usr/bin/env python3
# go-sgb의 웹 하나를 gtwill로 조판하기 전에, 그 웹의 디렉터리에 .bux 두 개를 쓴다.
#
#   python3 twill/bux.py 웹이름 원본...     (웹의 디렉터리에서 부른다)
#
# system.bux: 웹이 가져오는 go-sgb 패키지마다, 그 .aux에서 내보낸 이름(대문자로
#   시작하는 것)의 @$ 줄. Go에서 남의 패키지 것은 내보낸 이름만 보이니 이것으로
#   넉넉하다. 레이블과 시험 함수는 남이 쓸 수 없으니 빼고, gbbasic의
#   Graph = gbgraph.Graph 같은 별칭은 원래 정의를 가릴 뿐이니 뺀다. 가져온 두
#   패키지가 같은 이름을 달리 정의하면(gbflip의 메서드 Next와 gbgraph의 필드 Next
#   따위) 그 이름은 통째로 버린다. gtwill은 형을 모르니 r.Next()를 *Arc라 적을
#   것이고, 틀린 인용보다는 인용하지 않는 편이 낫다.
#
# 웹이름.bux: twill/hints.txt에서 그 웹 몫의 힌트. 서술의 |...|에는 나오지만 코드가
#   정의하지 않는 이름들(대개 C 원본의 이름)에 뜻을 준다.
#
# gtwill은 system.bux, 웹 자신의 정의, 웹이름.bux 차례로 읽으므로 웹 자신의 정의가
# 가져온 것을 이기고, 힌트가 둘 다를 이긴다. 둘 다 생성물이라 커밋하지 않는다.
import os
import re
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HINTS = os.path.join(ROOT, 'twill', 'hints.txt')
SECTION = re.compile(r'@[ *\t\n]')


def die(msg):
    sys.exit('twill/bux.py: ' + msg)


def webdir(stem):
    for d in (stem, os.path.join('demos', stem), '.'):
        if os.path.exists(os.path.join(ROOT, d, stem + '.w')):
            return os.path.join(ROOT, d)
    die('웹 %s를 찾을 수 없다' % stem)


def lines_by_section(path, out=None, n=None):
    """웹의 줄마다 (절 번호, 줄)을 준다. @i로 끼운 파일의 절도 센다."""
    if out is None:
        out, n = [], [0]
    for ln in open(path, encoding='utf-8'):
        if ln.startswith('@i '):
            inc = ln[3:].strip().strip('"')
            lines_by_section(os.path.join(os.path.dirname(path), inc), out, n)
            continue
        if SECTION.match(ln):
            n[0] += 1
        out.append((n[0], ln))
    return out


def title(stem):
    w = open(os.path.join(webdir(stem), stem + '.w'), encoding='utf-8').read()
    m = re.search(r'\\def\\title\{((?:[^{}]|\{[^{}]*\})*)\}', w)
    return m.group(1) if m else stem


def aux_lines(stem):
    path = os.path.join(webdir(stem), stem + '.aux')
    if not os.path.exists(path):
        die('%s가 없다: make twill이 먼저 gtwill을 한 바퀴 돌려 .aux를 마련한다' % path)
    return [l.rstrip('\n') for l in open(path, encoding='utf-8') if l.startswith('@$')]


def system_bux(stem, srcs):
    pkgs = set()
    for s in srcs:
        pkgs |= set(re.findall(r'"github\.com/sjnam/go-sgb/(gb[a-z]+)"', open(s, encoding='utf-8').read()))
    pkgs.discard(stem)
    lines, prog = [], {}
    for p in sorted(pkgs):
        for l in aux_lines(p):
            name, loc = l.split(' ', 2)[:2]
            if not re.match(r'@\$[A-Z]', l) or re.match(r'@\$(Test|Benchmark|Example|Fuzz)', l):
                continue
            if l.endswith('\\twilllabel@>') or re.search(r'=\\PB\{\\ID\{gb[a-z]*\}\\mathord\{\.\}', l):
                continue
            where = re.sub(r'\}\d*$', '}', loc)
            prog[name] = where if prog.get(name, where) == where else None
            lines.append((name, l))
    return [l for name, l in lines if prog[name]]


def typeset(exprs):
    """Go 원문들을 gweave로 조판해 \\PB{...}들을 얻는다. 이 저장소가 정의한 형은
    굵게 나오도록 @s를 단다."""
    if not exprs:
        return []
    types = set()
    for d, _, fs in os.walk(ROOT):
        for f in fs:
            if f.endswith('.w'):
                types |= set(re.findall(r'(?m)^\s*type\s+([A-Za-z_]\w*)',
                                        open(os.path.join(d, f), encoding='utf-8').read()))
    tmp = tempfile.mkdtemp()
    with open(os.path.join(tmp, 'x.w'), 'w', encoding='utf-8') as f:
        f.write('@i %s/gbtypes.w\n' % ROOT)
        f.writelines('@s %s int\n' % t for t in sorted(types))
        f.write('@* x.\n')
        f.writelines('|%s|\\par\n' % e for e in exprs)
    subprocess.run(['gweave', 'x.w'], cwd=tmp, check=True, capture_output=True)
    tex = open(os.path.join(tmp, 'x.tex'), encoding='utf-8').read()
    out, i = [], 0
    while (i := tex.find('\\PB{', i)) >= 0:
        j, depth = i + 3, 0
        while True:
            depth += {'{': 1, '}': -1}.get(tex[j], 0)
            if depth == 0:
                break
            j += 1
        out.append(tex[i:j + 1])
        i = j + 1
    if len(out) != len(exprs):
        die('gweave가 식 %d개에서 \\PB를 %d개 냈다' % (len(exprs), len(out)))
    return out


def hints_for(stem):
    rows, cur = [], None
    for ln in open(HINTS, encoding='utf-8'):
        ln = ln.strip()
        if not ln or ln.startswith("#"):
            continue
        if ln.startswith('== '):
            cur = ln[3:].strip()
        elif cur == stem:
            rows.append(ln.split(None, 2))
    return rows


def in_bars(name, line):
    """|...| 안에(코드 주석의 |...| 포함) 이름이 낱말로 나오는가."""
    pat = re.compile(r'(?<![\w])' + re.escape(name) + r'(?![\w])')
    return any(pat.search(span) for span in line.split('|')[1::2])


def location(stem, name, loc, secs):
    """힌트의 자리를 gtwill의 꼴로. §만 적으면 그 이름이 처음 나오는 절이고,
    §12처럼 적으면 그 절에 정말 나오는지 검사한다. gbwords§처럼 다른 웹도 된다."""
    if loc.startswith('"'):
        return loc
    other, _, num = loc.partition('§')
    web = other or stem
    ss = secs if web == stem else lines_by_section(os.path.join(webdir(web), web + '.w'))
    hits = [n for n, l in ss if n > 0 and in_bars(name, l)]
    if not hits:
        die('%s: %s가 %s의 |...|에 나오지 않는다' % (stem, name, web))
    if num and int(num) not in hits:
        die('%s: %s가 %s §%s에 나오지 않는다(나오는 절: %s)' % (stem, name, web, num, hits))
    return '{%s}%s' % (title(web), num or hits[0])


def hint_bux(stem, srcs):
    secs = []
    for s in srcs:
        if s.endswith('.w'):
            secs = lines_by_section(s)
    rows = hints_for(stem)
    exprs = [m[1:] for _, _, m in rows if m[0] in '=:']
    pbs = iter(typeset(exprs))
    out = []
    for name, loc, mean in rows:
        if mean.startswith('aux:'):
            got = [l for l in aux_lines(mean[4:]) if l.startswith('@$%s ' % name)]
            if not got:
                die('%s: %s.aux에 %s가 없다' % (stem, mean[4:], name))
            out.append(got[0])
            continue
        tex = '\\zip' if mean == '-' else ('=' if mean[0] == '=' else '') + next(pbs)
        out.append('@$%s %s %s@>' % (name, location(stem, name, loc, secs), tex))
    return out


def main():
    if len(sys.argv) < 3:
        die('쓰는 법: bux.py 웹이름 원본...')
    stem, srcs = sys.argv[1], sys.argv[2:]
    head = '%% twill/bux.py가 만든 것이다. 고치려면 %s를 고친다.\n'
    with open('system.bux', 'w', encoding='utf-8') as f:
        f.write(head % '이 웹이 가져오는 패키지의 .w')
        f.writelines(l + '\n' for l in system_bux(stem, srcs))
    with open(stem + '.bux', 'w', encoding='utf-8') as f:
        f.write(head % 'twill/hints.txt')
        f.writelines(l + '\n' for l in hint_bux(stem, srcs))


main()
