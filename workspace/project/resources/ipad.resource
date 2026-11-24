*** Settings ***
Documentation     A real iPad on a bench, and the virtual head unit it is tested against, leased together from one
...               lease template.
...
...               The iPad's exporter has an edge gateway beside it (`edge-gateway` in this repository): a real
...               Bluetooth controller and a test Wi-Fi network. The lease joins each to the head unit (its
...               `bluetooth` and `web` forwards): nothing here carries the traffic. What a person would press on
...               the iPad is pressed with Appium (XCUITest); the head unit is driven as in the other suites.
...
...               Each role of the lease is a session: `ipad` and `headunit`.
Resource          media.resource
# The radios beside the iPad (its exporter's `bluetooth` and `wifi` drivers): the real controller's half of the
# Bluetooth bridge, and what answers the one port of the test Wi-Fi.
Library           jumpstarter_robot.Driver    bluetooth    client=jumpstarter_driver_radio.client.BluetoothRadioClient
...               prefix=iPad Radio    session=ipad    AS    ipad.radio
Library           jumpstarter_robot.Driver    wifi    client=jumpstarter_driver_radio.client.RadioClient
...               prefix=iPad Wifi    session=ipad    AS    ipad.wifi


*** Variables ***
# The lease template the two devices come from: it names the roles `ipad` and `headunit` and the forwards
# between them. A lease you already hold from it is used as it is, and kept.
${LEASE TEMPLATE}               ipad-and-head-unit
# The forward of the lease that joins the test Wi-Fi's port to the port inside the head unit.
${WEB FORWARD}                  web
# The iPad's own name. The suite reads it from the lease (the iPad's exporter knows it); give it only to say
# otherwise.
${IPAD NAME}                    ${EMPTY}
# The address the gateway's controller has on the air (`--address` of its service): the iPad lists the head
# unit under it.
${GATEWAY BLUETOOTH ADDRESS}    B8:27:EB:4A:53:01
# The test Wi-Fi network of the gateway, and its one port: the lease answers it with the head unit's.
${TEST NETWORK}                 JumpstarterBench
# A network the iPad knows and normally uses: it is chosen again when a suite is done with the test network.
# Empty leaves the iPad where it is.
${USUAL NETWORK}                ${EMPTY}
${GATEWAY PAGE}                 http://10.77.0.1:8080/
# The port inside the head unit that the lease's `web` forward ends at (the `web` port of its exporter).
${HEAD UNIT WEB PORT}           8000

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
    [Documentation]    Lease both in one lease, power the head unit on, and open ADB and Appium on it and Appium
    ...    on the iPad. The lease joins the two itself: once its forwards are up, there is nothing left to set up.
    Wait Until Keyword Succeeds    ${LEASE PATIENCE}    15s    Acquire Lease
    Role Should Be Bound    ipad
    Role Should Be Bound    headunit
    Head Unit Power On
    Wait Until Forward Is Listening    ${BLUETOOTH FORWARD}    timeout=2 min
    Wait Until Forward Is Listening    ${WEB FORWARD}    timeout=2 min
    Open ADB And Appium    headunit
    ${appium}=    Start Appium    ios.appium    alias=ipad    session=ipad
    Open Application    ${appium.url}    alias=ipad    &{appium.capabilities}    appium:bundleId=${IPAD SETTINGS}
    ...    appium:shouldTerminateApp=${False}    appium:newCommandTimeout=${600}

Release The iPad And The Head Unit
    Run Keyword And Ignore Error    Close All Applications
    Run Keyword And Ignore Error    Close All ADB Devices
    Release Lease

On The iPad
    Switch Application    ipad

Open Settings On The iPad
    On The iPad
    Open On The iPad    ${IPAD SETTINGS}
    Run Keyword And Ignore Error    Click Element    ${IPAD BACK BUTTON}

Open On The iPad
    [Arguments]    ${app}
    Execute Script    mobile: launchApp    bundleId=${app}

# ---- Bluetooth: the head unit's radio and the real controller beside the iPad are one air ----------------------------

Connect The Radios Of The iPad And The Head Unit
    [Documentation]    The lease has joined the head unit's simulated radio and the real controller beside the
    ...    iPad already. This waits until the two halves of that bridge are joined and each carries the other
    ...    device's name: the iPad finds a device with the head unit's name, and the head unit finds the iPad.
    ${head unit}=    Get Bluetooth Identity    headunit
    iPad Radio Start
    Head Unit Radio Start
    iPad Radio Wait Until Joined
    Head Unit Radio Wait Until Joined
    Wait Until Keyword Succeeds    60s    2s    Radios Should Carry The Names Of The iPad And The Head Unit    ${head unit}
    ${the ipad}=    Head Unit Radio Peer
    IF    not $IPAD_NAME
        Set Suite Variable    ${IPAD NAME}    ${the ipad.name}
    END
    Set Suite Variable    ${HEAD UNIT NAME}    ${head unit}[name]
    Set Suite Variable    ${PHONE NAME}    ${IPAD NAME}

