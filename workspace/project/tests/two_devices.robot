*** Settings ***
Documentation     One suite, two devices: a phone and a head unit, each in a session of its own.
...
...               The keywords of the second session carry its name in front where a driver of the first session
...               has the same name. `List Driver Keywords` says what each is called.
Library           jumpstarter_robot.Jumpstarter    selector=type=phone    session=phone
Library           jumpstarter_robot.Session    headunit    selector=type=head-unit    AS    session.headunit
Suite Setup       Lease Both
Suite Teardown    Release Both


*** Keywords ***
Lease Both
    Acquire Lease    session=phone
    Acquire Lease    session=headunit

Release Both
    Release Lease    session=headunit
    Release Lease    session=phone


*** Test Cases ***
Both Devices Answer
    ${phone}=    List Drivers    session=phone
    ${headunit}=    List Drivers    session=headunit
    Should Not Be Empty    ${phone}
    Should Not Be Empty    ${headunit}
