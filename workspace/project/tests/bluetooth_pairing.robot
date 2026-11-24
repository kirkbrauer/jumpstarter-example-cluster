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

The Phone Pairs With The Head Unit
    [Setup]    Forget Paired Devices On The Phone And The Head Unit
    Connect The Radios Of The Phone And The Head Unit
    Open Bluetooth Settings On The Phone
    Open Bluetooth Settings On The Head Unit
    Look For New Devices On The Head Unit
    Choose The Phone On The Head Unit
    Pairing Codes Should Match On The Head Unit And The Phone
    Confirm The Pairing On The Head Unit
    Confirm The Pairing On The Phone
    Allow The Head Unit To Read Messages On The Phone
    Phone Should Be Paired With The Head Unit
    Head Unit Should Be Paired With The Phone
    Phone Should Be Connected To The Head Unit
    Head Unit Should Be Connected To The Phone
    The Radios Should Have Carried The Pairing
