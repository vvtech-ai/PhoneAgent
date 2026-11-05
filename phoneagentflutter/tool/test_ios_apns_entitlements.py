"""Validate each Runner configuration uses matching APNs entitlement inputs."""
from pathlib import Path
import plistlib
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]


class APNSEntitlementsTests(unittest.TestCase):
    def test_each_runner_configuration_has_matching_entitlements(self):
        project = plistlib.loads(subprocess.check_output([
            "plutil", "-convert", "xml1", "-o", "-",
            str(ROOT / "ios/Runner.xcodeproj/project.pbxproj")]))
        objects = project["objects"]
        runner = next(o for o in objects.values()
                      if o.get("isa") == "PBXNativeTarget" and o.get("name") == "Runner")
        configs = objects[runner["buildConfigurationList"]]["buildConfigurations"]
        seen = set()
        for identifier in configs:
            config = objects[identifier]
            name = config["name"]
            with self.subTest(configuration=name):
                seen.add(name)
                settings = config["buildSettings"]
                entitlements = plistlib.loads((ROOT / "ios" / settings["CODE_SIGN_ENTITLEMENTS"]).read_bytes())
                self.assertEqual(entitlements.get("aps-environment"), "$(TRUSTED_CALLER_APNS_ENVIRONMENT)")
                self.assertEqual(settings["TRUSTED_CALLER_APNS_ENVIRONMENT"],
                                 "production" if name == "Release" else "development")
                self.assertTrue(entitlements["com.apple.developer.associated-domains"])
                self.assertIs(entitlements.get("com.apple.developer.usernotifications.communication"), True)
        self.assertEqual(seen, {"Debug", "Profile", "Release"})


if __name__ == "__main__":
    unittest.main()
