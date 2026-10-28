"""Prepare isolated macOS signing and explicitly requested TestFlight uploads."""
import argparse
import base64
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import secrets
import shlex
import shutil
import subprocess
import sys
import uuid
import zipfile

BUNDLE_ID = "com.fosslift.fosslift"


class SigningError(Exception):
    pass


def run(args, *, data=None, env=None, error="signing_command_failed"):
    result = subprocess.run(args, input=data, capture_output=True, env=env)
    if result.returncode:
        # Arguments can contain a keychain or P12 password. Never print them.
        raise SigningError(error)
    return result.stdout


def private_file(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    with os.fdopen(os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600), "wb") as file:
        file.write(data)
    path.chmod(0o600)


def required(name):
    value = os.environ.get(name, "")
    if not value:
        raise SigningError(f"missing_secret: {name}")
    return value


def decode_profile(path):
    # This extracts metadata, not a substitute for Xcode's Apple signature checks.
    content = run(["openssl", "cms", "-verify", "-inform", "DER", "-in", str(path),
                   "-noverify", "-nosigs"], error="profile_decode")
    try:
        return plistlib.loads(content)
    except Exception:
        raise SigningError("profile_decode") from None


def profile_metadata(profile, certificate=None):
    entitlements = profile.get("Entitlements", {})
    teams = profile.get("TeamIdentifier", [])
    prefixes = profile.get("ApplicationIdentifierPrefix", [])
    if not teams or not re.fullmatch(r"[A-Z0-9]{10}", teams[0]):
        raise SigningError("profile_team")
    if not prefixes or entitlements.get("application-identifier") != f"{prefixes[0]}.{BUNDLE_ID}":
        raise SigningError("profile_bundle: expected com.fosslift.fosslift")
    if entitlements.get("get-task-allow") is not False or "ProvisionedDevices" in profile or profile.get("ProvisionsAllDevices"):
        raise SigningError("profile_distribution: use an App Store Connect distribution profile")
    expiry = profile.get("ExpirationDate")
    if not isinstance(expiry, dt.datetime) or expiry.replace(tzinfo=dt.timezone.utc) <= dt.datetime.now(dt.timezone.utc):
        raise SigningError("profile_expired")
    certificates = profile.get("DeveloperCertificates", [])
    if not certificates or any(not isinstance(cert, bytes) for cert in certificates):
        raise SigningError("profile_certificate")
    if certificate is not None and certificate not in certificates:
        raise SigningError("profile_certificate: certificate does not belong to this profile")
    try:
        uuid.UUID(profile["UUID"])
    except Exception:
        raise SigningError("profile_uuid") from None
    if not isinstance(profile.get("Name"), str) or not profile["Name"].strip():
        raise SigningError("profile_name")
    return {
        "bundle_id": BUNDLE_ID, "team_id": teams[0], "profile_uuid": profile["UUID"],
        "profile_name": profile["Name"], "expires": expiry.isoformat(),
        "certificate_sha1s": [hashlib.sha1(cert).hexdigest().upper() for cert in certificates],
    }


def build_number(value):
    if not re.fullmatch(r"[1-9][0-9]{0,8}", value):
        raise SigningError("build_number: enter a positive integer, such as 29")
    return value


def root_dir():
    return Path(required("RUNNER_TEMP")) / "foss-lift-signing"


def save_state(root, state):
    private_file(root / "state.json", json.dumps(state).encode())


