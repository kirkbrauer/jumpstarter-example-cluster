*** Settings ***
Documentation     A real iPad on a bench, and the virtual head unit it is tested against.
...
...               The iPad's exporter has an edge gateway beside it (`edge-gateway` in this repository): a real Bluetooth controller and a test Wi-Fi network, each offered as a port
...               through the iPad's lease. What a person would press on the iPad is pressed with Appium
...               (XCUITest); the head unit is driven as in the other suites.
...
...               The iPad's own name and Bluetooth address are not known to the suite: give them with
...               `--variable`. See `tests/ipad_bluetooth.robot`.
Resource          media.resource
Library           jumpstarter_robot.Session    ipad    selector=${IPAD SELECTOR}    AS    session.ipad
Library           ../libraries/PortRelay.py


*** Variables ***
${IPAD SELECTOR}                type=tablet
# The iPad as its Settings > General > About names it, and its Bluetooth address from the same page.
${IPAD NAME}                    ${EMPTY}
${IPAD BLUETOOTH ADDRESS}       ${EMPTY}
# The address the gateway's controller has on the air (`--address` of its service): the iPad lists the head
# unit under it.
${GATEWAY BLUETOOTH ADDRESS}    B8:27:EB:4A:53:01
# The test Wi-Fi network of the gateway, and the port on it that the suite answers.
${TEST NETWORK}                 JumpstarterBench
# A network the iPad knows and normally uses: it is chosen again when a suite is done with the test network.
# Empty leaves the iPad where it is.
${USUAL NETWORK}                ${EMPTY}
${GATEWAY PAGE}                 http://10.77.0.1:8080/

# ---- What is pressed and read on the iPad, by name ------------------------------------------------------------------
#
# iPadOS gives most of these an accessibility id. A row of a list is found by what it contains.

# Settings (com.apple.Preferences)
${IPAD SETTINGS}                com.apple.Preferences
${IPAD BLUETOOTH ROW}           accessibility_id=Bluetooth
${IPAD WIFI ROW}                accessibility_id=Wi-Fi
${IPAD BACK BUTTON}             accessibility_id=BackButton
${IPAD PAIR BUTTON}             accessibility_id=Pair    # of "Bluetooth Pairing Request"
${IPAD FORGET BUTTON}           accessibility_id=FORGET_BUTTON
${IPAD FORGET DEVICE BUTTON}    accessibility_id=Forget Device    # of the question that follows
${IPAD PASSWORD FIELD}          xpath=//XCUIElementTypeSecureTextField

