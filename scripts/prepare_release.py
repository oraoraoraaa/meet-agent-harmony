#!/usr/bin/env python3
"""Build and verify a locally signed HarmonyOS APP; never upload or copy signing keys."""
import datetime
import hashlib
import io
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
DEVECO = Path('/Applications/DevEco-Studio.app/Contents')
SDK = DEVECO / 'sdk'
JAVA = DEVECO / 'jbr/Contents/Home/bin/java'
SIGN_TOOL = SDK / 'default/openharmony/toolchains/lib/hap-sign-tool.jar'
BUNDLE = 'com.rinalic.meetAgentHarmony'
APP_ID = '6917616810342569054'


def main():
    config = (ROOT / 'build-profile.json5').read_text()
    for field in ('storeFile', 'certpath', 'profile', 'keyAlias', 'storePassword', 'keyPassword'):
        match = re.search(r'"' + field + r'"\s*:\s*"([^"\n]+)"', config)
        if not match:
            raise RuntimeError('Configure release signing in DevEco first; missing field: ' + field)
        if field in ('storeFile', 'certpath', 'profile') and not Path(match.group(1)).is_file():
            raise RuntimeError('Signing file does not exist for field: ' + field)
    app = json.loads((ROOT / 'AppScope/app.json5').read_text())['app']
    if app['bundleName'] != BUNDLE:
        raise RuntimeError('Bundle identity changed; update AGC and this release workflow together.')
    stamp = datetime.datetime.now().strftime('%Y%m%d-%H%M%S')
    destination = Path(sys.argv[1]).expanduser().resolve() if len(sys.argv) > 1 else (
        Path.home() / 'Downloads/meet-agent-harmony/releases' / f"{app['versionName']}-{stamp}")
    if destination.exists():
        raise RuntimeError('Output directory already exists; choose a new directory.')
    env = os.environ.copy()
    env.update(PATH=str(DEVECO / 'tools/node/bin') + os.pathsep + env['PATH'],
               JAVA_HOME=str(DEVECO / 'jbr'), DEVECO_SDK_HOME=str(SDK))
    logs = ROOT / 'build/release-checks'
    logs.mkdir(parents=True, exist_ok=True)
    with (logs / 'build.log').open('w') as log:
        subprocess.run([str(DEVECO / 'tools/hvigor/bin/hvigorw'), '--mode', 'project',
                        '-p', 'product=default', '-p', 'buildMode=release', 'assembleApp', '--no-daemon'],
                       cwd=ROOT, env=env, stdout=log, stderr=log, check=True)
    source = ROOT / 'build/outputs/default/meet-agent-harmony-default-signed.app'
    with tempfile.TemporaryDirectory(prefix='meet-release-verify-') as temporary:
        work = Path(temporary)
        packages = [source]
        with zipfile.ZipFile(source) as archive:
            haps = [name for name in archive.namelist() if name.endswith('.hap')]
            if not haps:
                raise RuntimeError('APP contains no HAP modules.')
            for name in haps:
                module = name.removesuffix('.hap')
                companion = ROOT / 'entry/build/default/outputs/default' / (module + '-signed.hap')
                # APP distribution embeds unsigned module payloads; verify the matching
                # SDK-signed standalone HAP and compare its code/resources to the APP.
                with zipfile.ZipFile(io.BytesIO(archive.read(name))) as embedded, zipfile.ZipFile(companion) as signed:
                    for item in embedded.namelist():
                        left, right = embedded.read(item), signed.read(item)
                        if item == 'pack.info':
                            if json.loads(left) != json.loads(right):
                                raise RuntimeError('APP and signed HAP packaging metadata differ.')
                        elif left != right:
                            raise RuntimeError('APP and signed HAP payload differ: ' + item)
                packages.append(companion)
        with (logs / 'verification.log').open('w') as log:
            for index, package in enumerate(packages):
                profile = work / f'profile-{index}.p7b'
                subprocess.run([str(JAVA), '-jar', str(SIGN_TOOL), 'verify-app', '-inFile', str(package),
                                '-outCertChain', str(work / f'chain-{index}.cer'), '-outProfile', str(profile)],
                               stdout=log, stderr=log, check=True)
                # The SDK verifies signatures; decode module Profile to check release identity and validity.
                if index > 0:
                    decoded = subprocess.run(['openssl', 'cms', '-verify', '-inform', 'DER',
                                              '-in', str(profile), '-noverify'], capture_output=True, check=True)
                    info = json.loads(decoded.stdout)
                    identity = info['bundle-info']
                    if (info['type'] != 'release' or info['app-distribution-type'] != 'app_gallery'
                            or identity['bundle-name'] != BUNDLE or identity['app-identifier'] != APP_ID):
                        raise RuntimeError('Embedded Profile is not the expected AppGallery release identity.')
                    now = datetime.datetime.now().timestamp()
                    if not info['validity']['not-before'] <= now <= info['validity']['not-after']:
                        raise RuntimeError('Release Profile is outside its validity period.')
    destination.mkdir(parents=True)
    shutil.copy2(source, destination / source.name)
    shutil.copy2(ROOT / 'AppScope/resources/base/media/app_icon.png', destination / 'icon.png')
    symbols = ROOT / 'build/outputs/default/symbol/release/app-symbol.zip'
    if symbols.exists():
        shutil.copy2(symbols, destination / 'app-symbol.zip')
    for document in ('RELEASE.md', 'REVIEWER_NOTES.md'):
        shutil.copy2(ROOT / 'docs' / document, destination / document)
    material = Path.home() / 'Downloads/meet-agent-harmony/screenshots'
    if material.is_dir():
        target = destination / 'screenshots'
        target.mkdir()
        for screenshot in material.glob('*.png'):
            shutil.copy2(screenshot, target / screenshot.name)
    (destination / 'BUILD_INFO.json').write_text(json.dumps({
        'bundleName': BUNDLE, 'appId': APP_ID, 'versionName': app['versionName'],
        'versionCode': app['versionCode'], 'buildVersion': app.get('buildVersion'),
        'createdAt': datetime.datetime.now().astimezone().isoformat(),
        'signatureVerification': 'APP and matching standalone HAP signatures passed; embedded payloads match',
        'sourceCommit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
        'workingTreeHasChanges': bool(subprocess.check_output(['git', 'status', '--porcelain'], cwd=ROOT)),
    }, indent=2) + '\n')
    files = sorted(path for path in destination.rglob('*') if path.is_file())
    (destination / 'SHA256SUMS.txt').write_text(''.join(
        hashlib.sha256(path.read_bytes()).hexdigest() + '  ' + path.relative_to(destination).as_posix() + '\n'
        for path in files))
    print('Verified release exported to: ' + str(destination))


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        print('Release preparation stopped: ' + str(error), file=sys.stderr)
        print('Inspect local build/release-checks logs. No upload was performed.', file=sys.stderr)
        sys.exit(1)
