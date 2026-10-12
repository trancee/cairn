import hashlib
import importlib.util
import tempfile
import unittest
from pathlib import Path


spec = importlib.util.spec_from_file_location(
    "functional_simulator", Path(__file__).with_name("run-functional-simulator.py")
)
simulator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(simulator)


class FunctionalPayloadTest(unittest.TestCase):
    def create_payload(self, directory):
        payload = Path(directory)
        binary = payload / "CairnSimulatorSmoke.kexe"
        binary.write_bytes(b"checksum validation fixture")
        (payload / "revision.txt").write_text("a" * 40 + "\n")
        digest = hashlib.sha256(binary.read_bytes()).hexdigest()
        (payload / "payload.sha256").write_text(
            f"{digest}  CairnSimulatorSmoke.kexe\n"
        )
        return payload

    def test_verified_same_revision_payload_is_selected(self):
        with tempfile.TemporaryDirectory() as directory:
            payload = self.create_payload(directory)

            binary = simulator.verify_payload(payload, "a" * 40)

            self.assertEqual(binary, payload / "CairnSimulatorSmoke.kexe")

    def test_invalid_payload_fails_before_execution(self):
        def oversize(payload):
            with (payload / "CairnSimulatorSmoke.kexe").open("r+b") as binary:
                binary.truncate(128 * 1024 * 1024 + 1)

        cases = {
            "corruption": lambda payload: (payload / "CairnSimulatorSmoke.kexe").write_bytes(b"changed"),
            "missing": lambda payload: (payload / "CairnSimulatorSmoke.kexe").unlink(),
            "wrong-revision": lambda payload: (payload / "revision.txt").write_text("b" * 40 + "\n"),
            "outside-path": lambda payload: (payload / "payload.sha256").write_text("a" * 64 + "  ../secret\n"),
            "extra-file": lambda payload: (payload / "unexpected").touch(),
            "symlink": lambda payload: (
                (payload / "CairnSimulatorSmoke.kexe").rename(payload / "outside"),
                (payload / "CairnSimulatorSmoke.kexe").symlink_to(payload / "outside"),
                (payload / "outside").unlink(),
            ),
            "oversized": oversize,
        }
        for name, mutate in cases.items():
            with self.subTest(name=name), tempfile.TemporaryDirectory() as directory:
                payload = self.create_payload(directory)
                mutate(payload)

                with self.assertRaisesRegex(SystemExit, "FAIL: functional payload"):
                    simulator.verify_payload(payload, "a" * 40)


if __name__ == "__main__":
    unittest.main()
