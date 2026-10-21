"""Validate the UI reference bundle without Flutter or third-party packages."""
from pathlib import Path
from html.parser import HTMLParser
from urllib.parse import urlsplit, unquote
from datetime import datetime
import hashlib
import json
import re
import struct

ROOT = Path(__file__).resolve().parents[1]
UI = ROOT / 'docs/ui-v4'


class Links(HTMLParser):
    def __init__(self):
        super().__init__()
        self.resources = []
        self.anchors = []

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag in ('script', 'img') and attrs.get('src'):
            self.resources.append(attrs['src'])
        if tag == 'link' and attrs.get('href'):
            self.resources.append(attrs['href'])
        if tag == 'a' and attrs.get('href'):
            self.anchors.append(attrs['href'])


def local_link(base, href, external_allowed=False):
    url = urlsplit(href)
    if url.scheme or url.netloc:
        assert external_allowed and url.scheme in ('https', 'http'), href
        return
    if url.path:
        path = (base / unquote(url.path)).resolve()
        assert path.is_relative_to(ROOT), f'Outside repository: {href}'
        assert path.exists(), f'Missing target: {base}: {href}'


def main():
    manifest = json.loads((UI / 'manifest.json').read_text())
    screens = manifest['screens']
    assert [s['id'] for s in screens] == [f'{i:02}' for i in range(1, 17)]
    assert len({s['route'] for s in screens}) == 16
    tokens = json.loads((UI / 'tokens.json').read_text())
    assert tokens['navigation'] == ['home', 'finance', 'plans', 'calendar', 'workspace']
    assert tokens['geometry']['panelRadius'] == 16
    assert tokens['geometry']['controlRadius'] == 12
    assert all(s['implementationStatus'] == 'pending' for s in screens)

    for asset in manifest['assets']:
        data = (ROOT / asset['path']).read_bytes()
        assert len(data) == asset['bytes'], asset['path']
        assert hashlib.sha256(data).hexdigest() == asset['sha256'], asset['path']
    for screen in screens:
        data = (UI / screen['png']).read_bytes()
        assert data[:8] == b'\x89PNG\r\n\x1a\n', screen['png']
        width, height = struct.unpack('>II', data[16:24])
        assert (width, height) == (screen['pngSize']['width'], screen['pngSize']['height'])
        assert width == 780 and height > 0, screen['png']
        for key in ('html', 'text'):
            assert (UI / screen[key]).is_file(), screen[key]
        for source in screen['source']:
            assert source['symbol'] in (ROOT / source['path']).read_text(), source
        file = UI / screen['html']
        links = Links()
        links.feed(file.read_text())
        for href in links.resources + links.anchors:
            local_link(file.parent, href)

    for file in (UI / 'reference').rglob('*.css'):
        for href in re.findall(r'url\([\'\"]?([^\'\")]+)', file.read_text()):
            if not href.startswith('data:'):
                local_link(file.parent, href)
    gallery = UI / 'reference/index.html'
    links = Links()
    links.feed(gallery.read_text())
    for href in links.resources:
        local_link(gallery.parent, href)
    for href in links.anchors:
        local_link(gallery.parent, href, external_allowed=True)
    docs = [ROOT / p for p in ('AGENTS.md', 'MUSE_HANDOFF.md', 'DESIGN.md')]
    docs += list(UI.glob('*.md'))
    for file in docs:
        for href in re.findall(r'\[[^\]]+\]\(([^\s)]+)\)', file.read_text()):
            local_link(file.parent, href, external_allowed=True)

    fixture = json.loads((UI / 'fixtures.json').read_text())
    txs, expected = fixture['transactions'], fixture['expected']
    income = sum(t['amount'] for t in txs if t['amount'] > 0)
    expense = -sum(t['amount'] for t in txs if t['amount'] < 0)
    assert (income, expense, income-expense) == (expected['income'], expected['expense'], expected['balance'])
    assert len({t['id'] for t in txs}) == len(txs)
    plans = {p['id']: p for p in fixture['plans']}
    assert all(t['planId'] is None or t['planId'] in plans for t in txs)
    linked = [t for t in txs if t['planId'] == 'trip-bandung']
    spent = -sum(t['amount'] for t in linked if t['amount'] < 0)
    assert len(linked) == 3 and spent == expected['tripSpent'] == 750000
    assert plans['trip-bandung']['budget'] - spent == expected['tripRemaining']
    assert plans['community-event']['budget'] == expected['communityEventRemaining']
    for plan in plans.values():
        assert plan['endDate'] >= plan['startDate']
        for rundown in plan['rundown']:
            assert plan['startDate'] <= rundown['day'] <= plan['endDate']
    for t in txs:
        datetime.fromisoformat(t['date'])
    split = fixture['split']
    assert split['people'] >= 1
    assert divmod(split['total'], split['people']) == (split['perPerson'], split['remainder'])
    members = fixture['workspace']['members']
    assert len(members) == fixture['attendance']['memberCount'] == 4
    assert fixture['attendance']['representativeId'] in {m['id'] for m in members}
    assert datetime(2026, 10, 24).weekday() == datetime(2026, 10, 31).weekday() == 5

    qa = json.loads((UI / 'browser-qa.json').read_text())
    assert len(qa) == 16
    for screen in qa:
        assert not screen['consoleErrors'], screen['screen']
        for check in screen['sizes'] + [screen['text200Percent']]:
            assert check['width'] <= check['viewport'] and not check['bad'] and check['unnamed'] == 0
        assert all(screen['interactions'].values()), screen['screen']
    print(json.dumps({'status': 'passed', 'screens': 16,
                      'hashedReferenceAssets': len(manifest['assets']),
                      'fixturesAndLinks': 'passed', 'browserEvidence': 'passed',
                      'flutterImplementationVerified': False}, ensure_ascii=False))


if __name__ == '__main__':
    main()
