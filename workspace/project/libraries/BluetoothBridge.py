# SPDX-License-Identifier: Apache-2.0
"""Bluetooth between two leased devices that do not share a radio.

Each Cuttlefish device has a virtual radio of its own: the phone cannot see the head unit, however close their
exporters are. This library stands in both radios at once. In the phone's radio it is a device with the head
unit's name; in the head unit's radio it is a device with the phone's name; and what either Android says to it,
it says to the other. The two then pair and talk as if they shared the air.

    phone ))) [ "Head Unit" | bridge | "Phone" ] ((( head unit

It reaches each radio through the lease: the exporter's `bluetooth` driver is the radio's HCI port, and the
bridge joins it as one more controller (bumble is its host). It relays L2CAP, which is everything above the
link: SDP, RFCOMM, the audio and phone book profiles. Pairing itself is per link: each Android pairs with the
bridge, which accepts.

    Library    libraries/BluetoothBridge.py

    Bridge Bluetooth    ${phone}    ${head unit}
    ...
    Stop Bluetooth Bridge

A device is described by a dictionary: `session` (its Jumpstarter session), `name`, `address` and
`class_of_device` (see `resources/bluetooth.resource`, which reads them from the device).
"""

from __future__ import annotations

import asyncio
import threading
from contextlib import ExitStack
from dataclasses import dataclass, field
from typing import Any

from bumble.core import BT_BR_EDR_TRANSPORT
from bumble.device import Connection, Device, DeviceConfiguration
from bumble.hci import HCI_Write_Default_Link_Policy_Settings_Command, HCI_Write_Link_Policy_Settings_Command
from bumble.host import Host
from bumble.keys import MemoryKeyStore
from bumble.pairing import PairingConfig, PairingDelegate
from bumble.transport import open_transport
from jumpstarter_driver_network.adapters import TcpPortforwardAdapter
from robot.api import logger
from robot.api.deco import keyword, library
from robot.libraries.BuiltIn import BuiltIn

DRIVER = "bluetooth"
# Link policy: the two devices may swap who leads the link (profiles need that), and no link may sleep.
ROLE_SWITCH_ONLY = 0x0001


class _Accept(PairingDelegate):
    """The bridge says it has a display and a yes/no key, as a phone and a head unit do, so that each device
    asks its own user to confirm. It then answers yes itself: the people at the two devices are who decide.

    Each device pairs with the bridge: there are two pairings, and each device shows the code of its own.
    """

    def __init__(self) -> None:
        super().__init__(io_capability=PairingDelegate.IoCapability.DISPLAY_OUTPUT_AND_YES_NO_INPUT)

    async def confirm(self, auto: bool = False) -> bool:
        return True

    async def compare_numbers(self, number: int, digits: int) -> bool:
        return True

    async def accept(self) -> bool:
        return True