def prepare():
    if sys.platform != "darwin":
        raise SigningError("signing_requires_macos")
    password = required("IOS_P12_PASSWORD")
    try:
        p12 = base64.b64decode(required("IOS_DISTRIBUTION_P12_BASE64"), validate=True)
        profile_data = base64.b64decode(required("IOS_PROVISION_PROFILE_BASE64"), validate=True)
    except ValueError:
        raise SigningError("signing_files_must_be_base64") from None
    root = root_dir()
    root.mkdir(mode=0o700, parents=True, exist_ok=True)
    profile_path, p12_path = root / "profile.mobileprovision", root / "identity.p12"
    private_file(profile_path, profile_data)
    state = profile_metadata(decode_profile(profile_path))
    previous = shlex.split(run(["security", "list-keychains", "-d", "user"]).decode())
    keychain = root / "signing.keychain-db"
    state.update(keychain=str(keychain), previous_keychains=previous, installed_profiles=[])
    save_state(root, state)
    private_file(p12_path, p12)
    keychain_password = secrets.token_hex(32)
    try:
        run(["security", "create-keychain", "-p", keychain_password, str(keychain)], error="keychain_create")
        run(["security", "set-keychain-settings", "-lut", "21600", str(keychain)])
        run(["security", "unlock-keychain", "-p", keychain_password, str(keychain)])
        run(["security", "import", str(p12_path), "-k", str(keychain), "-P", password,
             "-T", "/usr/bin/codesign", "-T", "/usr/bin/security"], error="p12_import: check IOS_P12_PASSWORD and the signing package")
        run(["security", "set-key-partition-list", "-S", "apple-tool:,apple:", "-s", "-k", keychain_password, str(keychain)])
        run(["security", "list-keychains", "-d", "user", "-s", str(keychain), *previous])
        identities = run(["security", "find-identity", "-p", "codesigning", str(keychain)]).decode()
        matches = {value.upper() for value in re.findall(r'([A-Fa-f0-9]{40}) "', identities)}
        available = matches.intersection(state["certificate_sha1s"])
        if len(available) != 1:
            raise SigningError("profile_certificate: imported identity does not match the profile")
        state["identity_sha1"] = available.pop()
        destination = Path.home() / "Library/Developer/Xcode/UserData/Provisioning Profiles" / f'{state["profile_uuid"]}.mobileprovision'
        if destination.exists():
            raise SigningError("profile_already_installed: refusing to overwrite another profile")
        state["installed_profiles"].append(str(destination))
        save_state(root, state)
        private_file(destination, profile_data)
        options = {
            "method": "app-store-connect", "signingStyle": "manual", "teamID": state["team_id"],
            "signingCertificate": state["identity_sha1"], "stripSwiftSymbols": True,
            "provisioningProfiles": {BUNDLE_ID: state["profile_uuid"]},
        }
        export_path = root / "ExportOptions.plist"
        private_file(export_path, plistlib.dumps(options))
        state["export_options"] = str(export_path)
        save_state(root, state)
        with open(required("GITHUB_ENV"), "a") as file:
            file.write(f'IOS_SIGNING_STATE={root / "state.json"}\nIOS_EXPORT_OPTIONS={export_path}\n')
        print(f"Signing identity and App Store profile prepared for {BUNDLE_ID}.")
    finally:
        p12_path.unlink(missing_ok=True)


def cleanup():
    root = root_dir()
    path = root / "state.json"
    if path.exists():
        state = json.loads(path.read_text())
        subprocess.run(["security", "list-keychains", "-d", "user", "-s", *state.get("previous_keychains", [])], capture_output=True)
        subprocess.run(["security", "delete-keychain", state["keychain"]], capture_output=True)
        profile_folder = Path.home() / "Library/Developer/Xcode/UserData/Provisioning Profiles"
        for name in state.get("installed_profiles", []):
            target = Path(name)
            if target.parent == profile_folder:
                target.unlink(missing_ok=True)
    shutil.rmtree(root, ignore_errors=True)
    print("Temporary signing material removed.")


