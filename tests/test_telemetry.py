import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'lib'))
import telemetry as t


class TelemetryTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.proc, self.sys = self.base/'proc', self.base/'sys'
        self.write('proc/stat', 'cpu 100 0 100 800 0 0 0 0 40 0\n')
        self.write('proc/meminfo', 'MemTotal: 1000 kB\nMemAvailable: 600 kB\nSwapTotal: 100 kB\nSwapFree: 70 kB\n')
        self.write('proc/cpuinfo', 'processor : 0\nmodel name : Test CPU\nprocessor : 1\n')
        self.write('proc/loadavg', '1.0 2.0 3.0 1/20 123')
        self.write('proc/uptime', '12345.5 10000')
        self.write('proc/net/dev', 'Inter-|\n face |\n eth0: 100 0 0 0 0 0 0 0 200 0\n')
        self.sampler = t.Sampler(self.proc, self.sys, home=self.base)
        self.sampler.nvidia = None

    def write(self, path, value):
        file = self.base/path
        file.parent.mkdir(parents=True, exist_ok=True)
        file.write_text(value)
        return file

    def test_cpu_deltas_do_not_double_count_guest_and_reset_safely(self):
        self.assertIsNone(self.sampler.sample(10)['cpu']['usage'])
        self.write('proc/stat', 'cpu 120 0 110 870 0 0 0 0 60 0\n')
        self.assertEqual(self.sampler.sample(12)['cpu']['usage'], 30)
        self.write('proc/stat', 'cpu 0 0 0 0 0 0 0 0\n')
        self.assertIsNone(self.sampler.sample(14)['cpu']['usage'])

    def test_memory_uses_available_instead_of_counting_reclaimable_cache(self):
        result = self.sampler.sample(10)
        self.assertEqual(result['memory']['usage'], 40)
        self.assertEqual(result['memory']['swapUsed'], 30*1024)
        self.assertEqual(result['cpu']['threads'], 2)
        self.assertEqual(result['uptime'], 12345.5)

    def test_missing_devices_and_sensor_removal_do_not_leave_stale_values(self):
        self.write('sys/class/hwmon/hwmon0/name', 'coretemp')
        sensor = self.write('sys/class/hwmon/hwmon0/temp1_input', '44000')
        self.assertEqual(self.sampler.sample(10)['cpu']['temperature'], 44)
        sensor.unlink()
        result = self.sampler.sample(12)
        self.assertIsNone(result['cpu']['temperature'])
        self.assertEqual(result['gpus'], [])
        json.dumps(result, allow_nan=False)

    def test_network_disappearance_and_reappearance_have_no_counter_spikes(self):
        self.sampler.sample(10)
        self.write('proc/net/dev', 'Inter-|\n face |\n eth0: 300 0 0 0 0 0 0 0 250 0\n')
        network = self.sampler.sample(12)['network']
        self.assertEqual((network['download'], network['upload']), (100, 25))
        self.write('proc/net/dev', 'Inter-|\n face |\n')
        self.assertIsNone(self.sampler.sample(14)['network']['download'])
        self.write('proc/net/dev', 'Inter-|\n face |\n eth0: 999999 0 0 0 0 0 0 0 999999 0\n')
        self.assertIsNone(self.sampler.sample(16)['network']['download'])

    def test_amd_and_nvidia_unsupported_fields_are_not_fake_zeroes(self):
        self.write('sys/class/drm/card0/device/vendor', '0x1002')
        self.write('sys/class/drm/card0/device/gpu_busy_percent', '65')
        self.write('sys/class/drm/card0/device/hwmon/hwmon0/temp1_input', '55000')
        gpu = self.sampler.sample(10)['gpus'][0]
        self.assertEqual((gpu['usage'], gpu['temperature']), (65, 55))
        self.assertIsNone(gpu['memoryTotal'])
        gpu = t.nvidia_rows('NVIDIA Test, 00000000:01:00.0, 42, 56, 1024, 8192, [N/A]')[0]
        self.assertEqual(gpu['memoryUsed'], 1024**3)
        self.assertEqual(gpu['usage'], 42)
        self.assertIsNone(gpu['power'])

    def test_nvidia_failure_backs_off_and_sleeping_gpu_is_not_queried(self):
        self.write('sys/class/drm/card0/device/vendor', '0x10de')
        state = self.write('sys/class/drm/card0/device/power/runtime_status', 'suspended')
        calls = []
        def fail(*args, **kwargs):
            calls.append(args)
            raise subprocess.TimeoutExpired(args[0], 1.2)
        self.sampler.nvidia = 'nvidia-smi'
        self.sampler.runner = fail
        self.assertTrue(self.sampler.sample(10)['gpus'][0]['sleeping'])
        self.assertEqual(calls, [])
        state.write_text('active')
        self.sampler.sample(12); self.sampler.sample(14)
        self.assertEqual(len(calls), 1)
        self.sampler.sample(44)
        self.assertEqual(len(calls), 2)

    def test_intel_shared_drm_fds_count_once_and_counter_regressions_catch_up(self):
        device = self.write('sys/devices/0000:00:02.0/vendor', '0x8086').parent
        card = self.base/'sys/class/drm/card0'
        card.mkdir(parents=True)
        (card/'device').symlink_to(device)
        fds = self.base/'proc/123/fd'; fds.mkdir(parents=True)
        for fd in ('4', '5'):
            (fds/fd).symlink_to('/dev/dri/renderD128')
            self.write('proc/123/fdinfo/'+fd, 'drm-pdev: 0000:00:02.0\ndrm-client-id: 7\ndrm-engine-render: 1000000000 ns\n')
        self.assertIsNone(self.sampler.sample(10)['gpus'][0]['usage'])
        for fd in ('4', '5'):
            self.write('proc/123/fdinfo/'+fd, 'drm-pdev: 0000:00:02.0\ndrm-client-id: 7\ndrm-engine-render: 2000000000 ns\n')
        gpu = self.sampler.sample(12)['gpus'][0]
        self.assertEqual(gpu['usage'], 50)
        self.assertEqual(gpu['usageScope'], 'session')
        for fd in ('4', '5'):
            self.write('proc/123/fdinfo/'+fd, 'drm-pdev: 0000:00:02.0\ndrm-client-id: 7\ndrm-engine-render: 1900000000 ns\n')
        self.assertEqual(self.sampler.sample(14)['gpus'][0]['usage'], 0)


if __name__ == '__main__': unittest.main()
