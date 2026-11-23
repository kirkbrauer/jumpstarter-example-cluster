# SPDX-License-Identifier: Apache-2.0
"""A port of an edge gateway, answered by a port inside a leased Android device.

An edge gateway (`edge-gateway` in this repository) has a port that devices on its test
Wi-Fi network connect to, and waits for a far end to answer it. This library is that far end's stand-in: it
keeps connections open to the gateway through its exporter's lease, and joins each one a device uses to a TCP
port inside an Android device, reached over that device's lease (ADB).

    Library    libraries/PortRelay.py

    Serve In Device                  headunit    <a command that listens on port 8000>
    Attach Device Port To Gateway    headunit    8000    gateway_session=ipad
    ...
    Detach Device Port

The test runner carries the bytes. That is what JEP-0015's inter-exporter forwards replace.
"""

import socket
import threading
from contextlib import ExitStack

import adbutils
from jumpstarter_driver_network.adapters import TcpPortforwardAdapter
from jumpstarter_robot.keywords import adb
from robot.api import logger
from robot.libraries.BuiltIn import BuiltIn


def _pump(one, other):
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
                sock.close()
            except OSError:
                pass


class PortRelay:
    """Keywords that join an edge gateway's port to a port inside a leased device."""

    ROBOT_LIBRARY_SCOPE = "SUITE"

    def __init__(self):
        self._stack, self._stop, self.joined = ExitStack(), threading.Event(), 0

    def attach_device_port_to_gateway(self, device_alias, device_port, gateway_driver="wifi", gateway_session=None, waiting=3):
        """Keep `waiting` connections open to the gateway's attach port; each one the gateway uses is joined to
        the device's port, and replaced."""
        arguments = [gateway_driver] + ([f"session={gateway_session}"] if gateway_session else [])
        client = BuiltIn().run_keyword("Get Driver", *arguments)
        host, port = self._stack.enter_context(TcpPortforwardAdapter(client=client))
        device = adb._devices.get_connection(device_alias).device

        def wait_and_join():
            while not self._stop.is_set():
                try:
                    gateway = socket.create_connection((host, port), timeout=10)
                    gateway.settimeout(None)
                    first = gateway.recv(65536)  # nothing comes until a device on the Wi-Fi connects
                    if not first:
                        gateway.close()
                        continue
                    inside = device.create_connection(adbutils.Network.TCP, int(device_port))
                    inside.sendall(first)
                    self.joined += 1
                    threading.Thread(target=_pump, args=(inside, gateway), daemon=True).start()
                    _pump(gateway, inside)
                except Exception as error:  # noqa: BLE001
                    if not self._stop.is_set():
                        logger.warn(f"port relay: {error!r}")
                        self._stop.wait(2)

        for _ in range(int(waiting)):
            threading.Thread(target=wait_and_join, daemon=True).start()
        logger.info(f"port relay: the gateway's port is answered by {device_alias}:{device_port}", also_console=True)

    def serve_in_device(self, device_alias, command):
        """Run a command inside the device for as long as the suite lasts (a server, say): it lives on a shell
        that this keeps open, since what an ADB command leaves behind is stopped when the command returns."""
        device = adb._devices.get_connection(device_alias).device
        stream = device.shell(command, stream=True)
        self._stack.callback(stream.close)

    def connections_joined(self):
        return self.joined

    def detach_device_port(self):
        self._stop.set()
        self._stack.close()
