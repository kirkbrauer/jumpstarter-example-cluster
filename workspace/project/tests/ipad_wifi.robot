*** Settings ***
Documentation     A real iPad, on real Wi-Fi, opens a page that a virtual head unit serves.
...
...               The edge gateway beside the iPad has a test Wi-Fi network with one port on it. The suite
...               answers that port with a web server inside the head unit, a Cuttlefish in a cluster: what
...               the iPad loads over the air comes from the virtual device.
...
...               The iPad has to know the test network already (join it once by hand), and has no internet
...               while it is on it. Name the network it normally uses, and the suite chooses it again at the end:
...
...               `robot --variable "IPAD NAME:My iPad" --variable "USUAL NETWORK:Home" --outputdir results tests/ipad_wifi.robot`
Resource          ../resources/ipad.resource
Suite Setup       Lease The iPad And The Head Unit
Suite Teardown    Run Keywords    Detach Device Port
...               AND    Run Keyword And Ignore Error    Return The iPad To Its Usual Network
...               AND    Release The iPad And The Head Unit


*** Variables ***
${HEAD UNIT PORT}    8000
${HEADING}           Served by the virtual head unit


*** Test Cases ***
The Head Unit Answers The Gateway's Port
    Serve A Page On The Head Unit    ${HEAD UNIT PORT}    ${HEADING}
    Attach Device Port To Gateway    headunit    ${HEAD UNIT PORT}    gateway_driver=wifi    gateway_session=ipad

The iPad Opens The Head Unit's Page Over Wi-Fi
    Join The Test Network On The iPad
    Open In A New Safari Tab On The iPad    ${GATEWAY PAGE}
    iPad Should Show The Page    ${HEADING}
    ${joined}=    Connections Joined
    Should Be True    ${joined} > 0    The page did not come through the relay.