# Safari (com.apple.mobilesafari)
${IPAD SAFARI}                  com.apple.mobilesafari
${IPAD NEW TAB BUTTON}          accessibility_id=NewTabButton
${IPAD ADDRESS FIELD}           xpath=(//XCUIElementTypeTextField | //XCUIElementTypeSearchField)[1]
${IPAD PLAY BUTTON}             accessibility_id=Play
${IPAD PAUSE BUTTON}            accessibility_id=Pause
${IPAD PLAYER BUTTON}           xpath=//XCUIElementTypeButton[@name="Play" or @name="Pause"]    # either: the player is there


*** Keywords ***
# ---- The two devices -------------------------------------------------------------------------------------------------

Lease The iPad And The Head Unit
    [Documentation]    Lease both, power the head unit on, and open ADB and Appium on it and Appium on the iPad.
    Should Not Be Empty    ${IPAD NAME}    Give the iPad's name: --variable "IPAD NAME:..."
    Acquire Lease    session=headunit    duration=${LEASE DURATION}
    Acquire Lease    session=ipad    duration=${LEASE DURATION}
    Head Unit Power On
    Open ADB And Appium    headunit
    ${appium}=    Start Appium    ios.appium    alias=ipad    session=ipad
    Open Application    ${appium.url}    alias=ipad    &{appium.capabilities}    appium:bundleId=${IPAD SETTINGS}
    ...    appium:shouldTerminateApp=${False}    appium:newCommandTimeout=${600}

Release The iPad And The Head Unit
    Run Keyword And Ignore Error    Close All Applications
    Run Keyword And Ignore Error    Close All ADB Devices
    Release Lease    session=ipad
    Release Lease    session=headunit

On The iPad
    Switch Application    ipad

Open Settings On The iPad
    On The iPad
    Open On The iPad    ${IPAD SETTINGS}
    Run Keyword And Ignore Error    Click Element    ${IPAD BACK BUTTON}

Open On The iPad
    [Arguments]    ${app}
    Execute Script    mobile: launchApp    bundleId=${app}

# ---- Bluetooth: the head unit's radio is the gateway's real one ---------------------------------------------------------

Connect The Head Unit's Radio To The Gateway
    [Documentation]    The head unit's simulated radio and the real controller beside the iPad become one air: the
    ...    iPad finds a device with the head unit's name, and the head unit finds the iPad.
    Should Not Be Empty    ${IPAD BLUETOOTH ADDRESS}    Give the iPad's Bluetooth address: --variable "IPAD BLUETOOTH ADDRESS:..."
    ${head unit}=    Get Bluetooth Identity    headunit
    # (its class is a phone's: 0x5A020C)
    ${ipad}=    Create Dictionary    session=ipad    name=${IPAD NAME}    address=${IPAD BLUETOOTH ADDRESS}
    ...    class_of_device=${5898764}
    Bridge Bluetooth    ${head unit}    ${ipad}
    Set Suite Variable    ${HEAD UNIT NAME}    ${head unit}[name]
    Set Suite Variable    ${PHONE NAME}    ${IPAD NAME}

Open Bluetooth Settings On The iPad
    [Documentation]    An iPad with its Bluetooth settings open can be found, and asks about a pairing request.
    Open Settings On The iPad
    Press    ${IPAD BLUETOOTH ROW}

Make The iPad Forget The Head Unit
    [Documentation]    The "More Info" button on the head unit's row of the iPad's devices, then "Forget This
    ...    Device", then "Forget Device". Nothing happens if the iPad does not know the head unit.
    Open Bluetooth Settings On The iPad
    Sleep    4s
    ${known}=    Run Keyword And Return Status    Click Element
    ...    xpath=//XCUIElementTypeCell[.//*[@name="${GATEWAY BLUETOOTH ADDRESS}"]]//XCUIElementTypeButton[@name="More Info"]
    IF    ${known}
        Press    ${IPAD FORGET BUTTON}    timeout=15s
        Press    ${IPAD FORGET DEVICE BUTTON}    timeout=15s
    END

Choose The iPad On The Head Unit
    [Documentation]    Presses the iPad's row in the head unit's list of available devices.
    On The Head Unit
    ${the ipad}=    Row Labelled    ${IPAD NAME}
    Press    ${the ipad}    timeout=90s

Confirm The Pairing On The iPad
    [Documentation]    Presses "Pair" on the iPad's "Bluetooth Pairing Request".
    On The iPad
    Press    ${IPAD PAIR BUTTON}    timeout=40s

Pair The iPad With The Head Unit
    [Documentation]    The whole of pairing, started from the head unit's settings and confirmed on both.
    Use Device Named    headunit
    Forget Paired Devices
    Make The iPad Forget The Head Unit
    Connect The Head Unit's Radio To The Gateway
    Open Bluetooth Settings On The iPad
    Open Bluetooth Settings On The Head Unit
    Look For New Devices On The Head Unit
    Choose The iPad On The Head Unit
    Confirm The Pairing On The iPad
    Run Keyword And Ignore Error    Confirm The Pairing On The Head Unit
    Head Unit Should Be Connected To The Phone

# ---- Music from a web page ----------------------------------------------------------------------------------------------

Play A Web Page's Audio On The iPad
    [Documentation]    Opens the address in a new Safari tab; Safari shows its player for an audio file, and plays.
    [Arguments]    ${url}
    Open In A New Safari Tab On The iPad    ${url}
    Wait Until On Screen    ${IPAD PLAYER BUTTON}    timeout=60s
    # (Safari starts some audio by itself, a moment after the player appears: Play may be gone when it is pressed)
    Run Keyword And Ignore Error    Click Element    ${IPAD PLAY BUTTON}
    Wait Until On Screen    ${IPAD PAUSE BUTTON}    timeout=40s

Pause The Audio On The iPad
    On The iPad
    Run Keyword And Ignore Error    Click Element    ${IPAD PAUSE BUTTON}

Open In A New Safari Tab On The iPad
    [Arguments]    ${url}
    On The iPad
    Open On The iPad    ${IPAD SAFARI}
    Press    ${IPAD NEW TAB BUTTON}
    Wait Until On Screen    ${IPAD ADDRESS FIELD}
    Input Text    ${IPAD ADDRESS FIELD}    ${url}\n

Head Unit Should Be Playing The iPad's Audio
    [Documentation]    The head unit's remote control of the iPad's player says it is playing, and the head
    ...    unit's Bluetooth audio has the car's speakers.
    On The Head Unit
    Wait Until Keyword Succeeds    40s    3s    Remote Player Should Be    PLAYING
    Wait Until Keyword Succeeds    20s    3s    Bluetooth Audio Should Have The Speakers

Remote Player Should Be
    [Arguments]    ${state}
    ${bluetooth}=    Get Bluetooth State
    Should Match Regexp    ${bluetooth}    playState=PlaybackState \\{state=STATE_${state}\\b

Bluetooth Audio Should Have The Speakers
    ${audio}=    ADB Shell    dumpsys audio    expected_rc=None
    Should Match Regexp    ${audio}    (?s)focus owners:.{0,400}a2dpsink

# ---- Wi-Fi: the gateway's test network ------------------------------------------------------------------------------------

Join The Test Network On The iPad
    [Documentation]    Chooses the gateway's network in the iPad's Wi-Fi settings. It has to be one the iPad
    ...    already knows: a suite does not type its password.
    Open Settings On The iPad
    Press    ${IPAD WIFI ROW}
    Press    xpath=(//XCUIElementTypeCell[.//*[contains(@name, "${TEST NETWORK}")]])[1]    timeout=60s
    Sleep    8s
    Page Should Not Contain Element    ${IPAD PASSWORD FIELD}
    ...    The iPad asks for the password of ${TEST NETWORK}: join it once by hand, so that the iPad knows it.

Return The iPad To Its Usual Network
    [Documentation]    Chooses `${USUAL NETWORK}` again, a network the iPad knows. Nothing happens if none is given.
    IF    $USUAL_NETWORK
        Open Settings On The iPad
        Press    ${IPAD WIFI ROW}
        Press    xpath=(//XCUIElementTypeCell[.//*[contains(@name, "${USUAL NETWORK}")]])[1]    timeout=60s
        Sleep    8s
    END

Serve A Page On The Head Unit
    [Documentation]    A one-page web server inside the head unit, for as long as the suite lasts.
    [Arguments]    ${port}    ${heading}
    Use Device Named    headunit
    ${body}=    Set Variable    <!doctype html><title>Head unit</title><h1>${heading}</h1>
    ${length}=    Get Length    ${body}
    ADB Shell    printf "HTTP/1.1 200 OK\\r\\nContent-Type: text/html\\r\\nContent-Length: ${length}\\r\\nConnection: close\\r\\n\\r\\n%s" "${body}" > /data/local/tmp/page.http
    Serve In Device    headunit    while true; do toybox nc -l -p ${port} < /data/local/tmp/page.http > /dev/null; done

iPad Should Show The Page
    [Arguments]    ${heading}
    On The iPad
    Wait Until On Screen    xpath=//*[contains(@name, "${heading}")]    timeout=40s
