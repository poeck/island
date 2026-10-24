import asyncio
import json
import os
from pathlib import Path
import stat
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'lib'))
from askpass import Broker, private_directory


class AskpassTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.env = dict(os.environ, XDG_RUNTIME_DIR=self.temp.name,
                        SUDO_ASKPASS_ACTION='Validate sudo credentials',
                        SUDO_ASKPASS_TARGET='root', SUDO_ASKPASS_DIRECTORY='/fixture')
        with patch.dict(os.environ, self.env):
            self.directory = private_directory(create=True)
        self.events = asyncio.Queue()
        self.broker = Broker(lambda **event: self.events.put_nowait(event), timeout=2)
        self.server = await asyncio.start_unix_server(self.broker.handle, path=str(self.directory / 'socket'))
        self.helpers = []

    async def asyncTearDown(self):
        for process in self.helpers:
            if process.returncode is None:
                process.kill()
            await process.communicate()
        self.server.close()
        await self.server.wait_closed()
        for task in list(self.broker.clients):
            task.cancel()
        await asyncio.gather(*self.broker.clients, return_exceptions=True)
        self.temp.cleanup()

    async def helper(self):
        process = await asyncio.create_subprocess_exec(
            sys.executable, str(ROOT / 'bin/island-askpass'), '[sudo] password for fixture:',
            env=self.env, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE)
        self.helpers.append(process)
        return process

    async def event(self, kind):
        event = await asyncio.wait_for(self.events.get(), 3)
        self.assertEqual(event['event'], kind)
        return event

    async def test_response_goes_only_to_helper_stdout(self):
        helper = await self.helper()
        request = await self.event('request')
        self.assertEqual(request['action'], 'Validate sudo credentials')
        self.assertEqual(request['target'], 'root')
        self.assertEqual(request['directory'], '/fixture')
        self.broker.reply({'id': request['id'] + 1, 'response': 'wrong-request'})
        self.assertIsNone(helper.returncode)
        self.broker.reply({'id': request['id'], 'response': 'synthetic-ä-fixture'})
        stdout, stderr = await helper.communicate()
        self.assertEqual(helper.returncode, 0)
        self.assertEqual(stdout.decode(), 'synthetic-ä-fixture\n')
        self.assertEqual(stderr, b'')
        clear = await self.event('clear')
        self.assertEqual(clear, {'event': 'clear', 'id': request['id']})
        self.assertTrue(self.events.empty())

    async def test_cancel_and_newline_fail_without_password_output(self):
        for value in (None, 'line\nbreak', 'null\0byte', ''):
            helper = await self.helper()
            request = await self.event('request')
            self.broker.reply({'id': request['id'], 'response': value})
            stdout, _ = await helper.communicate()
            self.assertEqual(helper.returncode, 1)
            self.assertEqual(stdout, b'')
            await self.event('clear')

    async def test_disconnected_client_clears_and_next_request_is_serialized(self):
        first = await self.helper()
        request = await self.event('request')
        second = await self.helper()
        await asyncio.sleep(.05)
        self.assertTrue(self.events.empty())
        first.kill()
        await first.communicate()
        self.assertEqual((await self.event('clear'))['id'], request['id'])
        next_request = await self.event('request')
        self.assertNotEqual(next_request['id'], request['id'])
        # A stale reply must never answer a later request.
        self.broker.reply({'id': request['id'], 'response': 'stale'})
        self.broker.reply({'id': next_request['id'], 'response': None})
        self.assertEqual((await second.communicate())[0], b'')
        await self.event('clear')

    async def test_timeout_clears_prompt_and_fails_helper(self):
        self.broker.timeout = .15
        helper = await self.helper()
        request = await self.event('request')
        stdout, _ = await helper.communicate()
        self.assertEqual(helper.returncode, 1)
        self.assertEqual(stdout, b'')
        self.assertEqual((await self.event('clear'))['id'], request['id'])

    async def test_malformed_request_does_not_reach_ui(self):
        reader, writer = await asyncio.open_unix_connection(str(self.directory / 'socket'))
        writer.write(b'{invalid request\n')
        await writer.drain()
        self.assertEqual(await reader.read(), b'')
        writer.close()
        await writer.wait_closed()
        self.assertTrue(self.events.empty())

    async def test_missing_broker_and_insecure_directory_fail_closed(self):
        self.server.close()
        await self.server.wait_closed()
        (self.directory / 'socket').unlink(missing_ok=True)
        helper = await self.helper()
        self.assertEqual((await helper.communicate())[0], b'')
        self.assertEqual(helper.returncode, 1)
        self.directory.chmod(0o755)
        with patch.dict(os.environ, self.env), self.assertRaises(ValueError):
            private_directory()
        self.directory.rmdir()
        self.directory.symlink_to(self.temp.name, target_is_directory=True)
        with patch.dict(os.environ, self.env), self.assertRaises(ValueError):
            private_directory()
        self.directory.unlink()

    async def test_broker_stdio_shutdown_and_exclusive_socket(self):
        # Use a separate directory so the in-process fixture does not own it.
        runtime = Path(self.temp.name) / 'separate'
        runtime.mkdir(mode=0o700)
        env = dict(self.env, XDG_RUNTIME_DIR=str(runtime), ISLAND_MODE='live', ISLAND_CONFIG='{"askpass":true}')
        command = [sys.executable, str(ROOT / 'bin/island'), 'internal', 'askpass-bridge']
        process = await asyncio.create_subprocess_exec(*command, env=env, stdin=asyncio.subprocess.PIPE,
                                                      stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE)
        self.helpers.append(process)
        self.assertEqual(json.loads(await process.stdout.readline()), {'event': 'ready'})
        path = runtime / 'island-askpass/socket'
        self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o600)
        duplicate = await asyncio.create_subprocess_exec(*command, env=env, stdin=asyncio.subprocess.PIPE,
                                                        stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE)
        stdout, _ = await duplicate.communicate()
        self.assertEqual(stdout, b'')
        self.assertTrue(path.exists())
        helper = await asyncio.create_subprocess_exec(sys.executable, str(ROOT / 'bin/island-askpass'),
                                                     env=env, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE)
        self.helpers.append(helper)
        request = json.loads(await process.stdout.readline())
        process.stdin.write((json.dumps({'id': request['id'], 'response': 'stdio-fixture'}) + '\n').encode())
        await process.stdin.drain()
        self.assertEqual((await helper.communicate())[0], b'stdio-fixture\n')
        self.assertEqual(json.loads(await process.stdout.readline())['event'], 'clear')
        process.stdin.close()
        await process.wait()
        self.assertFalse(path.exists())


if __name__ == '__main__':
    unittest.main()
