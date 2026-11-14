"""Observe pam-u2f touch requests. This process never authenticates a user."""
import ctypes
import json
import os
from pathlib import Path
import select
import struct
import time

IN_OPEN = 0x20
IN_CLOSE = 0x18
NAMES = {f'pam-u2f-{s}.pending': s for s in ('sudo', 'polkit', 'lock')}


def update(counts, name, mask):
    if name not in NAMES:
        return counts
    result = dict(counts)
    if mask & IN_OPEN:
        result[name] = result.get(name, 0) + 1
    if mask & IN_CLOSE:
        result[name] = max(0, result.get(name, 0) - 1)
    return {k: v for k, v in result.items() if v}


def watch(directory=None, output=None):
    directory = Path(directory or os.environ['XDG_RUNTIME_DIR'])
    info = directory.stat()
    if info.st_uid != os.getuid() or info.st_mode & 0o077:
        raise ValueError('Security key notifications require a private runtime directory.')
    # Create before watching, and only when missing: another watcher (the shell
    # and the locker each run one) must not see our opens as touch requests.
    for name in NAMES:
        try:
            marker = os.open(directory / name, os.O_CREAT | os.O_EXCL | os.O_WRONLY | os.O_NOFOLLOW | os.O_CLOEXEC, 0o600)
        except FileExistsError:
            continue
        os.close(marker)
    emit = output or (lambda value: print(json.dumps(value), flush=True))
    libc = ctypes.CDLL(None, use_errno=True)
    libc.inotify_init1.argtypes = [ctypes.c_int]
    libc.inotify_add_watch.argtypes = [ctypes.c_int, ctypes.c_char_p, ctypes.c_uint32]
    fd = libc.inotify_init1(os.O_CLOEXEC | os.O_NONBLOCK)
    if fd < 0:
        raise OSError(ctypes.get_errno(), 'inotify_init1')
    counts = {}
    last = 0
    try:
        if libc.inotify_add_watch(fd, os.fsencode(directory), IN_OPEN | IN_CLOSE) < 0:
            raise OSError(ctypes.get_errno(), 'inotify_add_watch')
        emit({'pending': []})
        while True:
            if not select.select([fd], [], [], 1)[0]:
                # A lost close event must never leave a permanent touch prompt.
                if counts and time.monotonic() - last > 120:
                    counts = {}
                    emit({'pending': []})
                continue
            data = os.read(fd, 65536)
            offset = 0
            before = set(counts)
            while offset + 16 <= len(data):
                _, mask, _, size = struct.unpack_from('iIII', data, offset)
                name = data[offset + 16:offset + 16 + size].split(b'\0', 1)[0].decode(errors='replace')
                offset += 16 + size
                if mask & 0x4000:  # IN_Q_OVERFLOW: discard ambiguous UI state.
                    counts = {}
                else:
                    counts = update(counts, name, mask)
            # Coalesce a batch, so an open immediately followed by its close
            # (a marker probe, not a waiting key) never flashes a prompt.
            if before != set(counts):
                last = time.monotonic()
                emit({'pending': sorted(NAMES[k] for k in counts)})
    finally:
        os.close(fd)
