*** Settings ***
Documentation     A real iPad, on real Wi-Fi, opens a page that a virtual head unit serves.
...
...               The edge gateway beside the iPad has a test Wi-Fi network with one port on it. The lease
...               (`ipad-and-head-unit`) answers that port with a port inside the head unit, a Cuttlefish in a
...               cluster: what the iPad loads over the air comes from the virtual device, through the lease's
...               `web` forward. Nothing in the suite carries the traffic.
...
...               The iPad has to know the test network already (join it once by hand), and has no internet
...               while it is on it. Name the network it normally uses, and the suite chooses it again at the end:
...
...               `robot --variable "USUAL NETWORK:Home" --outputdir results tests/ipad_wifi.robot`
Resource          ../resources/ipad.resource
Suite Setup       Lease The iPad And The Head Unit
Suite Teardown    Run Keywords    Run Keyword And Ignore Error    Return The iPad To Its Usual Network
...               AND    Release The iPad And The Head Unit


*** Variables ***
${HEADING}           Served by the virtual head unit


*** Test Cases ***
The Head Unit Answers The Gateway's Port
    Serve A Page On The Head Unit    ${HEADING}
    The Test Network's Port Should Be Answered By The Head Unit

The iPad Opens The Head Unit's Page Over Wi-Fi
    Join The Test Network On The iPad
    Open In A New Safari Tab On The iPad    ${GATEWAY PAGE}
    iPad Should Show The Page    ${HEADING}
    The Page Should Have Come Through The Lease
