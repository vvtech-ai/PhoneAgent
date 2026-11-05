"""Check the host/extension contract needed for communication notifications."""
import plistlib
from pathlib import Path
import unittest


IOS = Path(__file__).resolve().parents[1] / "ios"


def read_plist(path):
    with path.open("rb") as source:
        return plistlib.load(source)


class TrustedNotificationConfigurationTests(unittest.TestCase):
    def test_host_declares_the_donated_message_intent(self):
        host = read_plist(IOS / "Runner/Info.plist")
        self.assertIn("INSendMessageIntent", host.get("NSUserActivityTypes", []))

    def test_host_enables_communication_notifications(self):
        entitlements = read_plist(IOS / "Runner/Runner.entitlements")
        self.assertIs(
            entitlements.get("com.apple.developer.usernotifications.communication"),
            True,
        )

    def test_extension_declares_message_intent_and_service_entry(self):
        extension = read_plist(
            IOS / "TrustedCallerNotificationService/Info.plist"
        )
        self.assertIn("INSendMessageIntent", extension["NSUserActivityTypes"])
        entry = extension["NSExtension"]
        self.assertEqual(
            entry["NSExtensionPointIdentifier"], "com.apple.usernotifications.service"
        )
        self.assertEqual(entry["NSExtensionPrincipalClass"], "NotificationService")


if __name__ == "__main__":
    unittest.main()
