from pathlib import Path
import re
ROOT = Path(__file__).resolve().parents[2]
REPORT = ROOT / 'reports/production/07a8'
OUT = REPORT / 'startup_verify_summary.txt'
PAT = {
    'runtime': re.compile(r'\[Startup\] RuntimeV3 ready (\d+)ms'),
    'welcome': re.compile(r'\[Startup\] Welcome navigation (\d+)ms'),
    'repo': re.compile(r'\[Startup\] Repository ready (\d+)ms'),
    'auth': re.compile(r'\[Startup\] Auth ready (\d+)ms'),
}
SKIP = re.compile(r'Skipped\s+(\d+)\s+frames', re.I)

def parse(path):
    text = path.read_text(encoding='utf-8', errors='replace')
    d = {}
    for k, rx in PAT.items():
        m = rx.search(text)
        d[k] = int(m.group(1)) if m else None
    skips = [int(x) for x in SKIP.findall(text)]
    d['max_skip'] = max(skips) if skips else 0
    d['runtime_ready_seen'] = '[RuntimeV3] READY' in text
    return d

def show(label, d):
    print(label)
    print('  Runtime V3:', d['runtime'], 'ms')
    print('  Auth:      ', d['auth'], 'ms')
    print('  Welcome:   ', d['welcome'], 'ms')
    print('  Repository:', d['repo'], 'ms')
    print('  Max skipped frames:', d['max_skip'])
    print('  RuntimeV3 READY marker:', d['runtime_ready_seen'])

def main():
    first = parse(REPORT / 'first_install.log')
    warm = parse(REPORT / 'warm_launch.log')
    print('=' * 62)
    print('LINKBALL STEP 07A.8 - STARTUP VERIFY SUMMARY')
    print('=' * 62)
    print()
    show('FIRST INSTALL', first)
    print()
    show('WARM LAUNCH', warm)
    print()
    findings = []
    if first['welcome'] is None:
        findings.append('First-install Welcome marker missing.')
    elif first['welcome'] > 10000:
        findings.append(f"First-install Welcome still slow: {first['welcome']}ms.")
    if warm['welcome'] is None:
        findings.append('Warm Welcome marker missing.')
    elif warm['welcome'] > 5000:
        findings.append(f"Warm Welcome still slow: {warm['welcome']}ms.")
    if not first['runtime_ready_seen'] or not warm['runtime_ready_seen']:
        findings.append('RuntimeV3 READY marker missing in one launch.')
    if max(first['max_skip'], warm['max_skip']) >= 120:
        findings.append('120+ skipped-frame stall remains; 07A.9 model bridge is recommended.')
    if first['repo'] is not None and first['welcome'] is not None and first['repo'] > first['welcome']:
        print('[PASS] Legacy Repository completed AFTER Welcome on first install.')
    else:
        findings.append('Could not verify Repository remained outside first-install Welcome path.')
    if warm['repo'] is not None and warm['welcome'] is not None and warm['repo'] > warm['welcome']:
        print('[PASS] Legacy Repository completed AFTER Welcome on warm launch.')
    print()
    if findings:
        print('[WARN] Remaining findings:')
        for f in findings:
            print('  -', f)
        overall = 'NEEDS_07A_9'
    else:
        print('[PASS] Startup critical-path goals met.')
        overall = 'PASS'
    OUT.write_text('\n'.join([
        f'overall={overall}',
        f"first_runtime_ms={first['runtime']}",
        f"first_welcome_ms={first['welcome']}",
        f"first_repo_ms={first['repo']}",
        f"first_max_skipped={first['max_skip']}",
        f"warm_runtime_ms={warm['runtime']}",
        f"warm_welcome_ms={warm['welcome']}",
        f"warm_repo_ms={warm['repo']}",
        f"warm_max_skipped={warm['max_skip']}",
        *['finding=' + x for x in findings],
    ]) + '\n', encoding='utf-8', newline='\n')
    print()
    print('Overall:', overall)

if __name__ == '__main__':
    main()
