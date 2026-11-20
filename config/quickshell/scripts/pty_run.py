#!/usr/bin/env python3
import os, sys, pty, select, re, fcntl, termios, struct

FIFO = "/tmp/qs-term-in"
if os.path.exists(FIFO):
    os.remove(FIFO)
os.mkfifo(FIFO)

cmd = sys.argv[1:]
osc_re = re.compile(r'\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)')
csi_re = re.compile(r'\x1b\[[0-9;?]*[a-zA-Z]')

pid, fd = pty.fork()
if pid == 0:
    os.execvp(cmd[0], cmd)

try:
    fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", 24, 74, 0, 0))
except Exception:
    pass

fifo_fd = os.open(FIFO, os.O_RDWR | os.O_NONBLOCK)

try:
    while True:
        r, _, _ = select.select([fd, fifo_fd], [], [], 0.1)
        if fd in r:
            try:
                data = os.read(fd, 4096)
                if not data:
                    break
                text = data.decode("utf-8", errors="replace")
                text = osc_re.sub("", text)
                text = csi_re.sub("", text)
                text = text.replace("\r\n", "\n")
                if text:
                    sys.stdout.write(text)
                    sys.stdout.flush()
            except OSError:
                break
        if fifo_fd in r:
            try:
                inp = os.read(fifo_fd, 4096)
                if inp:
                    os.write(fd, inp)
            except OSError:
                pass
        wpid, status = os.waitpid(pid, os.WNOHANG)
        if wpid == pid:
            break
finally:
    os.close(fifo_fd)
    if os.path.exists(FIFO):
        os.remove(FIFO)
    print("\n--- Завершено ---")
