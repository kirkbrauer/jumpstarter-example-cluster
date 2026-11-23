*** Settings ***
Documentation     The two devices of these suites: an Android phone and a car's head unit, each leased through
...               Jumpstarter in a session of its own.
...
...               `On The Phone` and `On The Head Unit` choose where the ADB and Appium keywords that follow go.
Library           AppiumLibrary
Library           jumpstarter_robot.Jumpstarter    selector=${PHONE SELECTOR}    session=phone
Library           jumpstarter_robot.Session    headunit    selector=${HEAD UNIT SELECTOR}    AS    session.headunit
# The power driver of each device, under the device's own name: `Phone Power On`, `Head Unit Power On`.
Library           jumpstarter_robot.Driver    cuttlefish.power    client=jumpstarter_driver_cuttlefish.client.CvdPowerClient
...               prefix=Phone Power    session=phone    AS    phone.power
Library           jumpstarter_robot.Driver    cuttlefish.power    client=jumpstarter_driver_cuttlefish.client.CvdPowerClient
...               prefix=Head Unit Power    session=headunit    AS    headunit.power


*** Variables ***
# Which exporters to lease. A lease you already hold for the same selector is used as it is, and kept.
${PHONE SELECTOR}        device=cf-phone
${HEAD UNIT SELECTOR}    device=cf-headunit
${LEASE DURATION}        30 minutes


*** Keywords ***
Lease The Phone And The Head Unit
    [Documentation]    Lease both devices, power them on, and open ADB and Appium on each.
    Acquire Lease    session=phone    duration=${LEASE DURATION}
    Acquire Lease    session=headunit    duration=${LEASE DURATION}
    Phone Power On
    Head Unit Power On
    Open ADB And Appium    phone
    Open ADB And Appium    headunit

Release The Phone And The Head Unit
    Run Keyword And Ignore Error    Close All Applications
    Run Keyword And Ignore Error    Close All ADB Devices
    Release Lease    session=headunit
    Release Lease    session=phone

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
