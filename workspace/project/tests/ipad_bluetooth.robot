*** Settings ***
Documentation     A real iPad and a virtual head unit, over real Bluetooth.
...
...               The iPad is on a bench; the head unit is a Cuttlefish in a cluster. The two are leased together
...               (`ipad-and-head-unit`), and the lease joins a real Bluetooth controller beside the iPad to the
...               head unit's simulated radio, so the iPad finds, pairs with and plays music through a head unit
...               that is not there. Nothing in the suite carries the traffic.
...
...               The iPad needs the internet for the audio (so not the gateway's test Wi-Fi network):
...
...               `robot --outputdir results tests/ipad_bluetooth.robot`
Resource          ../resources/ipad.resource
Suite Setup       Run Keywords    Lease The iPad And The Head Unit    AND    Pair The iPad With The Head Unit
Suite Teardown    Run Keywords    Pause The Audio On The iPad    AND    Release The iPad And The Head Unit


*** Variables ***
# A public audio file; Safari names what it plays after the site.
${AUDIO URL}      https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3
${AUDIO TITLE}    soundhelix.com


*** Test Cases ***
The Head Unit Knows The iPad
    Head Unit Should Be Paired With The Phone
    Head Unit Should Be Connected To The Phone
    The Radios Should Have Carried The iPad's Pairing
    Head Unit Should Be Ready For Music

The iPad Plays A Web Page's Audio Through The Head Unit
    Open Bluetooth Audio On The Head Unit
    Start A Web Page's Audio On The iPad    ${AUDIO URL}
    Head Unit Should Show The Track    ${AUDIO TITLE}
    Play The iPad's Audio From The Head Unit
    Head Unit Should Be Playing The iPad's Audio
    iPad Should Be Playing
