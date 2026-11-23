*** Settings ***
Documentation     A first suite against a leased Android phone.
...
...               Lease a phone in the Jumpstarter view (Exporters, "Acquire Lease"), or let this suite acquire one
...               by its label. Open the phone's Screen from its `hmi` driver in the Leases view to watch the run.
Library           jumpstarter_robot.Jumpstarter    selector=type=phone    duration=30 minutes
Suite Setup       Acquire Lease
Suite Teardown    Release Lease


*** Test Cases ***
The Phone Has Its Drivers
    ${drivers}=    List Drivers
    Log    ${drivers}
    Should Not Be Empty    ${drivers}

The Keywords Of The Phone Are Listed
    ${keywords}=    List Driver Keywords
    Log    ${keywords}
