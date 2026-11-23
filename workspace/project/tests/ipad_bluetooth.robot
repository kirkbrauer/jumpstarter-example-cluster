*** Settings ***
Documentation     A real iPad and a virtual head unit, over real Bluetooth.
...
...               The iPad is on a bench; the head unit is a Cuttlefish in a cluster. An edge gateway beside the
...               iPad (a real Bluetooth controller on its exporter's host) is joined to the head unit's simulated
...               radio, so the iPad finds, pairs with and plays music through a head unit that is not there.
...
...               The iPad needs the internet for the audio (so not the gateway's test Wi-Fi network), and the
...               suite needs the iPad's own name and Bluetooth address (Settings > General > About):
...
...               `robot --variable "IPAD NAME:My iPad" --variable "IPAD BLUETOOTH ADDRESS:AA:BB:CC:DD:EE:FF" --outputdir results tests/ipad_bluetooth.robot`
Resource          ../resources/ipad.resource
Suite Setup       Run Keywords    Lease The iPad And The Head Unit    AND    Pair The iPad With The Head Unit
Suite Teardown    Run Keywords    Pause The Audio On The iPad    AND    Stop Bluetooth Bridge
...               AND    Release The iPad And The Head Unit


*** Variables ***
# A public audio file; Safari names what it plays after the site.
${AUDIO URL}      https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3
${AUDIO TITLE}    soundhelix.com


*** Test Cases ***
The Head Unit Knows The iPad
    Head Unit Should Be Paired With The Phone
    Head Unit Should Be Connected To The Phone
    Head Unit Should Be Ready For Music

The iPad Plays A Web Page's Audio Through The Head Unit
    Open Bluetooth Audio On The Head Unit
    Play A Web Page's Audio On The iPad    ${AUDIO URL}
    Head Unit Should Be Playing The iPad's Audio
    Head Unit Should Show The Track    ${AUDIO TITLE}
