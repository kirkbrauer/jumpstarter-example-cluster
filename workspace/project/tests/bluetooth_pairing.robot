*** Settings ***
Documentation     A driver pairs their phone with the car over Bluetooth.
...
...               One lease, two devices: an Android phone and an Android Automotive head unit, leased together
...               from the lease template `phone-and-head-unit`. Jumpstarter powers them on, and the lease itself
...               joins their Bluetooth radios (its `bluetooth` forward): no part of this test carries the
...               traffic. Appium taps what a person would tap; ADB checks what each device then believes.
...
...               Run it as it is: `robot --outputdir results tests/bluetooth_pairing.robot`, or from the Testing
...               view. Watch it: open the Screen of both devices of the lease from the Jumpstarter view while
...               it runs.
Resource          ../resources/bluetooth.resource
Suite Setup       Lease The Phone And The Head Unit
Suite Teardown    Release The Phone And The Head Unit


*** Test Cases ***
The Lease Joins The Radios Of The Phone And The Head Unit
    Role Should Be Bound    phone
    Role Should Be Bound    headunit
    Forward Should Be Listening    ${BLUETOOTH FORWARD}
    ${forward}=    Get Forward    ${BLUETOOTH FORWARD}
    Should Be Equal    ${forward.endpoints}    ${{['phone.bluetooth', 'headunit.bluetooth']}}
    Lease Should Have No Lost Roles

The Head Unit Starts The Pairing
    [Documentation]    A person in the car chooses the phone on the head unit. Both devices ask at once, and
    ...    the pairing is made when both have agreed.
    [Setup]    Forget Paired Devices On The Phone And The Head Unit
    Connect The Radios Of The Phone And The Head Unit
    Open Bluetooth Settings On The Phone
    Look For New Devices On The Phone
    Open Bluetooth Settings On The Head Unit
    Look For New Devices On The Head Unit
    Choose The Phone On The Head Unit
    Pairing Codes Should Match On The Head Unit And The Phone
    Confirm The Pairing On The Head Unit
    Confirm The Pairing On The Phone
    Allow The Head Unit To Read Messages On The Phone
    The Phone And The Head Unit Should Be Paired And Connected

The Phone Starts The Pairing
    [Documentation]    The same from the other side, on the same lease: both forget each other, and the person
    ...    chooses the head unit on the phone.
    [Setup]    Forget Paired Devices On The Phone And The Head Unit
    The Radios Should Be Idle
    Open Bluetooth Settings On The Head Unit
    Look For New Devices On The Head Unit
    Open Bluetooth Settings On The Phone
    Look For New Devices On The Phone
    Choose The Head Unit On The Phone
    Pairing Codes Should Match On The Head Unit And The Phone
    Confirm The Pairing On The Phone
    Confirm The Pairing On The Head Unit
    Allow The Head Unit To Read Messages On The Phone
    The Phone And The Head Unit Should Be Paired And Connected


*** Keywords ***
The Phone And The Head Unit Should Be Paired And Connected
    Phone Should Be Paired With The Head Unit
    Head Unit Should Be Paired With The Phone
    Phone Should Be Connected To The Head Unit
    Head Unit Should Be Connected To The Phone
    The Radios Should Have Carried The Pairing
