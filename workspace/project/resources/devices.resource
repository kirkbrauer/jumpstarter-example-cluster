*** Settings ***
Documentation     The two devices of these suites: an Android phone and a car's head unit, leased together through
...               Jumpstarter from one lease template. The lease holds both or neither, and joins their radios.
...
...               Each role of the lease is a session: `phone` and `headunit`. `On The Phone` and
...               `On The Head Unit` choose where the ADB and Appium keywords that follow go.
Library           AppiumLibrary
Library           jumpstarter_robot.Jumpstarter    auto_import=False
Library           jumpstarter_robot.Lease    ${LEASE TEMPLATE}    duration=${LEASE DURATION}    AS    lease.devices
# The power driver of each device, under the device's own name: `Phone Power On`, `Head Unit Power On`.
Library           jumpstarter_robot.Driver    cuttlefish.power    client=jumpstarter_driver_cuttlefish.client.CvdPowerClient
...               prefix=Phone Power    session=phone    AS    phone.power
Library           jumpstarter_robot.Driver    cuttlefish.power    client=jumpstarter_driver_cuttlefish.client.CvdPowerClient
...               prefix=Head Unit Power    session=headunit    AS    headunit.power


*** Variables ***
# The lease template the two devices come from (`jmp get lease-templates`): it names the roles `phone` and
# `headunit` and the forwards between their radios. A lease you already hold from it is used as it is, and kept.
${LEASE TEMPLATE}        phone-and-head-unit
${LEASE DURATION}        30 minutes
# How long to keep asking for a lease that the lab cannot satisfy yet.
${LEASE PATIENCE}        5 minutes
# The forward of the lease that joins the two Bluetooth radios.
${BLUETOOTH FORWARD}     bluetooth


*** Keywords ***
Lease The Phone And The Head Unit
    [Documentation]    Lease both devices in one lease, power them on, and open ADB and Appium on each. The lease
    ...    joins their Bluetooth radios itself: once its forward is up, the two are on one air.
    # (The devices are made anew after each lease. Just after one was given back there may be none to lease
    # for a moment, and the lab then says the lease cannot be satisfied: ask again until it can.)
    Wait Until Keyword Succeeds    ${LEASE PATIENCE}    15s    Acquire Lease
    Role Should Be Bound    phone
    Role Should Be Bound    headunit
    Phone Power On
    Head Unit Power On
    Wait Until Forward Is Listening    ${BLUETOOTH FORWARD}    timeout=2 min
    Open ADB And Appium    phone
    Open ADB And Appium    headunit

Release The Phone And The Head Unit
    Run Keyword And Ignore Error    Close All Applications
    Run Keyword And Ignore Error    Close All ADB Devices
    Release Lease

On The Phone
    Use Device Named    phone

On The Head Unit
    Use Device Named    headunit

Open ADB And Appium
    [Documentation]    Wait until Android has booted, and open ADB and Appium on the device.
    [Arguments]    ${device}
    # (the exporter's own ADB server: nothing to install where the suite runs)
    Open ADB Device    cuttlefish.adb    alias=${device}    timeout=10 min    session=${device}
    ${appium}=    Start Appium    android.appium    alias=${device}    session=${device}
    Open Application    ${appium.url}    alias=${device}    &{appium.capabilities}    appium:newCommandTimeout=${600}
    Dismiss First Boot Notice

Use Device Named
    [Arguments]    ${device}
    Switch ADB Device    ${device}
    Switch Application    ${device}

Get Driver's User
    [Documentation]    The Android user of the person driving the device: 0 on a phone, another on a head unit,
    ...    whose user 0 is the car itself. A device's contacts and messages are that user's.
    ${user}=    ADB Shell    am get-current-user
    RETURN    ${user.strip()}

Dismiss First Boot Notice
    [Documentation]    A head unit that has just been created shows a notice over everything until it is told not to.
    Run Keyword And Ignore Error    Click Element    android=new UiSelector().text("Do not show again")