def verify_ipa(number):
    state = json.loads(Path(required("IOS_SIGNING_STATE")).read_text())
    files = list(Path("build/ios/ipa").glob("*.ipa"))
    if len(files) != 1:
        raise SigningError("ipa_missing_or_ambiguous")
    with zipfile.ZipFile(files[0]) as archive:
        info_files = [name for name in archive.namelist() if re.fullmatch(r"Payload/[^/]+\.app/Info.plist", name)]
        if len(info_files) != 1:
            raise SigningError("ipa_app_identity")
        info = plistlib.loads(archive.read(info_files[0]))
        if info.get("CFBundleIdentifier") != BUNDLE_ID or info.get("CFBundleVersion") != number:
            raise SigningError("ipa_app_identity_or_build_number")
        profile_name = info_files[0].removesuffix("Info.plist") + "embedded.mobileprovision"
        embedded = root_dir() / "exported.mobileprovision"
        private_file(embedded, archive.read(profile_name))
        metadata = profile_metadata(decode_profile(embedded))
        if metadata["profile_uuid"] != state["profile_uuid"]:
            raise SigningError("ipa_profile_mismatch")
    app = Path("build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app")
    run(["codesign", "--verify", "--deep", "--strict", str(app)], error="archive_signature_invalid")
    exported = root_dir() / "verified-ipa"
    run(["ditto", "-x", "-k", str(files[0]), str(exported)], error="ipa_extract_failed")
    exported_app = exported / info_files[0].removesuffix("/Info.plist")
    run(["codesign", "--verify", "--deep", "--strict", str(exported_app)], error="ipa_signature_invalid")
    certificate_prefix = root_dir() / "ipa-certificate-"
    run(["codesign", "-d", "--extract-certificates", str(certificate_prefix), str(exported_app)], error="ipa_certificate_missing")
    certificate = Path(f"{certificate_prefix}0").read_bytes()
    if hashlib.sha1(certificate).hexdigest().upper() != state["identity_sha1"]:
        raise SigningError("ipa_certificate_mismatch")
    print(f"Verified signed IPA: {BUNDLE_ID}, build {number}.")


def upload():
    key_id, issuer = required("ASC_API_KEY_ID"), required("ASC_API_ISSUER_ID")
    if not re.fullmatch(r"[A-Z0-9]{10}", key_id):
        raise SigningError("invalid_ASC_API_KEY_ID")
    try:
        uuid.UUID(issuer)
    except ValueError:
        raise SigningError("invalid_ASC_API_ISSUER_ID") from None
    key = required("ASC_API_PRIVATE_KEY")
    if "-----BEGIN PRIVATE KEY-----" not in key:
        raise SigningError("ASC_API_PRIVATE_KEY_must_contain_the_raw_p8_file")
    files = list(Path("build/ios/ipa").glob("*.ipa"))
    if len(files) != 1:
        raise SigningError("ipa_missing_or_ambiguous")
    key_dir = root_dir() / "private_keys"
    key_file = key_dir / f"AuthKey_{key_id}.p8"
    private_file(key_file, key.encode())
    try:
        env = {**os.environ, "API_PRIVATE_KEYS_DIR": str(key_dir)}
        result = subprocess.run([
            "xcrun", "altool", "--upload-app", "--type", "ios", "-f", str(files[0]),
            "--apiKey", key_id, "--apiIssuer", issuer,
        ], capture_output=True, text=True, env=env)
        output = result.stdout + result.stderr
        output = output.replace(key, "[private key redacted]")
        output = re.sub(r"eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+", "[token redacted]", output)
        print(output)
        if result.returncode:
            raise SigningError("app_store_upload_failed")
        print("Upload accepted. Check App Store Connect for processing; beta review and invitations remain manual.")
    finally:
        key_file.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    check = sub.add_parser("validate-profile")
    check.add_argument("profile", type=Path)
    check.add_argument("--certificate", type=Path)
    number = sub.add_parser("validate-build-number")
    number.add_argument("number")
    for name in ["prepare", "cleanup", "upload"]:
        sub.add_parser(name)
    verify = sub.add_parser("verify-ipa")
    verify.add_argument("number")
    args = parser.parse_args()
    if args.command == "validate-profile":
        certificate = None
        if args.certificate:
            certificate = run(["openssl", "x509", "-in", str(args.certificate), "-outform", "DER"], error="profile_certificate")
        print(json.dumps(profile_metadata(decode_profile(args.profile), certificate)))
    elif args.command == "validate-build-number":
        print(build_number(args.number))
    elif args.command == "prepare":
        prepare()
    elif args.command == "cleanup":
        cleanup()
    elif args.command == "verify-ipa":
        verify_ipa(build_number(args.number))
    elif args.command == "upload":
        upload()


if __name__ == "__main__":
    try:
        main()
    except SigningError as error:
        print(f"Signing setup failed: {error}", file=sys.stderr)
        sys.exit(1)