@dataclass(eq=False)
class _Side:
    """The bridge in one device's radio, under the other device's name."""

    radio: str  # whose radio this is
    persona: str  # whose name it carries here
    target: str  # the address of the device this radio belongs to
    device: Device
    other: _Side | None = None
    link: Connection | None = None
    held: list[tuple[int, bytes]] = field(default_factory=list)
    reaching: asyncio.Future | None = None
    tasks: list[asyncio.Future] = field(default_factory=list)
    relayed: int = 0
    closing: bool = False  # the bridge is being taken away: it hangs up both links itself
    called: bool = False  # the link is one the bridge opened (see `reach`), not one the device opened

    def secure(self) -> bool:
        return self.link is not None and self.link.is_encrypted

    def ready(self) -> bool:
        """Whether what the other device says can be passed on.

        On a link the bridge opened, not before the bridge has paired and encrypted it. On a link the device
        opened, at once: the device looks the bridge up first (SDP, in the clear), and encrypts the link itself
        before it uses anything that needs it. That is a phone reconnecting to a head unit it knows.
        """
        return self.link is not None and (self.link.is_encrypted or not self.called)

    def heard(self, _connection: Connection, cid: int, pdu: bytes) -> None:
        """Something the device of this radio said: the other device hears it."""
        self.relayed += 1
        assert self.other is not None
        self.other.say(cid, bytes(pdu))

    def say(self, cid: int, pdu: bytes) -> None:
        if self.ready():
            self.device.send_l2cap_pdu(self.link.handle, cid, pdu)  # type: ignore[union-attr]
            return
        self.held.append((cid, pdu))
        if self.link is None and self.reaching is None:
            self.reaching = asyncio.ensure_future(self.reach())

    def release(self) -> None:
        if self.ready():
            held, self.held = self.held, []
            for cid, pdu in held:
                self.device.send_l2cap_pdu(self.link.handle, cid, pdu)  # type: ignore[union-attr]

    def joined(self, connection: Connection) -> None:
        self.link = connection
        self.called = self.reaching is not None
        self.tasks.append(asyncio.ensure_future(self.stay_awake(connection)))
        connection.on("connection_encryption_change", self.release)
        connection.on("disconnection", self.left)
        self.release()

    def left(self, _reason: int) -> None:
        self.link, self.held = None, []  # (a call that is still being placed ends by itself)
        other = self.other
        if other is not None and other.secure() and not self.closing:
            # one conversation: when one device hangs up, the other is hung up on. (A link that is still being
            # paired is left alone: a phone hangs up between pairing and its first use, a person takes longer.)
            self.tasks.append(asyncio.ensure_future(other.link.disconnect()))  # type: ignore[union-attr]

    async def stay_awake(self, connection: Connection) -> None:
        """Refuse the low-power modes on this link.

        An idle Android asks for sniff mode; the virtual radio answers that badly, and a minute later calls the
        link dead. A link that never sleeps costs a virtual device nothing.
        """
        try:
            await self.device.host.send_command(
                HCI_Write_Link_Policy_Settings_Command(
                    connection_handle=connection.handle, link_policy_settings=ROLE_SWITCH_ONLY
                )
            )
        except Exception as error:  # noqa: BLE001 - the link works without it, for a while
            logger.warn(f"Bluetooth bridge: could not keep the link to the {self.radio} awake: {error!r}")

    async def reach(self) -> None:
        """Call the device of this radio, and pair with it.

        Only a link the bridge opened is authenticated by the bridge, and only once: a device that called is
        the one that pairs, and the radio's link manager does not survive being asked twice.
        """
        try:
            link = await self.device.connect(self.target, transport=BT_BR_EDR_TRANSPORT, timeout=30)
            await link.authenticate()
            await link.encrypt()
            self.release()
        except Exception as error:
            logger.warn(f"Bluetooth bridge: {self.persona!r} could not reach the {self.radio}: {error!r}")
        finally:
            self.reaching = None


def _side(transport: Any, radio: dict, persona: dict) -> _Side:
    config = DeviceConfiguration()
    config.name = persona["name"]
    config.class_of_device = int(persona["class_of_device"])
    config.classic_enabled, config.le_enabled = True, False
    # without Secure Connections there is no key derived across transports to disagree about
    config.classic_sc_enabled, config.classic_ssp_enabled = False, True
    device = Device(config=config, host=Host(controller_source=transport.source, controller_sink=transport.sink))
    device.keystore = MemoryKeyStore()
    device.pairing_config_factory = lambda _connection: PairingConfig(
        sc=False, mitm=False, bonding=True, delegate=_Accept()
    )
    side = _Side(radio=radio["name"], persona=persona["name"], target=radio["address"], device=device)
    device.l2cap_channel_manager.on_pdu = side.heard  # everything above the link is relayed, none of it answered
    device.on("connection", side.joined)
    return side


