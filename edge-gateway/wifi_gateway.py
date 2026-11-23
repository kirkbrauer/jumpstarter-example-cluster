# SPDX-License-Identifier: Apache-2.0
"""What the Pi's test Wi-Fi network needs to be usable: addresses for the devices that join it, and one port.

Standard library only. Addresses are given from a small pool on the access point's own interface and nowhere
else. The port belongs to whoever attaches to it from the other side (through the exporter's lease): a device
on the Wi-Fi that connects to it is talking to that far end, for example a service inside a virtual device.

    python3 wifi_gateway.py --interface wlan0 --address 10.77.0.1 --port 8080
"""

import argparse
import ipaddress
import json
import select
import socket
import struct
import threading
import time

DISCOVER, OFFER, REQUEST, ACK, NAK = 1, 2, 3, 5, 6
LEASE_SECONDS = 3600


def say(event: str, **more) -> None:
    print(json.dumps({"event": event, **more}), flush=True)


def options(data: bytes) -> dict[int, bytes]:
    found, at = {}, 0
    while at < len(data) and data[at] != 255:
        if data[at] == 0:
            at += 1
            continue
        found[data[at]] = data[at + 2 : at + 2 + data[at + 1]]
        at += 2 + data[at + 1]
    return found


def serve_addresses(interface: str, server: ipaddress.IPv4Address, first: int = 10, last: int = 50) -> None:
    """A DHCP server for one /24: an address per hardware address, kept for as long as this runs."""
    network = ipaddress.ip_network(f"{server}/24", strict=False)
    given: dict[bytes, ipaddress.IPv4Address] = {}
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_BINDTODEVICE, interface.encode())
    sock.bind(("0.0.0.0", 67))
    say("addresses", interface=interface, pool=f"{network.network_address + first}-{network.network_address + last}")
    while True:
        packet, _ = sock.recvfrom(2048)
        if len(packet) < 240 or packet[0] != 1 or packet[236:240] != b"\x63\x82\x53\x63":
            continue
        xid, hardware = packet[4:8], packet[28:34]
        asked = options(packet[240:])
        kind = asked.get(53, b"\0")[0]
        if kind not in (DISCOVER, REQUEST):
            continue
        if hardware not in given:
            used = set(given.values())
            free = [network.network_address + n for n in range(first, last + 1) if network.network_address + n not in used]
            if not free:
                continue
            given[hardware] = free[0]
        address = given[hardware]
        answer = OFFER if kind == DISCOVER else ACK
        wanted = asked.get(50) or packet[12:16]
        if kind == REQUEST and wanted != b"\0\0\0\0" and wanted != address.packed:
            answer = NAK
        reply = struct.pack("!BBBB4sHH4s4s4s4s", 2, 1, 6, 0, xid, 0, 0x8000, b"\0" * 4,
                            b"\0" * 4 if answer == NAK else address.packed, server.packed, b"\0" * 4)
        reply += hardware + b"\0" * 10 + b"\0" * 192 + b"\x63\x82\x53\x63"
        reply += bytes([53, 1, answer, 54, 4]) + server.packed
        if answer != NAK:
            reply += bytes([51, 4]) + struct.pack("!I", LEASE_SECONDS) + bytes([1, 4]) + network.netmask.packed
            reply += bytes([3, 4]) + server.packed
        reply += b"\xff"
        sock.sendto(reply, ("255.255.255.255", 68))
        say({OFFER: "offered", ACK: "given", NAK: "refused"}[answer], address=str(address), device=hardware.hex(":")[-5:])


NOBODY = (
    b"HTTP/1.1 503 Service Unavailable\r\nContent-Type: text/html; charset=utf-8\r\nConnection: close\r\n\r\n"
    b"<!doctype html><title>Jumpstarter test network</title>"
    b"<h1 id=where>Nothing is attached to this port</h1><p>The Raspberry Pi gateway is here, with no device behind it.</p>"
)


def pump(one: socket.socket, other: socket.socket) -> None:
    try:
        while True:
            data = one.recv(65536)
            if not data:
                break
            other.sendall(data)
    except OSError:
        pass
    finally:
        for sock in (one, other):
            try:
                sock.shutdown(socket.SHUT_RDWR)
            except OSError:
                pass
            sock.close()


def serve_relay(address: str, port: int, attach: tuple[str, int]) -> None:
    """A port on the test network, and what answers it: whoever is attached on the other side.

    A device on the Wi-Fi connects to `address:port`. Whoever stands in for the far end keeps connections open
    to the attach port, each waiting; a device's connection takes one of them, and the two are joined. With
    nobody waiting, the device is told so.
    """
    waiting: list[socket.socket] = []
    lock = threading.Lock()

    def take() -> socket.socket | None:
        with lock:
            while waiting:
                upstream = waiting.pop(0)
                ready, _, _ = select.select([upstream], [], [], 0)
                if ready:  # it has closed (or spoke out of turn) while it waited
                    upstream.close()
                    continue
                return upstream
        return None

    def attached() -> None:
        listener = socket.create_server(attach)
        say("attach-port", address=attach[0], port=attach[1])
        while True:
            upstream, _ = listener.accept()
            upstream.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
            with lock:
                waiting.append(upstream)

    threading.Thread(target=attached, daemon=True).start()
    listener = socket.create_server((address, port))
    say("device-port", address=address, port=port)
    while True:
        device, peer = listener.accept()
        upstream = take()
        if upstream is None:
            say("nobody", device=peer[0])
            try:
                device.sendall(NOBODY)
            finally:
                device.close()
            continue
        say("joined", device=peer[0])
        threading.Thread(target=pump, args=(device, upstream), daemon=True).start()
        threading.Thread(target=pump, args=(upstream, device), daemon=True).start()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--interface", default="wlan0")
    parser.add_argument("--address", default="10.77.0.1")
    parser.add_argument("--port", type=int, default=8080)
    parser.add_argument("--attach", default="127.0.0.1:7410", help="where the far end of the port attaches")
    args = parser.parse_args()
    server = ipaddress.IPv4Address(args.address)
    threading.Thread(target=serve_addresses, args=(args.interface, server), daemon=True).start()
    host, _, port = args.attach.rpartition(":")
    serve_relay(args.address, args.port, (host or "127.0.0.1", int(port)))


if __name__ == "__main__":
    main()
