*** Settings ***
Documentation     A driver plays music from their phone through the car.
...
...               The phone has the music; the head unit, with Bluetooth Audio as its source, shows what is
...               playing and has the buttons. Pressing them on the head unit plays, pauses and skips on the phone.
...
...               Run it as it is: `robot --outputdir results tests/bluetooth_media.robot`.
Resource          ../resources/media.resource
Suite Setup       Run Keywords    Lease The Phone And The Head Unit
...               AND    Pair The Phone With The Head Unit For Music
...               AND    Install The Test Player On The Phone
...               AND    Open Bluetooth Audio On The Head Unit
...               AND    Open The Test Player On The Phone
...               AND    Offer The Phone's Music To The Head Unit
Suite Teardown    Release The Phone And The Head Unit
Test Setup        Start From The First Track, Paused


*** Test Cases ***
The Head Unit Shows What The Phone Has Ready
    Phone Should Show The Track    ${FIRST TRACK}
    Head Unit Should Show The Track    ${FIRST TRACK}
    Head Unit Should Show The Artist    Jumpstarter

The Head Unit Plays And Pauses The Phone's Music
    Press Play On The Head Unit
    Phone Should Be Playing
    Press Pause On The Head Unit
    Phone Should Be Paused

The Head Unit Skips To The Next Track
    Press Next Track On The Head Unit
    Phone Should Show The Track    ${SECOND TRACK}
    Head Unit Should Show The Track    ${SECOND TRACK}
    Press Previous Track On The Head Unit
    Phone Should Show The Track    ${FIRST TRACK}
    Head Unit Should Show The Track    ${FIRST TRACK}

A Track Changed On The Phone Changes On The Head Unit
    Press Next Track On The Phone
    Head Unit Should Show The Track    ${SECOND TRACK}
