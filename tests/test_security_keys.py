import os
from pathlib import Path
import queue
import sys
import tempfile
import threading
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'lib'))
import security_keys as keys


class Stop(Exception):
    pass


class SecurityKeyTests(unittest.TestCase):
    def test_counts_follow_open_and_close_of_known_markers_only(self):
        counts = keys.update({}, 'pam-u2f-sudo.pending', keys.IN_OPEN)
        counts = keys.update(counts, 'pam-u2f-sudo.pending', keys.IN_OPEN)
        self.assertEqual(counts, {'pam-u2f-sudo.pending': 2})
        counts = keys.update(counts, 'pam-u2f-sudo.pending', 0x10)
        self.assertEqual(counts, {'pam-u2f-sudo.pending': 1})
        self.assertEqual(keys.update(counts, 'unrelated', keys.IN_OPEN), counts)
        self.assertEqual(keys.update({}, 'pam-u2f-lock.pending', 0x08), {})

    def test_rejects_shared_runtime_directory(self):
        with tempfile.TemporaryDirectory() as d:
            os.chmod(d, 0o755)
            with self.assertRaises(ValueError):
                keys.watch(d, lambda value: None)

    def test_reports_a_waiting_key_until_its_marker_closes(self):
        with tempfile.TemporaryDirectory() as d:
            os.chmod(d, 0o700)
            # A marker left by a previous watcher is reused, not reopened.
            Path(d, 'pam-u2f-lock.pending').touch(mode=0o600)
            seen, done = queue.Queue(), threading.Event()
            def output(value):
                seen.put(value['pending'])
                if done.is_set():
                    raise Stop()
            def run():
                try:
                    keys.watch(d, output)
                except Stop:
                    pass
            worker = threading.Thread(target=run, daemon=True)
            worker.start()
            self.assertEqual(seen.get(timeout=5), [])
            marker = open(Path(d, 'pam-u2f-sudo.pending'))
            self.assertEqual(seen.get(timeout=5), ['sudo'])
            done.set()
            marker.close()
            self.assertEqual(seen.get(timeout=5), [])
            worker.join(timeout=5)
            self.assertFalse(worker.is_alive())


if __name__ == '__main__':
    unittest.main()
