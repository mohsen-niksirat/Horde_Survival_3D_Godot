"""Headless regression gate. Each script gets a separate temporary save dir.
Usage: python tools/run_tests.py --godot godot [--test tests/test_name.gd]
Cleanup-at-exit warnings are reported separately, never hidden as passes.
"""
from pathlib import Path
import argparse, json, os, re, subprocess, tempfile, time


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--godot', default='godot')
    ap.add_argument('--test', action='append')
    ap.add_argument('--timeout', type=int, default=120)
    ap.add_argument('--out', default='build/test-results')
    args = ap.parse_args()
    root = Path(__file__).resolve().parents[1]
    out = root / args.out; out.mkdir(parents=True, exist_ok=True)
    tests = args.test or ['tests/smoke_phase1.gd'] + [str(x.relative_to(root)) for x in sorted((root/'tests').glob('test_*.gd'))]
    results = []
    for test in tests:
        start = time.monotonic()
        with tempfile.TemporaryDirectory() as save:
            env = dict(os.environ, XDG_DATA_HOME=save, GODOT_SILENCE_ROOT_WARNING='1')
            try:
                # Use shell=True or bash fallback in case godot is a wrapper shell script without a shebang
                cmd = [args.godot, '--headless', '--path', str(root), '--script', test]
                try:
                    p = subprocess.run(cmd, capture_output=True, text=True, timeout=args.timeout, env=env)
                except OSError as e:
                    if e.errno == 8:  # Exec format error
                        p = subprocess.run(['bash', args.godot, '--headless', '--path', str(root), '--script', test], capture_output=True, text=True, timeout=args.timeout, env=env)
                    else:
                        raise
                log = p.stdout + p.stderr; code = p.returncode
            except subprocess.TimeoutExpired as exc:
                log = str(exc.stdout or '') + str(exc.stderr or '') + '\nTIMEOUT'; code = 124
        (out / (Path(test).stem + '.log')).write_text(log)
        cleanup = [line for line in log.splitlines() if 'leaked at exit' in line or 'resources still in use at exit' in line]
        errors = [line for line in log.splitlines() if ('ERROR:' in line or 'FAIL' in line) and line not in cleanup]
        passed = code == 0 and not errors and bool(re.search(r'\b\w*PASS\w*\b', log))
        result = dict(test=test, exit_code=code, passed=passed, seconds=round(time.monotonic()-start, 2), errors=errors, cleanup_warnings=cleanup)
        results.append(result)
        print(('PASS' if passed else 'FAIL'), test, flush=True)
    report = dict(total=len(results), passed=sum(r['passed'] for r in results), results=results)
    (out/'summary.json').write_text(json.dumps(report, indent=2))
    print(json.dumps({k:v for k,v in report.items() if k != 'results'}))
    return 0 if all(r['passed'] for r in results) else 1

if __name__ == '__main__':
    raise SystemExit(main())
