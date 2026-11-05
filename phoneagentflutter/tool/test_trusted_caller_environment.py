"""Compile public environment gates using synthetic credentials only."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


class TrustedEnvironmentTests(unittest.TestCase):
    def test_missing_invalid_test_and_production_macros(self):
        project = Path(__file__).resolve().parents[1]
        source = project / "ios/TrustedCallerSDK/Classes"
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            classes = root / "Classes"
            classes.mkdir()
            generated = root / "Generated"
            generated.mkdir()
            for name in ["TrustedCallerSDKAvailability", "TrustedCallerConfiguration"]:
                for suffix in ["h", "m"]:
                    shutil.copyfile(source / f"{name}.{suffix}", classes / f"{name}.{suffix}")
            (generated / "TrustedCallerLocalCredentials.h").write_text(
                "#import <Foundation/Foundation.h>\n"
                "@interface TrustedCallerLocalCredentials : NSObject\n"
                "+ (NSString *)appKey;\n+ (NSString *)appSecret;\n@end\n"
            )
            (generated / "TrustedCallerLocalCredentials.m").write_text(
                '#import "TrustedCallerLocalCredentials.h"\n'
                "int syntheticCredentialReads = 0;\n"
                "@implementation TrustedCallerLocalCredentials\n"
                '+ (NSString *)appKey { syntheticCredentialReads++; return @"synthetic-key"; }\n'
                '+ (NSString *)appSecret { syntheticCredentialReads++; return @"synthetic-secret"; }\n'
                "@end\n"
            )
            main = root / "main.m"
            main.write_text(
                '#import "Classes/TrustedCallerSDKAvailability.h"\n'
                '#import "Classes/TrustedCallerConfiguration.h"\n'
                "extern int syntheticCredentialReads;\n"
                "int main(int argc, char **argv) { @autoreleasepool {\n"
                "NSString *expected = [NSString stringWithUTF8String:argv[1]];\n"
                'NSCAssert([TrustedCallerSDKAvailability.sdkEnvironment isEqual:expected], @"Environment mismatch");\n'
                "NSDictionary *credentials = TrustedCallerConfiguration.credentials;\n"
                'BOOL configured = ![expected isEqual:@"unavailable"];\n'
                'NSCAssert((credentials != nil) == configured, @"Configuration gate mismatch");\n'
                'NSCAssert(syntheticCredentialReads == (configured ? 2 : 0), @"Unexpected credential access");\n'
                "} return 0; }\n"
            )
            for macro, expected in [(None, "unavailable"), ("2", "unavailable"),
                                    ("1", "test"), ("0", "pro")]:
                with self.subTest(macro=macro):
                    output = root / "environment-test"
                    command = ["xcrun", "clang", "-fobjc-arc", "-fblocks",
                               "-DTARGET_OS_SIMULATOR=1", "-framework", "Foundation"]
                    if macro is not None:
                        command.append(f"-DPHONEAGENT_TRUSTED_SDK_TEST={macro}")
                    command += [str(main), str(classes / "TrustedCallerSDKAvailability.m"),
                                str(classes / "TrustedCallerConfiguration.m"),
                                str(generated / "TrustedCallerLocalCredentials.m"), "-o", str(output)]
                    subprocess.run(command, check=True, capture_output=True)
                    subprocess.run([str(output), expected], check=True, capture_output=True)


if __name__ == "__main__":
    unittest.main()
