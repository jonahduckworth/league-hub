#!/usr/bin/env python3
"""Run local Next.js development servers while preserving checkout configuration."""
import os
from pathlib import Path
import signal
import subprocess
import time
import urllib.error
import urllib.request

root = Path(__file__).resolve().parents[2]
processes = []
snapshots = {}
restored = False

def restore():
    for path, original in snapshots.items():
        if original is not None:
            if not path.exists() or path.read_bytes() != original:
                path.write_bytes(original)
        elif path.exists():
            generated = path.read_text()
            if 'BEGIN:nextjs-agent-rules' in generated or generated.strip() == '@AGENTS.md':
                path.unlink()

def interrupted(signum, frame):
    raise KeyboardInterrupt

signal.signal(signal.SIGTERM, interrupted)
try:
    for component in ('admin', 'marketing'):
        directory = root / 'apps' / component
        for filename in ('next-env.d.ts', 'tsconfig.json', 'AGENTS.md', 'CLAUDE.md'):
            path = directory / filename
            snapshots[path] = path.read_bytes() if path.exists() else None
        variables = os.environ.copy()
        if component == 'admin':
            variables['NEXT_PUBLIC_ADMIN_DEMO_MODE'] = 'true'
        else:
            # Fail closed: local preview submissions must never reach production.
            variables['NEXT_PUBLIC_CONTACT_ENDPOINT'] = 'http://127.0.0.1:9/local-preview-disabled'
        processes.append(subprocess.Popen(
            ['npm', 'run', 'dev', '--', '--hostname', '127.0.0.1'],
            cwd=directory, env=variables, start_new_session=True))
    deadline = time.monotonic() + 60
    for port, expected in ((3010, 'Overview'), (3020, 'League Hub')):
        while True:
            if any(p.poll() is not None for p in processes):
                raise RuntimeError('A development server exited during startup')
            try:
                with urllib.request.urlopen(f'http://127.0.0.1:{port}/', timeout=5) as response:
                    if response.status == 200 and expected in response.read().decode():
                        print(f'PASS web startup: port {port}, expected page content', flush=True)
                        break
            except (urllib.error.URLError, TimeoutError):
                pass
            if time.monotonic() >= deadline:
                raise RuntimeError(f'Development server on port {port} failed readiness')
            time.sleep(0.5)
    restore()
    restored = True
    print('Web development servers ready; tracked configuration preserved.', flush=True)
    while all(p.poll() is None for p in processes):
        time.sleep(1)
    raise RuntimeError('A development server exited')
except KeyboardInterrupt:
    pass
finally:
    for process in processes:
        if process.poll() is None:
            os.killpg(process.pid, signal.SIGTERM)
    for process in processes:
        try:
            process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait()
    if not restored:
        restore()