@library(scope="SUITE", auto_keywords=False)
class BluetoothBridge:
    """Keywords for a Bluetooth bridge between two leased devices."""

    def __init__(self) -> None:
        self._loop: asyncio.AbstractEventLoop | None = None
        self._thread: threading.Thread | None = None
        self._stop: asyncio.Event | None = None
        self._forwards = ExitStack()
        self._sides: list[_Side] = []

    @keyword
    def bridge_bluetooth(self, first: dict, second: dict) -> None:
        """Join the Bluetooth radios of two leased devices until `Stop Bluetooth Bridge` or the end of the suite.

        Afterwards each device finds the other by its name when it looks for devices to pair with.
        """
        if self._thread is not None:
            raise RuntimeError("The Bluetooth bridge is already running: Stop Bluetooth Bridge first.")
        ports = [self._radio_of(device) for device in (first, second)]
        ready = threading.Event()
        failure: list[BaseException] = []

        def run() -> None:
            self._loop = asyncio.new_event_loop()
            asyncio.set_event_loop(self._loop)
            try:
                self._loop.run_until_complete(self._serve(ports, first, second, ready))
            except BaseException as error:
                failure.append(error)
                ready.set()

        self._thread = threading.Thread(target=run, name="bluetooth-bridge", daemon=True)
        self._thread.start()
        if not ready.wait(60) or failure:
            self.stop_bluetooth_bridge()
            raise RuntimeError(f"The Bluetooth bridge did not start: {failure[0]!r}" if failure else "timed out")
        logger.info(f"Bluetooth bridge: {first['name']!r} and {second['name']!r} now share the air.")

    @keyword
    def stop_bluetooth_bridge(self) -> None:
        """Take the bridge away: the devices are out of each other's reach again. Their bonds stay."""
        if self._loop is not None and self._stop is not None:
            self._loop.call_soon_threadsafe(self._stop.set)
        if self._thread is not None:
            self._thread.join(20)
        self._thread, self._loop, self._stop, self._sides = None, None, None, []
        self._forwards.close()
        self._forwards = ExitStack()

    @keyword
    def bluetooth_bridge_should_have_relayed_traffic(self) -> None:
        """Fail unless both devices have said something that reached the other."""
        counts = {side.radio: side.relayed for side in self._sides}
        logger.info(f"Bluetooth bridge: relayed packets by origin: {counts}")
        if not counts or min(counts.values()) == 0:
            raise AssertionError(f"The Bluetooth bridge has not carried traffic both ways: {counts}")

    def _radio_of(self, device: dict) -> str:
        """The HCI port of a device's radio, on a local port for as long as the bridge runs."""
        driver = BuiltIn().run_keyword("Get Driver", DRIVER, f"session={device['session']}")
        host, port = self._forwards.enter_context(TcpPortforwardAdapter(client=driver))
        return f"tcp-client:{host}:{port}"

    async def _serve(self, ports: list[str], first: dict, second: dict, ready: threading.Event) -> None:
        self._stop = asyncio.Event()
        async with await open_transport(ports[0]) as radio_one, await open_transport(ports[1]) as radio_two:
            # in the first device's radio stands the second device, and the other way round
            one, two = _side(radio_one, first, second), _side(radio_two, second, first)
            one.other, two.other = two, one
            self._sides = [one, two]
            for side in self._sides:
                await side.device.power_on()
                await side.device.host.send_command(
                    HCI_Write_Default_Link_Policy_Settings_Command(default_link_policy_settings=ROLE_SWITCH_ONLY)
                )
                await side.device.set_discoverable(True)
                await side.device.set_connectable(True)
            ready.set()
            await self._stop.wait()
            for side in self._sides:
                side.closing = True
            for side in self._sides:
                if side.link is not None:
                    # (a link the device is already dropping has nothing left to hang up)
                    await asyncio.gather(asyncio.wait_for(side.link.disconnect(), 5), return_exceptions=True)
            # nothing the bridge started is left behind: what has not finished by now is stopped, and waited for
            started = [task for side in self._sides for task in (*side.tasks, side.reaching) if task is not None]
            for task in started:
                task.cancel()
            await asyncio.gather(*started, return_exceptions=True)
            for side in self._sides:
                await side.device.power_off()
