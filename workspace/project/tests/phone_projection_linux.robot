*** Settings ***
Documentation     A driver's phone shows on the screen of a Linux head unit, without a cable.
...
...               The same story as `phone_projection.robot`, with another car: the head unit is Linux in QEMU,
...               running LIVI on BlueZ and hostapd, where that suite has Android Automotive with Open Headunit.
...               The phone is the same Android phone with AARE. One lease holds both, from the lease template
...               `phone-and-linux-head-unit`, and joins their Bluetooth and their Wi-Fi.
...
...               Nothing on the head unit goes through ADB: it is asked and told over SSH, or over its serial
...               console with `--variable "HEAD UNIT SHELL:console"`.
...
...               The head unit's disk is flashed first when the suite is told where its image is
...               (`images/headunit-linux`): `robot --outputdir results --variable "HEAD UNIT IMAGE:https://…"
...               --variable "HEAD UNIT SHELL:console" tests/phone_projection_linux.robot`.
Resource          ../resources/projection.resource
Suite Setup       Run Keywords    Lease The Phone And The Linux Head Unit
...               AND    Record Bluetooth On The Phone And The Head Unit
...               AND    Install The Projection Apps
...               AND    Switch Wi-Fi On On The Phone And The Head Unit
...               AND    Start The Receiver On The Head Unit
...               AND    Pair The Phone With The Linux Head Unit
Suite Teardown    Run Keywords    Stop Recording Bluetooth
...               AND    Release The Phone And The Head Unit


*** Variables ***
${LEASE TEMPLATE}           phone-and-linux-head-unit
${HEAD UNIT KIND}           Linux
# LIVI waits for the phone here, and its network is an access point named after the head unit.
${PROJECTION PORT}          5277
${HEAD UNIT NETWORK}        headunit
${PHONE NETWORK TO JOIN}    android=new UiSelector().text("${HEAD UNIT NETWORK}")
# The head unit's Bluetooth is a host of the phone's controller: only the phone's driver has a stack to record.
@{RECORDING RADIOS}         Phone Radio


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

The Phone Stops Projecting When Its Owner Disconnects
    Disconnect The Phone From The Head Unit In AARE
    Head Unit Should Not Be Showing The Phone
    Phone Should Be Paired With The Head Unit

The Phone's Owner Lets Its Sound Reach The Car
    Let The Phone's Sound Reach The Car

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
