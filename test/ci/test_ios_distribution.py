"""Integration coverage for catalogue section 25's distribution workflow."""
import base64
import datetime as dt
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
HELPER = ROOT / "tool/ios_signing.py"


class DistributionProfileTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory()
        cls.folder = Path(cls.temp.name)
        cls.key = cls.folder / "key.pem"
        cls.cert = cls.folder / "certificate.pem"
        subprocess.run([
            "openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes",
            "-keyout", str(cls.key), "-out", str(cls.cert), "-days", "1",
            "-subj", "/CN=Foss Lift CI Test",
            "-addext", "basicConstraints=critical,CA:FALSE",
            "-addext", "keyUsage=critical,digitalSignature",
            "-addext", "extendedKeyUsage=codeSigning",
        ], check=True, capture_output=True)
        cls.der = subprocess.check_output([
            "openssl", "x509", "-in", str(cls.cert), "-outform", "DER",
        ])

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def profile(self, **changes):
        value = {
            "Name": "FossLiftAppStore", "UUID": "b653721e-1547-4f49-a0a3-569549b870e7",
            "TeamIdentifier": ["TEAM123456"], "ApplicationIdentifierPrefix": ["TEAM123456"],
            "ExpirationDate": dt.datetime.now(dt.timezone.utc).replace(tzinfo=None) + dt.timedelta(days=1),
            "DeveloperCertificates": [self.der],
            "Entitlements": {"application-identifier": "TEAM123456.com.fosslift.fosslift", "get-task-allow": False},
        }
        value.update(changes)
        source = self.folder / "profile.plist"
        source.write_bytes(plistlib.dumps(value))
        target = self.folder / "profile.mobileprovision"
        subprocess.run([
            "openssl", "cms", "-sign", "-binary", "-nodetach", "-in", str(source),
            "-signer", str(self.cert), "-inkey", str(self.key), "-outform", "DER", "-out", str(target),
        ], check=True, capture_output=True)
        return target

    def validate(self, path):
        return subprocess.run([
            sys.executable, str(HELPER), "validate-profile", str(path), "--certificate", str(self.cert),
        ], capture_output=True, text=True)

    def test_distribution_profile_resolves_the_app_and_team(self):
        result = self.validate(self.profile())
        self.assertEqual(result.returncode, 0, result.stderr)
        data = json.loads(result.stdout)
        self.assertEqual(data["bundle_id"], "com.fosslift.fosslift")
        self.assertEqual(data["team_id"], "TEAM123456")
        self.assertEqual(data["profile_name"], "FossLiftAppStore")

    def test_wrong_app_cannot_be_signed(self):
        result = self.validate(self.profile(Entitlements={"application-identifier": "TEAM123456.com.other.app", "get-task-allow": False}))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("profile_bundle", result.stderr)

    def test_development_and_ad_hoc_profiles_are_refused(self):
        for changes in [
            {"ProvisionedDevices": ["test-device"]}, {"ProvisionsAllDevices": True},
            {"Entitlements": {"application-identifier": "TEAM123456.com.fosslift.fosslift", "get-task-allow": True}},
        ]:
            with self.subTest(changes=changes):
                result = self.validate(self.profile(**changes))
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("profile_distribution", result.stderr)

    def test_expired_profile_is_refused(self):
        result = self.validate(self.profile(ExpirationDate=dt.datetime(2020, 1, 1)))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("profile_expired", result.stderr)

    def test_a_different_certificate_is_refused(self):
        result = self.validate(self.profile(DeveloperCertificates=[b"another certificate"]))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("profile_certificate", result.stderr)

    def test_invalid_cms_does_not_reach_signing(self):
        path = self.folder / "invalid.mobileprovision"
        path.write_bytes(b"not a provisioning profile")
        result = self.validate(path)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("profile_decode", result.stderr)

    def test_build_numbers_are_positive_integers(self):
        for value in ["0", "-1", "29; echo unsafe", "abc"]:
            result = subprocess.run([sys.executable, str(HELPER), "validate-build-number", value], capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("build_number", result.stderr)
        subprocess.run([sys.executable, str(HELPER), "validate-build-number", "29"], check=True, capture_output=True)

    @unittest.skipUnless(sys.platform == "darwin", "Apple keychain integration needs macOS")
    def test_macos_prepares_app_signing_and_removes_temporary_credentials(self):
        # All keys in this test are generated fixtures, never repository secrets.
        p12 = self.folder / "fixture.p12"
        subprocess.run([
            "openssl", "pkcs12", "-export", "-inkey", str(self.key), "-in", str(self.cert),
            "-out", str(p12), "-passout", "pass:fixture-password",
            "-keypbe", "PBE-SHA1-3DES", "-certpbe", "PBE-SHA1-3DES", "-macalg", "sha1",
        ], check=True, capture_output=True)
        runner = self.folder / "runner"
        runner.mkdir()
        profile = self.profile()
        env = {
            **os.environ, "RUNNER_TEMP": str(runner), "GITHUB_ENV": str(runner / "env"),
            "IOS_DISTRIBUTION_P12_BASE64": base64.b64encode(p12.read_bytes()).decode(),
            "IOS_PROVISION_PROFILE_BASE64": base64.b64encode(profile.read_bytes()).decode(),
            "IOS_P12_PASSWORD": "fixture-password",
        }
        before = subprocess.check_output(["security", "list-keychains", "-d", "user"])
        root = runner / "foss-lift-signing"
        installed = None
        try:
            result = subprocess.run([sys.executable, str(HELPER), "prepare"], env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            state = json.loads((root / "state.json").read_text())
            installed = Path(state["installed_profiles"][0])
            self.assertEqual(installed.read_bytes(), profile.read_bytes())
            self.assertFalse((root / "identity.p12").exists())
            project = self.folder / "Runner.xcodeproj"
            shutil.copytree(ROOT / "ios/Runner.xcodeproj", project)
            subprocess.run([
                "ruby", str(ROOT / "tool/configure_ios_signing.rb"), str(root / "state.json"), str(project),
            ], check=True, capture_output=True)
            configured = subprocess.check_output([
                "ruby", "-rjson", "-rxcodeproj", "-e",
                "p = Xcodeproj::Project.open(ARGV[0]); puts JSON.generate(p.targets.find { |t| t.name == 'Runner' }.build_configurations.map(&:build_settings))",
                str(project),
            ])
            for settings in json.loads(configured):
                self.assertEqual(settings["CODE_SIGN_STYLE"], "Manual")
                self.assertEqual(settings["DEVELOPMENT_TEAM"], "TEAM123456")
                self.assertEqual(settings["PROVISIONING_PROFILE_SPECIFIER"], state["profile_uuid"])
                self.assertEqual(settings["CODE_SIGN_IDENTITY[sdk=iphoneos*]"], state["identity_sha1"])
            options = plistlib.loads(Path(state["export_options"]).read_bytes())
            self.assertEqual(options["method"], "app-store-connect")
            self.assertEqual(options["provisioningProfiles"], {"com.fosslift.fosslift": state["profile_uuid"]})
            checkout = root / "fixture-checkout"
            app = checkout / "build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app"
            executable = app / "Fixture"
            app.mkdir(parents=True)
            sdk = subprocess.check_output(["xcrun", "--sdk", "iphoneos", "--show-sdk-path"], text=True).strip()
            subprocess.run([
                "xcrun", "--sdk", "iphoneos", "clang", "-target", "arm64-apple-ios14.0", "-isysroot", sdk,
                "-x", "c", "-o", str(executable), "-",
            ], input=b"int main(void) { return 0; }", check=True, capture_output=True)
            (app / "Info.plist").write_bytes(plistlib.dumps({
                "CFBundleIdentifier": "com.fosslift.fosslift", "CFBundleExecutable": "Fixture",
                "CFBundleVersion": "29", "CFBundlePackageType": "APPL",
                "CFBundleSupportedPlatforms": ["iPhoneOS"],
            }))
            shutil.copyfile(profile, app / "embedded.mobileprovision")
            subprocess.run([
                "codesign", "--force", "--sign", state["identity_sha1"], "--keychain", state["keychain"], str(app),
            ], check=True, capture_output=True)
            payload = root / "Payload"
            shutil.copytree(app, payload / "Runner.app")
            ipa = checkout / "build/ios/ipa/Fixture.ipa"
            ipa.parent.mkdir(parents=True)
            subprocess.run([
                "ditto", "-c", "-k", "--keepParent", str(payload), str(ipa),
            ], check=True, capture_output=True)
            verify_env = {**env, "IOS_SIGNING_STATE": str(root / "state.json")}
            verified = subprocess.run([
                sys.executable, str(HELPER), "verify-ipa", "29",
            ], cwd=checkout, env=verify_env, capture_output=True, text=True)
            self.assertEqual(verified.returncode, 0, verified.stderr)
            state["identity_sha1"] = "A" * 40
            (root / "state.json").write_text(json.dumps(state))
            mismatched = subprocess.run([
                sys.executable, str(HELPER), "verify-ipa", "29",
            ], cwd=checkout, env=verify_env, capture_output=True, text=True)
            self.assertNotEqual(mismatched.returncode, 0)
            self.assertIn("ipa_certificate_mismatch", mismatched.stderr)
        finally:
            result = subprocess.run([sys.executable, str(HELPER), "cleanup"], env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(root.exists())
        if installed:
            self.assertFalse(installed.exists())
        self.assertEqual(subprocess.check_output(["security", "list-keychains", "-d", "user"]), before)


if __name__ == "__main__":
    unittest.main()
