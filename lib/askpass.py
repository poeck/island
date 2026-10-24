"""Sudo askpass over a private Unix socket and the shell's private stdio.

Only the helper writes a response to stdout (sudo's pipe). The broker never
prints responses, persists credentials, or exposes them through shell IPC.
"""
import asyncio
import contextlib
import ctypes
import fcntl
import json
import os
from pathlib import Path
import socket
import signal
import stat
import struct
import sys

LIMIT = 16384
TIMEOUT = 120


def private_directory(create=False):
    runtime = os.environ.get('XDG_RUNTIME_DIR')
    if not runtime:
        raise ValueError('XDG_RUNTIME_DIR is required for Island askpass.')
    base = Path(runtime)
    paths = [base, base / 'island-askpass']
    for path in paths:
        if create and path != base:
            path.mkdir(mode=0o700, exist_ok=True)
        info = path.lstat()
        if not stat.S_ISDIR(info.st_mode) or info.st_uid != os.getuid() or info.st_mode & 0o077:
            raise ValueError('Island askpass requires a private, user-owned runtime directory.')
    return paths[-1]


def peer_uid(connection):
    return struct.unpack('3i', connection.getsockopt(socket.SOL_SOCKET, socket.SO_PEERCRED, 12))[1]


def emit(**message):
    print(json.dumps(message), flush=True)


class Broker:
    def __init__(self, output=emit, timeout=TIMEOUT):
        self.output = output
        self.timeout = timeout
        self.serial = asyncio.Lock()
        self.sequence = 0
        self.pending = {}
        self.clients = set()

    def reply(self, message):
        future = self.pending.get(message.get('id'))
        response = message.get('response')
        if future and not future.done() and (response is None or isinstance(response, str)):
            future.set_result(response)

    async def handle(self, reader, writer):
        task = asyncio.current_task()
        self.clients.add(task)
        disconnected = None
        request_id = None
        try:
            if len(self.clients) > 8 or peer_uid(writer.get_extra_info('socket')) != os.getuid():
                return
            data = await asyncio.wait_for(reader.readline(), 5)
            request = json.loads(data)
            fields = ('action', 'target', 'directory', 'prompt')
            if not isinstance(request, dict) or any(not isinstance(request.get(k), str) or len(request[k]) > 2048 for k in fields):
                return
            disconnected = asyncio.create_task(reader.read(1))
            # A disconnected queued client must never become a lingering prompt.
            async with asyncio.timeout(self.timeout):
                async with self.serial:
                    if disconnected.done():
                        return
                    self.sequence += 1
                    request_id = self.sequence
                    future = asyncio.get_running_loop().create_future()
                    self.pending[request_id] = future
                    self.output(event='request', id=request_id, **{k: request[k] for k in fields})
                    done, _ = await asyncio.wait([future, disconnected], return_when=asyncio.FIRST_COMPLETED)
                    if future in done and not disconnected.done():
                        writer.write((json.dumps({'response': future.result()}) + '\n').encode())
                        await writer.drain()
                    self.pending.pop(request_id, None)
                    self.output(event='clear', id=request_id)
                    request_id = None
        except (ValueError, OSError, TimeoutError):
            pass  # Do not log request contents or responses, including parse errors.
        finally:
            if request_id is not None:
                self.pending.pop(request_id, None)
                self.output(event='clear', id=request_id)
            if disconnected:
                disconnected.cancel()
                with contextlib.suppress(asyncio.CancelledError, OSError):
                    await disconnected
            writer.close()
            with contextlib.suppress(OSError):
                await writer.wait_closed()
            self.clients.discard(task)

    async def input(self):
        reader = asyncio.StreamReader(limit=LIMIT)
        transport, _ = await asyncio.get_running_loop().connect_read_pipe(
            lambda: asyncio.StreamReaderProtocol(reader), sys.stdin)
        try:
            while line := await reader.readline():
                try:
                    message = json.loads(line)
                    if isinstance(message, dict):
                        self.reply(message)
                except (ValueError, TypeError):
                    pass
        finally:
            transport.close()


async def serve():
    # Quickshell may exit before child-process cleanup finishes. Tie the broker
    # directly to its parent as well as stdin, including abrupt shell crashes.
    parent = os.getppid()
    libc = ctypes.CDLL(None, use_errno=True)
    if libc.prctl(1, signal.SIGTERM, 0, 0, 0) != 0:  # PR_SET_PDEATHSIG (Linux)
        raise OSError(ctypes.get_errno(), 'Cannot bind askpass lifetime to its shell.')
    if os.getppid() != parent:
        return
    directory = private_directory(create=True)
    # Hold a lock before removing a stale socket; never steal a running broker.
    with open(os.open(directory / 'lock', os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600), 'w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        path = directory / 'socket'
        if path.exists() or path.is_symlink():
            if not stat.S_ISSOCK(path.lstat().st_mode):
                raise ValueError('Unexpected file at Island askpass socket path.')
            path.unlink()
        broker = Broker()
        server = await asyncio.start_unix_server(broker.handle, path=str(path), limit=LIMIT)
        path.chmod(0o600)
        try:
            async with server:
                emit(event='ready')
                await broker.input()
        finally:
            for task in list(broker.clients):
                task.cancel()
            await asyncio.gather(*broker.clients, return_exceptions=True)
            path.unlink(missing_ok=True)


def helper(prompt):
    """Called by sudo -A. Return nonzero with empty stdout on every failure."""
    try:
        path = private_directory() / 'socket'
        request = dict(action=os.environ.get('SUDO_ASKPASS_ACTION', 'Sudo request'),
                       target=os.environ.get('SUDO_ASKPASS_TARGET', 'root'),
                       directory=os.environ.get('SUDO_ASKPASS_DIRECTORY', os.getcwd()), prompt=prompt)
        with socket.socket(socket.AF_UNIX) as connection:
            connection.settimeout(TIMEOUT + 5)
            connection.connect(str(path))
            if peer_uid(connection) != os.getuid():
                raise ValueError('Invalid askpass peer.')
            connection.sendall((json.dumps(request) + '\n').encode())
            with connection.makefile('rb') as stream:
                data = stream.readline(LIMIT + 1)
            if len(data) > LIMIT:
                raise ValueError('Invalid askpass response.')
            response = json.loads(data).get('response')
            if not isinstance(response, str) or not response or '\n' in response or '\r' in response or '\0' in response:
                return 1
            sys.stdout.write(response + '\n')
            sys.stdout.flush()
            return 0
    except (OSError, ValueError, AttributeError):
        print('island: Askpass unavailable. Start Island in live mode with askpass enabled.', file=sys.stderr)
        return 1


def main():
    try:
        asyncio.run(serve())
    except (OSError, ValueError):
        print('Island: could not start the private askpass broker.', file=sys.stderr)
        return 1
    return 0
