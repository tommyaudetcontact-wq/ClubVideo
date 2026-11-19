"""Run isolated Godot regressions; an exit code alone never counts as a pass."""
import argparse
import json
from pathlib import Path
import subprocess
import time
import re
import shutil

ROOT = Path(__file__).resolve().parent.parent
ENGINE = Path('C:/Users/recto/Documents/Codex/2026-10-27/fait-x20-2/work/tools/godot/Godot_v4.7.2-stable_win64_console.exe')
TESTS = [
    ('test_entrepreneur_coop', 'ENTREPRENEUR_COOP_COMPLETE failures=0', []),
    ('test_entrepreneur_dropin', 'ENTREPRENEUR_DROPIN_COMPLETE failures=0', ['--touch-profile']),
    ('test_catalogue_stress', 'CATALOGUE_STRESS_COMPLETE failures=0', []),
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

def relevant_errors(output, marker):
    completed = output.find(marker)
    errors = []
    cleanup = []
    for match in re.finditer(r'^ERROR:.*$', output, re.M):
        line = match.group()
        # Godot's GL driver reports these during engine teardown, after the test
        # has finished. Keep them in the report without hiding runtime errors.
        if completed >= 0 and match.start() > completed and re.match(r'ERROR: Texture with GL ID of \d+: leaked \d+ bytes\.', line):
            cleanup.append(line)
        else:
            errors.append(line)
    return errors, cleanup

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--only', nargs='*')
    parser.add_argument('--render', action='store_true', help='Use the real GPU instead of the headless dummy renderer')
    parser.add_argument('--compat', action='store_true', help='Exercise the OpenGL compatibility renderer used by Android')
    args = parser.parse_args()
    project = ROOT / 'work/test-project'
    config = (project / 'project.godot').read_text(encoding='utf-8-sig')
    if 'ClubVideo-AutomatedTests-20261118' not in config:
        raise RuntimeError('Refusing to test without isolated user data')
    # Always exercise the current scripts, while keeping the isolated project settings.
    for path in (ROOT / 'outputs/videoclub-quest').iterdir():
        if path.is_file() and path.suffix in {'.gd', '.uid', '.tscn', '.tres', '.gdshader', '.svg'}:
            shutil.copy2(path, project / path.name)
    results = []
    for name, marker, extra in TESTS:
        if args.only and name not in args.only:
            continue
        tag = name + ('-touch' if extra else '') + ('-compat' if args.compat else '-gpu' if args.render else '')
        log = ROOT / f'work/regression-{tag}.log'
        command = [str(ENGINE)] + ([] if args.render else ['--headless']) + ['--xr-mode', 'off', '--path', str(project),
                   '--script', f'res://{name}.gd', '--max-fps', '120', '--quit-after', '14400']
        if extra:
            command += ['--'] + extra
        if args.compat:
            insert = command.index('--') if '--' in command else len(command)
            command[insert:insert] = ['--rendering-method', 'gl_compatibility', '--rendering-driver', 'opengl3']
        start = time.monotonic()
        with log.open('w', encoding='utf-8') as stream:
            process = subprocess.Popen(command, stdout=stream, stderr=subprocess.STDOUT)
            code = None
            while process.poll() is None:
                with log.open('r', encoding='utf-8', errors='replace') as probe:
                    errors = probe.read(32768)
                if time.monotonic()-start > 150 or 'SCRIPT ERROR' in errors or relevant_errors(errors, marker)[0]:
                    subprocess.run(['taskkill', '/PID', str(process.pid), '/T', '/F'], capture_output=True)
                    code = -1
                    break
                time.sleep(.5)
            if code is None:
                code = process.wait(timeout=10)
        output = log.read_text(encoding='utf-8', errors='replace')
        errors, cleanup = relevant_errors(output, marker)
        passed = code == 0 and marker in output and 'SCRIPT ERROR' not in output and not errors
        result = dict(test=tag, passed=passed, exit_code=code,
                      seconds=round(time.monotonic()-start, 2), log=str(log), teardown_warnings=cleanup)
        results.append(result)
        print(json.dumps(result), flush=True)
        (ROOT / f'work/regression-result-{tag}.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
        report = 'regression-results-gpu.json' if args.render else 'regression-results.json'
        if args.compat:
            report = 'regression-results-compat.json'
        if args.only:
            report = report.replace('.json', '-partial.json')
        (ROOT / 'work' / report).write_text(json.dumps(results, indent=2), encoding='utf-8')
    return 0 if results and all(r['passed'] for r in results) else 1

if __name__ == '__main__':
    raise SystemExit(main())
