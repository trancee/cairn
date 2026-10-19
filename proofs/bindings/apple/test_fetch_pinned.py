import hashlib
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).with_name("fetch-pinned.sh")


class FetchPinnedTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.root = Path(self.directory.name)
        self.source = self.root / "archive.tar.gz"
        self.source.write_bytes(b"pinned archive bytes")
        self.digest = hashlib.sha256(self.source.read_bytes()).hexdigest()
        self.cache = self.root / "cache"

    def tearDown(self):
        self.directory.cleanup()

    def fetch(self, url, digest, destination, cache=True):
        environment = {"PATH": "/usr/bin:/bin"}
        if cache:
            environment["CAIRN_ARCHIVE_CACHE"] = str(self.cache)
        return subprocess.run(
            ["/bin/bash", str(SCRIPT), url, digest, str(destination)],
            capture_output=True, text=True, env=environment, timeout=10,
        )

    def test_cache_miss_downloads_verifies_and_records_the_archive(self):
        destination = self.root / "out.tar.gz"

        result = self.fetch(self.source.as_uri(), self.digest, destination)

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(destination.read_bytes(), self.source.read_bytes())
        self.assertEqual((self.cache / self.digest).read_bytes(), self.source.read_bytes())
        self.assertIn(f"{destination}: OK", result.stdout)

    def test_cache_hit_verifies_without_network(self):
        self.cache.mkdir()
        (self.cache / self.digest).write_bytes(self.source.read_bytes())
        destination = self.root / "out.tar.gz"

        result = self.fetch("file:///nonexistent/archive", self.digest, destination)

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(destination.read_bytes(), self.source.read_bytes())
        self.assertIn(f"{destination}: OK", result.stdout)

    def test_corrupted_cache_entry_fails_verification(self):
        self.cache.mkdir()
        (self.cache / self.digest).write_bytes(b"tampered")
        destination = self.root / "out.tar.gz"

        result = self.fetch(self.source.as_uri(), self.digest, destination)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("FAILED", result.stdout)

    def test_mismatched_download_fails_and_is_not_cached(self):
        destination = self.root / "out.tar.gz"
        wrong = "0" * 64

        result = self.fetch(self.source.as_uri(), wrong, destination)

        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.cache / wrong).exists())

    def test_without_a_cache_the_archive_is_downloaded_and_verified(self):
        destination = self.root / "out.tar.gz"

        result = self.fetch(self.source.as_uri(), self.digest, destination, cache=False)

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(destination.read_bytes(), self.source.read_bytes())
        self.assertFalse(self.cache.exists())

    def test_malformed_digest_is_rejected_before_any_fetch(self):
        destination = self.root / "out.tar.gz"
        for digest in ["", "../escape", "A" * 64, "0" * 63]:
            with self.subTest(digest=digest):
                result = self.fetch(self.source.as_uri(), digest, destination)

                self.assertEqual(result.returncode, 2)
                self.assertFalse(destination.exists())


if __name__ == "__main__":
    unittest.main()
