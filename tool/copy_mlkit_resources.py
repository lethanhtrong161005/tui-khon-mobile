"""Xcode build phase: copy the Latin OCR model from the resolved Flutter plugin.

Models stay owned/versioned by pubspec.lock rather than duplicated in Git.
"""
import json
import os
from pathlib import Path
import shutil
from urllib.parse import urljoin, urlparse, unquote

project = Path(__file__).resolve().parents[1]
config = project / '.dart_tool/package_config.json'
packages = json.loads(config.read_text())['packages']
package = next(p for p in packages if p['name'] == 'google_mlkit_text_recognition')
root = Path(unquote(urlparse(urljoin(config.as_uri(), package['rootUri'])).path))
source = root / 'ios/google_mlkit_text_recognition/Sources/google_mlkit_text_recognition/LatinOCRResources.bundle'
if not source.is_dir():
    raise SystemExit('Latin OCR resources missing. Run flutter pub get.')
target = Path(os.environ['TARGET_BUILD_DIR']) / os.environ['UNLOCALIZED_RESOURCES_FOLDER_PATH'] / source.name
shutil.copytree(source, target, dirs_exist_ok=True)
