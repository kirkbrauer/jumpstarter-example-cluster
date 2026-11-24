*** Settings ***
Documentation     A driver makes a phone call with their phone paired to the car.
...
...               The phone makes the call; the head unit, as the phone's hands-free device, has the same call,
...               and either can end it for both.
...
...               Run it as it is: `robot --outputdir results tests/bluetooth_phone_call.robot`.
Resource          ../resources/calls.resource
Suite Setup       Run Keywords    Lease The Phone And The Head Unit
...               AND    Pair The Phone With The Head Unit
...               AND    Head Unit Should Be Ready For Calls
Suite Teardown    Release The Phone And The Head Unit
Test Teardown     Run Keywords    Hang Up On The Head Unit    AND    Phone Should Have No Call


*** Variables ***
${NUMBER}          6505550100
${OTHER NUMBER}    6505550177


*** Test Cases ***
A Call On The Phone Is A Call On The Head Unit
    Call From The Phone    ${NUMBER}
    Phone Should Show A Call With    ${NUMBER}
    Head Unit Should Have A Call With    ${NUMBER}

The Head Unit Hangs Up A Call
    Call From The Phone    ${NUMBER}
    Head Unit Should Have A Call With    ${NUMBER}
    Hang Up On The Head Unit
    Head Unit Should Have No Call
    Phone Should Have No Call

The Head Unit Makes A Call Through The Phone
    Call From The Head Unit    ${OTHER NUMBER}
    Head Unit Should Have A Call With    ${OTHER NUMBER}
    Phone Should Have A Call With    ${OTHER NUMBER}

A Call Ended On The Phone Ends On The Head Unit
    Call From The Phone    ${NUMBER}
    Head Unit Should Have A Call With    ${NUMBER}
    End The Call On The Phone
    Phone Should Have No Call
    Head Unit Should Have No Call
