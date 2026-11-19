"""Run isolated Godot regressions; an exit code alone never counts as a pass."""
import argparse
import json
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parent.parent
ENGINE = Path('C:/Users/recto/Documents/Codex/2026-10-27/fait-x20-2/work/tools/godot/Godot_v4.7.2-stable_win64_console.exe')
TESTS = [
    ('test_catalogue_migration', 'CATALOGUE_MIGRATION_COMPLETE failures=0', []),
    ('test_entrepreneur_rules', 'ENTREPRENEUR_RULES_COMPLETE failures=0', []),
    ('test_day0100', 'DAY0100_OK', []),
    ('test_disc096', 'DISC096_OK', []),
    ('test_capture0103', 'CAPTURE0103', []),
    ('test_entrepreneur_flow', 'ENTREPRENEUR_WORKFLOW_COMPLETE failures=0', []),
    ('test_entrepreneur_flow', 'ENTREPRENEUR_WORKFLOW_COMPLETE failures=0', ['--touch-profile']),
    ('test_coop_full_simulation', 'COOP_FULL_SIMULATION_OK', []),
    ('test_coop_full_mobile', 'COOP_FULL_MOBILE_OK', []),
]

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--only', nargs='*')
    parser.add_argument('--render', action='store_true', help='Use the real GPU instead of the headless dummy renderer')
    args = parser.parse_args()
    project = ROOT / 'work/test-project'
    config = (project / 'project.godot').read_text(encoding='utf-8-sig')
    if 'ClubVideo-AutomatedTests-20261118' not in config:
        raise RuntimeError('Refusing to test without isolated user data')
    results = []
    for name, marker, extra in TESTS:
        if args.only and name not in args.only:
            continue
        tag = name + ('-touch' if extra else '') + ('-gpu' if args.render else '')
        log = ROOT / f'work/regression-{tag}.log'
        command = [str(ENGINE)] + ([] if args.render else ['--headless']) + ['--xr-mode', 'off', '--path', str(project),
                   '--script', f'res://{name}.gd', '--max-fps', '120', '--quit-after', '14400']
        if extra:
            command += ['--'] + extra
        start = time.monotonic()
        with log.open('w', encoding='utf-8') as stream:
            process = subprocess.Popen(command, stdout=stream, stderr=subprocess.STDOUT)
            code = None
            while process.poll() is None:
                with log.open('r', encoding='utf-8', errors='replace') as probe:
                    errors = probe.read(32768)
                if time.monotonic()-start > 150 or 'SCRIPT ERROR' in errors or '\nERROR:' in errors:
                    subprocess.run(['taskkill', '/PID', str(process.pid), '/T', '/F'], capture_output=True)
                    code = -1
                    break
                time.sleep(.5)
            if code is None:
                code = process.wait(timeout=10)
        output = log.read_text(encoding='utf-8', errors='replace')
        passed = code == 0 and marker in output and 'SCRIPT ERROR' not in output and '\nERROR:' not in output
        result = dict(test=tag, passed=passed, exit_code=code,
                      seconds=round(time.monotonic()-start, 2), log=str(log))
        results.append(result)
        print(json.dumps(result), flush=True)
        report = 'regression-results-gpu.json' if args.render else 'regression-results.json'
        (ROOT / 'work' / report).write_text(json.dumps(results, indent=2), encoding='utf-8')
    return 0 if results and all(r['passed'] for r in results) else 1

if __name__ == '__main__':
    raise SystemExit(main())
