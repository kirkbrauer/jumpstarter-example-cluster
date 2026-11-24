*** Settings ***
Documentation     A phone and a car that already know each other: disconnecting, connecting again, forgetting.
...
...               Pairing happens once. After that a driver expects the phone to come back by itself when the car
...               starts, to be able to disconnect it and connect it again from either side, and to be able to
...               make the phone forget the car.
...
...               Run it as it is: `robot --outputdir results tests/bluetooth_connection.robot`.
Resource          ../resources/calls.resource
Suite Setup       Run Keywords    Lease The Phone And The Head Unit
...               AND    Pair The Phone With The Head Unit
Suite Teardown    Release The Phone And The Head Unit
Test Setup        Phone And Head Unit Should Be Connected


*** Test Cases ***
The Phone Disconnects And Connects Again
    Disconnect From The Head Unit On The Phone
    Phone Should Not Be Connected To The Head Unit
    Head Unit Should Not Be Connected To The Phone
    Connect To The Head Unit On The Phone
    Phone Should Be Connected To The Head Unit
    Head Unit Should Be Connected To The Phone
    Head Unit Should Be Ready For Calls

The Head Unit Disconnects The Phone And Connects It Again
    Disconnect The Phone On The Head Unit
    Head Unit Should Not Be Connected To The Phone
    Phone Should Not Be Connected To The Head Unit
    Connect The Phone On The Head Unit
    Head Unit Should Be Connected To The Phone
    Phone Should Be Connected To The Head Unit
    Head Unit Should Be Ready For Calls

The Phone Comes Back When The Head Unit's Bluetooth Does
    Switch Bluetooth Off On The Head Unit
    Phone Should Not Be Connected To The Head Unit
    Switch Bluetooth On On The Head Unit
    Head Unit Should Be Connected To The Phone
    Phone Should Be Connected To The Head Unit
    Head Unit Should Be Ready For Calls

The Phone Still Knows The Head Unit After Disconnecting
    Disconnect From The Head Unit On The Phone
    Phone Should Not Be Connected To The Head Unit
    Phone Should Be Paired With The Head Unit
    Head Unit Should Be Paired With The Phone
    [Teardown]    Connect To The Head Unit On The Phone

The Phone Forgets The Head Unit
    Forget The Head Unit On The Phone
    Phone Should Not Be Paired With The Head Unit
    Phone Should Not Be Connected To The Head Unit
    Head Unit Should Not Be Connected To The Phone
