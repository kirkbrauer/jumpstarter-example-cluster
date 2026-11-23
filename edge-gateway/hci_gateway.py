# SPDX-License-Identifier: Apache-2.0
"""A Bluetooth controller as an HCI port.

It takes a local controller for itself (the kernel's HCI user channel, so that no other Bluetooth stack on this
machine uses it) and serves it on a TCP port as a stream of HCI packets in H4 framing: the port a Bluetooth host
on another machine connects to, to be on the air through this controller. One host at a time.

Standard library only. It needs CAP_NET_ADMIN, to take the controller.

    python3 hci_gateway.py --device 0 --listen 127.0.0.1:7300 --address B8:27:EB:00:00:01

`--address` gives the controller a Bluetooth address before a host gets it. A Raspberry Pi's built-in
controller comes up with a placeholder (aa:aa:aa:aa:aa:aa) until something sets one; the command that does is
Broadcom's own, so the option is for Broadcom controllers.
"""

import argparse
import ctypes
import fcntl
import json
import os
import select
import socket
import struct
import sys

HCIDEVDOWN = 0x400448CA
HCI_CHANNEL_USER = 1
COMMAND, ACL, SCO, EVENT, ISO = 1, 2, 3, 4, 5


def say(event: str, **more) -> None:
    print(json.dumps({"event": event, **more}), flush=True)


def open_controller(device: int) -> socket.socket:
    """The controller on the kernel's user channel: every packet it sends, and nobody else at it."""
    control = socket.socket(socket.AF_BLUETOOTH, socket.SOCK_RAW, socket.BTPROTO_HCI)
    try:
        fcntl.ioctl(control.fileno(), HCIDEVDOWN, device)  # the user channel is only given for a controller that is down
    except OSError as error:
        if error.errno != 114:  # EALREADY: it is down
            raise
    finally:
        control.close()
    controller = socket.socket(socket.AF_BLUETOOTH, socket.SOCK_RAW, socket.BTPROTO_HCI)
    address = struct.pack("<HHH", socket.AF_BLUETOOTH, device, HCI_CHANNEL_USER)  # struct sockaddr_hci
    libc = ctypes.CDLL(None, use_errno=True)
    if libc.bind(controller.fileno(), address, len(address)) != 0:
        code = ctypes.get_errno()
        controller.close()
        raise OSError(code, f"cannot take hci{device}: {os.strerror(code)}")
    return controller


def command(controller: socket.socket, opcode: int, parameters: bytes = b"") -> None:
    """Send one HCI command and wait for the controller's answer to it."""
    controller.send(bytes([COMMAND]) + struct.pack("<HB", opcode, len(parameters)) + parameters)
    controller.settimeout(5)
    try:
        while True:
            event = controller.recv(260)
            # Command Complete (0x0e) or Command Status (0x0f) naming this opcode
            if event[:2] == bytes([EVENT, 0x0E]) and event[4:6] == struct.pack("<H", opcode):
                return
            if event[:2] == bytes([EVENT, 0x0F]) and event[5:7] == struct.pack("<H", opcode):
                return
    finally:
        controller.settimeout(None)


def set_address(controller: socket.socket, address: str) -> None:
    command(controller, 0x0C03)  # Reset
    command(controller, 0xFC01, bytes(reversed(bytes.fromhex(address.replace(":", "")))))  # Broadcom Write_BD_ADDR


def packets(buffer: bytearray):
    """Take the whole H4 packets out of the front of a buffer."""
    while buffer:
        kind = buffer[0]
        if kind == COMMAND or kind == SCO:
            header, size_at, size_format = 4, 3, "<B"
        elif kind == ACL or kind == ISO:
            header, size_at, size_format = 5, 3, "<H"
        elif kind == EVENT:
            header, size_at, size_format = 3, 2, "<B"
        else:
            raise ValueError(f"{kind:#04x} is not an HCI packet type")
        if len(buffer) < header:
            return
        size = struct.unpack_from(size_format, buffer, size_at)[0]
        if kind == ISO:
            size &= 0x3FFF
        if len(buffer) < header + size:
            return
        packet = bytes(buffer[: header + size])
        del buffer[: header + size]
        yield packet


def serve(device: int, listen: tuple[str, int], address: str = "") -> None:
    listener = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    listener.bind(listen)
    listener.listen(1)
    say("listening", port=listener.getsockname()[1], device=f"hci{device}")
    while True:
        host, peer = listener.accept()
        host.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        try:
            controller = open_controller(device)
        except OSError as error:
            say("controller-unavailable", reason=str(error))
            host.close()
            continue
        if address:
            try:
                set_address(controller, address)
            except OSError as error:
                say("address-not-set", reason=str(error))
        say("host", peer=peer[0])
        counts = {"to_controller": 0, "from_controller": 0}
        pending = bytearray()
        try:
            while True:
                ready, _, _ = select.select([host, controller], [], [])
                if controller in ready:
                    host.sendall(controller.recv(4096))  # one packet a read, with its H4 type
                    counts["from_controller"] += 1
                if host in ready:
                    chunk = host.recv(65536)
                    if not chunk:
                        break
                    pending += chunk
                    for packet in packets(pending):
                        controller.send(packet)
                        counts["to_controller"] += 1
        except (OSError, ValueError) as error:
            say("host-error", reason=str(error))
        finally:
            host.close()
            controller.close()  # closing the user channel resets the controller: the next host starts clean
            say("host-gone", **counts)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--device", type=int, default=0, help="the controller's number: 0 is hci0")
    parser.add_argument("--listen", default="127.0.0.1:7300")
    parser.add_argument("--address", default="", help="give a Broadcom controller this Bluetooth address first")
    args = parser.parse_args()
    host, _, port = args.listen.rpartition(":")
    try:
        serve(args.device, (host or "127.0.0.1", int(port)), args.address)
    except KeyboardInterrupt:
        sys.exit(0)


if __name__ == "__main__":
    main()
