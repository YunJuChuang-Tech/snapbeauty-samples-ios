"""Prepare host resources and official RTC binaries; SnapBeauty is a remote Swift package."""
import argparse
import hashlib
import json
import platform
import shutil
import subprocess
import tempfile
import uuid
from concurrent.futures import ThreadPoolExecutor
import urllib.request
import zipfile
from pathlib import Path

IOS = Path(__file__).resolve().parents[1]
LOCAL = IOS / ".local"
VERSIONS = {"TXLiteAVSDK_TRTC": "13.5.21355", "AgoraRtcEngine_iOS": "4.6.4", "AgoraInfra_iOS": "1.3.5", "ZegoExpressEngine": "3.25.0"}
WANTED = {"TXLiteAVSDK_TRTC", "TXSoundTouch", "TXFFmpeg", "AgoraRtcKit", "Agorafdkaac", "Agoraffmpeg", "AgoraSoundTouch", "video_dec", "aosl", "ZegoExpressEngine"}


def download(url, output):
    if not output.is_file():
        output.parent.mkdir(parents=True, exist_ok=True)
        print("Download: " + url, flush=True)
        temporary = output.with_suffix(output.suffix + ".part")
        with urllib.request.urlopen(url, timeout=180) as response, temporary.open("wb") as dest:
            shutil.copyfileobj(response, dest)
        temporary.replace(output)
    return hashlib.sha256(output.read_bytes()).hexdigest()