Radios Should Carry The Names Of The iPad And The Head Unit
    [Documentation]    On real air, beside the iPad, there is now a device with the head unit's name; in the head
    ...    unit's radio there is one with the iPad's.
    [Arguments]    ${head unit}
    ${beside the ipad}=    iPad Radio Status
    ${in the head unit's radio}=    Head Unit Radio Status
    Should Be True    ${beside the ipad}[on_air]    The controller beside the iPad is not on the air: ${beside the ipad}
    Should Be True    ${in the head unit's radio}[on_air]    The head unit's radio is not on the air: ${in the head unit's radio}
    ${carried beside the ipad}=    iPad Radio Peer
    ${carried in the head unit}=    Head Unit Radio Peer
    Should Be Equal    ${carried beside the ipad.name}    ${head unit}[name]
    Should Not Be Empty    ${carried in the head unit.name}

The Radios Should Have Carried The iPad's Pairing
    [Documentation]    Each half of the bridge has a secure link to its own device, and has passed on what that
    ...    device said: the two talked through the lease's forward, and through nothing else.
    ${beside the ipad}=    iPad Radio Wait Until Paired    timeout=${60}
    ${in the head unit's radio}=    Head Unit Radio Wait Until Paired    timeout=${60}
    FOR    ${radio}    IN    ${beside the ipad}    ${in the head unit's radio}
        Log    ${radio}
        Should Be True    ${radio}[paired] and ${radio}[encrypted]    A radio has no secure link to its device: ${radio}
        Should Be True    ${radio}[heard] > 0 and ${radio}[sent] > 0    A radio has not carried traffic both ways: ${radio}
    END

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
    Connect The Radios Of The iPad And The Head Unit
    Open Bluetooth Settings On The iPad
    Open Bluetooth Settings On The Head Unit
    Look For New Devices On The Head Unit
    Choose The iPad On The Head Unit
    Confirm The Pairing On The iPad
    Run Keyword And Ignore Error    Confirm The Pairing On The Head Unit
    Head Unit Should Be Connected To The Phone

# ---- Music from a web page ----------------------------------------------------------------------------------------------

Start A Web Page's Audio On The iPad
    [Documentation]    Opens the address in a new Safari tab; Safari shows its player for an audio file, and Play
    ...    is pressed if Safari has not started it by itself. A head unit pauses music it did not ask for: the
    ...    audio starts, the head unit learns of the player and pauses it, and from then on shows it.
    [Arguments]    ${url}
    Open In A New Safari Tab On The iPad    ${url}
    Wait Until On Screen    ${IPAD PLAYER BUTTON}    timeout=60s
    Sleep    3s
    Run Keyword And Ignore Error    Click Element    ${IPAD PLAY BUTTON}

Play The iPad's Audio From The Head Unit
    [Documentation]    Presses the head unit's play button, unless the iPad's audio is playing already: music the
    ...    head unit asked for is music it plays.
    On The Head Unit
    ${playing}=    Run Keyword And Return Status    Remote Player Should Be    PLAYING
    IF    not ${playing}    Press Play On The Head Unit

iPad Should Be Playing
    [Documentation]    Safari's player shows Pause while it plays.
    On The iPad
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
    Choose The Network On The iPad    ${TEST NETWORK}
    Sleep    8s
    Page Should Not Contain Element    ${IPAD PASSWORD FIELD}
    ...    The iPad asks for the password of ${TEST NETWORK}: join it once by hand, so that the iPad knows it.

Choose The Network On The iPad
    [Documentation]    Presses the network's row in the iPad's Wi-Fi settings. The row of a network the iPad is
    ...    not on is a button whose name starts with the network's and goes on with its security and signal;
    ...    older systems have a cell that contains the name instead.
    [Arguments]    ${network}
    ${row}=    Run Keyword And Return Status    Press
    ...    xpath=//XCUIElementTypeButton[starts-with(@name, "${network},")]    timeout=30s
    IF    not ${row}
        Press    xpath=(//XCUIElementTypeCell[.//*[contains(@name, "${network}")]])[1]    timeout=30s
    END

Return The iPad To Its Usual Network
    [Documentation]    Chooses `${USUAL NETWORK}` again, a network the iPad knows. Nothing happens if none is given.
    IF    $USUAL_NETWORK
        Open Settings On The iPad
        Press    ${IPAD WIFI ROW}
        Choose The Network On The iPad    ${USUAL NETWORK}
        Sleep    8s
    END

Serve A Page On The Head Unit
    [Documentation]    A one-page web server inside the head unit, on the port the lease's `web` forward ends at.
    ...    It answers until the head unit is given back.
    [Arguments]    ${heading}
    Use Device Named    headunit
    ${body}=    Set Variable    <!doctype html><title>Head unit</title><h1>${heading}</h1>
    ${length}=    Get Length    ${body}
    ADB Shell    printf "HTTP/1.1 200 OK\\r\\nContent-Type: text/html\\r\\nContent-Length: ${length}\\r\\nConnection: close\\r\\n\\r\\n%s" "${body}" > /data/local/tmp/page.http
    # (-L: it goes on listening, and says the page to each connection. In a session of its own it outlives the
    # ADB command that started it, which waits a moment so that the server is in that session before it ends.)
    ADB Shell    (toybox setsid toybox nc -p ${HEAD UNIT WEB PORT} -L cat /data/local/tmp/page.http < /dev/null > /dev/null 2>&1 &); sleep 1

The Test Network's Port Should Be Answered By The Head Unit
    [Documentation]    The lease's forward is up, and the gateway beside the iPad has connections waiting for a
    ...    device on the Wi-Fi.
    Forward Should Be Listening    ${WEB FORWARD}
    ${gateway}=    iPad Wifi Wait Until Attached
    Log    ${gateway}

The Page Should Have Come Through The Lease
    [Documentation]    The gateway beside the iPad has joined a connection of a device on the Wi-Fi to the lease's
    ...    forward, and none found the forward missing.
    ${gateway}=    iPad Wifi Status
    Should Be True    ${gateway}[joined] > 0    No connection from the Wi-Fi went through the lease's forward: ${gateway}

iPad Should Show The Page
    [Arguments]    ${heading}
    On The iPad
    Wait Until On Screen    xpath=//*[contains(@name, "${heading}")]    timeout=40s
