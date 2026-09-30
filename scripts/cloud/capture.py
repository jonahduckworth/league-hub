#!/usr/bin/env python3
"""Capture local previews only; reject all external browser requests."""
import argparse
from pathlib import Path
from urllib.parse import urlparse
from playwright.sync_api import sync_playwright

parser = argparse.ArgumentParser()
parser.add_argument('--output', default='/tmp/league-hub-captures')
args = parser.parse_args()
output = Path(args.output).resolve()
output.mkdir(parents=True, exist_ok=True)
with sync_playwright() as playwright:
    browser = playwright.chromium.launch(headless=True)
    try:
        for name, port, expected in [('admin', 3010, 'Overview'), ('marketing', 3020, 'League Hub')]:
            context = browser.new_context(viewport={'width': 1280, 'height': 800},
                                          record_video_dir=str(output), service_workers='block')
            def route_local(route):
                url = urlparse(route.request.url)
                if url.hostname == '127.0.0.1' and url.port in (3010, 3020):
                    route.continue_()
                else:
                    route.abort()
            context.route('**/*', route_local)
            page = context.new_page()
            errors = []
            page.on('pageerror', lambda error: errors.append(str(error)))
            response = page.goto(f'http://127.0.0.1:{port}/', wait_until='networkidle')
            assert response.status == 200
            assert expected in page.locator('body').inner_text()
            page.screenshot(path=str(output / f'{name}.png'), full_page=True)
            page.evaluate('window.scrollTo(0, document.body.scrollHeight)')
            page.wait_for_timeout(500)
            video = page.video
            context.close()
            video.save_as(str(output / f'{name}.webm'))
            video.delete()
            assert not errors, errors
            print(f'PASS {name}: HTTP 200, content, screenshot, video, no page errors')
    finally:
        browser.close()