def rtc():
    cache = LOCAL / "downloads"
    locked = {item["name"]: item for item in json.loads((IOS / "dependencies.lock.json").read_text())}
    receipt = []
    for name, version in VERSIONS.items():
        shard = "/".join(hashlib.md5(name.encode()).hexdigest()[:3])
        spec_url = f"https://raw.githubusercontent.com/CocoaPods/Specs/master/Specs/{shard}/{name}/{version}/{name}.podspec.json"
        spec_file = cache / f"{name}-{version}.json"
        spec_sha = download(spec_url, spec_file)
        expected = locked[name]
        if expected["version"] != version or expected["specSha256"] != spec_sha:
            raise RuntimeError("Official podspec differs from the reviewed dependency lock: " + name)
        spec = json.loads(spec_file.read_text())
        url = spec["source"]["http"]
        archive = cache / f"{name}-{version}.zip"
        sha = download(url, archive)
        if expected["url"] != url or expected["sha256"] != sha:
            raise RuntimeError("Official SDK archive differs from the dependency lock: " + name)
        expanded = LOCAL / "vendors" / name
        if not (expanded / ".ready").is_file():
            with zipfile.ZipFile(archive) as z:
                # Archives are official HTTPS downloads; reject escaping paths before extraction.
                for item in z.namelist():
                    assert (expanded / item).resolve().is_relative_to(expanded.resolve())
                z.extractall(expanded)
            (expanded / ".ready").write_text(sha)
        receipt.append(dict(name=name, version=version, spec=spec_url, specSha256=spec_sha, url=url, sha256=sha))
    (LOCAL / "rtc-receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
    print("RTC dependencies ready", flush=True)


def host_assets():
    """Prepare only the example's own makeup and optional local SDK license."""
    LOCAL.mkdir(exist_ok=True)
    host_assets = IOS / "HostAssetsSource"
    manifest = json.loads((host_assets / "sample_makeup/manifest.json").read_text(encoding="utf-8"))
    if len(manifest.get("files", {})) != 53:
        raise ValueError("Unexpected shared makeup manifest")
    for relative, record in manifest["files"].items():
        path = (host_assets / relative).resolve()
        if not path.is_relative_to((host_assets / "makeup").resolve()) or hashlib.sha256(path.read_bytes()).hexdigest() != record["sha256"]:
            raise ValueError("Shared makeup checksum differs: " + relative)
    with tempfile.TemporaryDirectory(prefix="host-assets-stage-", dir=LOCAL) as temporary:
        source = Path(temporary) / "HostAssets"
        assets = source / "Assets"
        assets.mkdir(parents=True)
        for folder in ["makeup", "sample_makeup"]:
            shutil.copytree(host_assets / folder, assets / folder)
        license_file = LOCAL / "snapbeauty.license"
        if not license_file.is_file():
            license_file = IOS / "SampleLicense/snapbeauty.license"
        if license_file.is_file():
            shutil.copy2(license_file, assets / "snapbeauty.license")
        destination = LOCAL / "HostAssets"
        if destination.exists():
            destination.rename(LOCAL / ("HostAssets-backup-" + uuid.uuid4().hex))
        source.rename(destination)
    print("Host makeup assets prepared; SDK comes from Swift Package Manager", flush=True)


def project():
    (LOCAL / "Verification").mkdir(exist_ok=True)
    deps = [{"package": "SnapBeautySDK", "product": "SnapBeautySDK"}]
    for name in sorted(WANTED):
        matches = list((LOCAL / "vendors").rglob(name + ".xcframework"))
        if not matches:
            raise RuntimeError("Missing official framework: " + name)
        deps.append({"framework": matches[0].relative_to(IOS).as_posix(), "embed": True})
    for framework in ["AVFoundation", "Metal", "CoreVideo", "CoreMedia", "CoreImage", "MetalKit", "Accelerate", "AudioToolbox", "VideoToolbox", "Network", "SystemConfiguration", "CoreTelephony", "Photos", "ReplayKit"]:
        deps.append({"sdk": framework + ".framework"})
    for library in ["libc++.tbd", "libz.tbd", "libsqlite3.tbd", "libresolv.tbd"]:
        deps.append({"sdk": library})
    spec = {"name": "SnapBeautySamples", "packages": {"SnapBeautySDK": {"url": "https://github.com/YunJuChuang-Tech/snapbeauty-ios-sdk.git", "exactVersion": "1.3.0"}}, "options": {"deploymentTarget": {"iOS": "15.0"}},
        "settings": {"base": {"SWIFT_VERSION": "5.0", "CLANG_CXX_LANGUAGE_STANDARD": "c++17", "IPHONEOS_DEPLOYMENT_TARGET": "15.0", "ENABLE_BITCODE": "NO"}},
        "targets": {"SnapBeautySamples": {"type": "application", "platform": "iOS",
            "sources": [{"path": "App"}, {"path": "Bridge"}, {"path": ".local/HostAssets/Assets", "type": "folder", "buildPhase": "resources"}],
            "settings": {"base": {"PRODUCT_BUNDLE_IDENTIFIER": "ai.snapbeauty.samples", "INFOPLIST_FILE": "Info.plist", "SWIFT_OBJC_BRIDGING_HEADER": "Bridge/SnapBeautySamples-Bridging-Header.h", "HEADER_SEARCH_PATHS": ["$(inherited)"], "OTHER_CPLUSPLUSFLAGS": ["$(inherited)", "-ffp-contract=off", "-fno-fast-math"], "TARGETED_DEVICE_FAMILY": "1,2", "MARKETING_VERSION": "0.1.6", "CURRENT_PROJECT_VERSION": "8", "GENERATE_INFOPLIST_FILE": "NO", "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon"}},
            "dependencies": deps},
            "SnapBeautySamplesTests": {"type": "bundle.unit-test", "platform": "iOS", "sources": ["Tests", {"path": ".local/Verification", "type": "folder", "buildPhase": "resources"}], "dependencies": [{"target": "SnapBeautySamples"}], "settings": {"base": {"PRODUCT_BUNDLE_IDENTIFIER": "ai.snapbeauty.samples.tests", "GENERATE_INFOPLIST_FILE": "YES"}}},
            "SnapBeautySamplesUITests": {"type": "bundle.ui-testing", "platform": "iOS", "sources": ["UITests"], "dependencies": [{"target": "SnapBeautySamples"}], "settings": {"base": {"PRODUCT_BUNDLE_IDENTIFIER": "ai.snapbeauty.samples.uitests", "GENERATE_INFOPLIST_FILE": "YES"}}}},
        "schemes": {"SnapBeautySamples": {"build": {"targets": {"SnapBeautySamples": "all", "SnapBeautySamplesTests": ["test"], "SnapBeautySamplesUITests": ["test"]}}, "test": {"targets": ["SnapBeautySamplesTests", "SnapBeautySamplesUITests"]}}}}
    (IOS / "project.json").write_text(json.dumps(spec, indent=2) + "\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host-only", action="store_true", help="Prepare local example makeup and optional license without RTC downloads")
    parser.add_argument("--rtc-only", action="store_true", help="Prepare only RTC dependencies")
    args = parser.parse_args()
    if args.host_only and args.rtc_only:
        parser.error("--host-only and --rtc-only cannot be combined")
    if not args.rtc_only:
        host_assets()
    if args.host_only:
        raise SystemExit(0)
    if platform.system() != "Darwin":
        parser.error("RTC preparation requires macOS/Xcode; use --host-only on other systems")
    LOCAL.mkdir(exist_ok=True)
    rtc()
    if not args.rtc_only:
        project()
