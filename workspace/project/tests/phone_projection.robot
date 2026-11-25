*** Settings ***
Documentation     A driver's phone shows on the car's screen, without a cable.
...
...               One lease, two devices: an Android phone and an Android Automotive head unit, leased together
...               from the lease template `phone-and-head-unit`. The lease joins their Bluetooth radios and their
...               Wi-Fi radios (its `bluetooth` and `wifi` forwards). The phone and the head unit pair; the head
...               unit tells the phone its Wi-Fi network over Bluetooth; the phone joins it and projects.
...
...               The apps are open source, and not Google's Android Auto: AARE on the phone, Open Headunit on
...               the head unit. `apps/projection/fetch.sh` downloads them.
...
...               Run it as it is: `robot --outputdir results tests/phone_projection.robot`.
Resource          ../resources/projection.resource
Suite Setup       Run Keywords    Lease The Phone And The Head Unit
...               AND    Record Bluetooth On The Phone And The Head Unit
...               AND    Install The Projection Apps
...               AND    Switch Wi-Fi On On The Phone And The Head Unit
...               AND    Start Open Headunit On The Head Unit
...               AND    Pair The Phone With The Head Unit
Suite Teardown    Run Keywords    Stop Recording Bluetooth
...               AND    Release The Phone And The Head Unit


*** Test Cases ***
The Phone Learns That The Head Unit Offers Wireless Projection
    Phone Should Know That The Head Unit Offers Wireless Projection

The Phone Projects To The Head Unit Over Bluetooth And Wi-Fi
    Start AARE On The Phone
    Start Projecting From The Phone To The Head Unit
    Bluetooth Should Have Carried The Phone's Arrival
    Phone Should Have Been Told The Head Unit's Network Over Bluetooth
    Phone Should Be On The Head Unit's Network
    Head Unit Should Be Showing The Phone
    Radios Should Be Carrying The Projection

A Touch On The Head Unit Reaches The Phone
    Touch The Projected Screen On The Head Unit

The Phone Shows Its Owner What The Car Shows
    Preview The Car Screen On The Phone

The Phone's Owner Lets AARE Read Notifications
    Let AARE Read The Phone's Notifications
    AARE Should Be Allowed To Read Notifications

The Phone Stops Projecting When Its Owner Disconnects
    Disconnect The Phone From The Head Unit In AARE
    Head Unit Should Not Be Showing The Phone
    Phone Should Be Paired With The Head Unit

The Phone's Owner Lets Its Sound Reach The Car
    Let The Phone's Sound Reach The Car
    AARE Should Have Nothing Left To Set Up

The Phone Comes Back And Projects Without Being Asked
    Bring The Phone Back Into The Car
    Bluetooth Should Have Carried The Phone's Arrival
    Phone Should Be On The Head Unit's Network
    Head Unit Should Be Showing The Phone

The Phone's Sound Is Heard In The Car
    Phone Should Be Sending Its Sound To The Car
    Play A Sound On The Phone
    Head Unit Should Be Playing The Phone's Sound
    [Teardown]    Stop The Sound On The Phone
