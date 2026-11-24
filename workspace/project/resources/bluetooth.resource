*** Settings ***
Documentation     Bluetooth between the phone and the head unit, one keyword for each thing a person does or checks.
...
...               The two are virtual devices with a radio each. Their lease joins the radios (its `bluetooth`
...               forward): nothing here carries the traffic. Each radio asks its own device who it
...               is, so each device lists the other under its real name: `Connect The Radios Of The Phone And
...               The Head Unit` only waits until the two are joined and carry each other's names. What a person
...               would press is pressed with Appium (AppiumLibrary); what a device then believes is read with ADB.
Resource          devices.resource
# The Bluetooth radio of each device (the exporter's `bt_radio` driver): one half of the bridge between the two.
Library           jumpstarter_robot.Driver    bt_radio    client=jumpstarter_driver_radio.client.BluetoothRadioClient
...               prefix=Phone Radio    session=phone    AS    phone.radio
Library           jumpstarter_robot.Driver    bt_radio    client=jumpstarter_driver_radio.client.BluetoothRadioClient
...               prefix=Head Unit Radio    session=headunit    AS    headunit.radio


*** Variables ***
# What each device calls itself on the air. `Connect The Radios Of The Phone And The Head Unit` reads them from the devices.
# Nothing here tells a radio these names: its driver reads them from its device, and follows a rename.
${PHONE NAME}                       ${EMPTY}
${HEAD UNIT NAME}                   ${EMPTY}

# ---- What is pressed and read on the screens, by name ------------------------------------------------------------
#
# Appium's first choice of locator is an accessibility id, then a resource id, and the words on the screen last:
# words change with the device's language. Android's stock Settings give these screens no accessibility ids, so a
# dialog's parts are found by resource id (`id=`). A row of a settings list has no id of its own: every row's
# label is `android:id/title`, and which row it is, is what its label says (see `Row Labelled`).

# The phone's Bluetooth settings (com.android.settings)
${PHONE SETTINGS ROW}               id=android:id/title
${PHONE PAIR NEW DEVICE}            Pair new device    # the label of that row, in the phone's language
${PHONE PAIRING DIALOG}             id=com.android.settings:id/pairing_confirmation_hint
${PHONE PAIRING CODE}               id=com.android.settings:id/pairing_subhead
${PHONE PAIR BUTTON}                id=com.android.settings:id/positive_button_container
# The question the phone asks once paired: may the head unit read your messages?
${PHONE ACCESS QUESTION}            id=com.android.settings:id/message
${PHONE ALLOW ACCESS BUTTON}        id=android:id/button1

# The head unit's page in the phone's Bluetooth settings: the gear beside its name opens it
${PHONE DEVICE DETAILS BUTTON}      id=com.android.settings:id/settings_button
${PHONE DISCONNECT BUTTON}          accessibility_id=Disconnect
${PHONE CONNECT BUTTON}             accessibility_id=Connect
${PHONE FORGET BUTTON}              accessibility_id=Forget
${PHONE FORGET DEVICE BUTTON}       id=android:id/button1    # "Forget device", of the question that follows

# The head unit's Bluetooth settings (com.android.car.settings)
${HEAD UNIT PAIR NEW DEVICE}        Pair new device    # the label of that row, in the head unit's language
${HEAD UNIT BLUETOOTH SWITCH}       accessibility_id=Bluetooth toggle switch
# On the phone's row of the paired devices: its Bluetooth button connects and disconnects the phone
${HEAD UNIT PHONE BLUETOOTH BUTTON}    accessibility_id=Bluetooth
${HEAD UNIT PAIRING CODE}           id=com.android.car.settings:id/pairing_subhead
${HEAD UNIT PAIR BUTTON}            id=android:id/button1


*** Keywords ***
# ---- Before pairing --------------------------------------------------------------------------------------------

Forget Paired Devices On The Phone And The Head Unit
    FOR    ${device}    IN    phone    headunit
        Use Device Named    ${device}
        Forget Paired Devices
    END

Connect The Radios Of The Phone And The Head Unit
    [Documentation]    The lease has joined the radios already, and each radio's half of the bridge has asked the
    ...    device beside it who it is. This waits until the two halves are joined and each is in its radio under
    ...    the other device's real name: that name is what the other device lists.
    ${phone}=    Get Bluetooth Identity    phone
    ${head unit}=    Get Bluetooth Identity    headunit
    # Both radios run from the start of the lease. After `Disconnect The Radios Of The Phone And The Head Unit`
    # neither does, and each has to be started before either can find the other: a half waits for the far
    # half, and a far half that is stopped never comes.
    Phone Radio Start
    Head Unit Radio Start
    Phone Radio Wait Until Joined
    Head Unit Radio Wait Until Joined
    Wait Until Keyword Succeeds    60s    2s    Radios Should Carry Each Other's Names    ${phone}    ${head unit}
    Set Suite Variable    ${PHONE NAME}    ${phone}[name]
    Set Suite Variable    ${HEAD UNIT NAME}    ${head unit}[name]

Radios Should Carry Each Other's Names
    [Documentation]    In the phone's radio there is now a device with the head unit's name, and the other way round.
    [Arguments]    ${phone}    ${head unit}
    ${in the phone's radio}=    Phone Radio Status
    ${in the head unit's radio}=    Head Unit Radio Status
    Should Be True    ${in the phone's radio}[on_air]    The phone's radio is not on the air: ${in the phone's radio}
    Should Be True    ${in the head unit's radio}[on_air]    The head unit's radio is not on the air: ${in the head unit's radio}
    ${beside the phone}=    Phone Radio Peer
    ${beside the head unit}=    Head Unit Radio Peer
    Should Be Equal    ${beside the phone.name}    ${head unit}[name]
    Should Be Equal    ${beside the head unit.name}    ${phone}[name]

The Radios Should Have Carried The Pairing
    [Documentation]    Each half of the bridge has a secure link to its own device, and has passed on what that
    ...    device said: the two talked through the lease's forward, and through nothing else.
    ${in the phone's radio}=    Phone Radio Wait Until Paired    timeout=${60}
    ${in the head unit's radio}=    Head Unit Radio Wait Until Paired    timeout=${60}
    FOR    ${radio}    IN    ${in the phone's radio}    ${in the head unit's radio}
        Log    ${radio}
        Should Be True    ${radio}[paired] and ${radio}[encrypted]    A radio has no secure link to its device: ${radio}
        Should Be True    ${radio}[heard] > 0 and ${radio}[sent] > 0    A radio has not carried traffic both ways: ${radio}
    END

The Radios Should Be Idle
    [Documentation]    Nothing is in flight: no half is calling its device, and no pairing is being made.
    Phone Radio Wait Until Idle
    Head Unit Radio Wait Until Idle

Disconnect The Radios Of The Phone And The Head Unit
    [Documentation]    Takes both radios off each other's air, as two devices out of reach: both are hung up on.
    ...    Their bonds stay. `Connect The Radios Of The Phone And The Head Unit` brings them back.
    Phone Radio Stop
    Head Unit Radio Stop

Pair The Phone With The Head Unit
    [Documentation]    The whole of pairing, for suites that are about what paired devices then do. Its steps, one
    ...    at a time and with their checks, are `tests/bluetooth_pairing.robot`.
    Forget Paired Devices On The Phone And The Head Unit
    Connect The Radios Of The Phone And The Head Unit
    Open Bluetooth Settings On The Phone
    Look For New Devices On The Phone
    Open Bluetooth Settings On The Head Unit
    Look For New Devices On The Head Unit
    Choose The Phone On The Head Unit
    Confirm The Pairing On The Head Unit
    Confirm The Pairing On The Phone
    Allow The Head Unit To Read Messages On The Phone
    Head Unit Should Be Connected To The Phone
    Wait Until Keyword Succeeds    90s    1s    The Connection Should Have Settled

The Connection Should Have Settled
    [Documentation]    Two devices that have just paired go on talking for a while: each opens the profiles it
    ...    wants of the other (calls, music, contacts, messages), and the head unit copies the phone book. A
    ...    "Disconnect" pressed in the middle of that is undone by a profile that was still on its way. This
    ...    holds once almost nothing has crossed between the two radios for a few seconds: the bridge counts
    ...    what each device said.
    ${before}=    Phone Radio Status
    Sleep    4s
    ${after}=    Phone Radio Status
    ${crossed}=    Evaluate    (${after}[heard] + ${after}[sent]) - (${before}[heard] + ${before}[sent])
    Should Be True    ${crossed} <= 4    The devices are still talking: ${crossed} packets in four seconds.

# ---- Pairing: started from either device's settings, confirmed on both -------------------------------------------------
#
# As with two devices in the hand, the one that is asked shows the question on its screen only while its "Pair new
# device" page is open; otherwise it posts a "Pairing request" notification. So both are put on that page first.

Open Bluetooth Settings On The Phone
    [Documentation]    A phone with its Bluetooth settings open is visible to devices nearby, and asks about a
    ...    pairing request on the screen instead of in a notification.
    On The Phone
    # (a phone that has just started sits on its lock screen, where nothing can be pressed)
    ADB Shell    input keyevent KEYCODE_WAKEUP
    ADB Shell    wm dismiss-keyguard
    ADB Shell    am force-stop com.android.settings
    ADB Shell    am start -a android.settings.BLUETOOTH_SETTINGS
    Wait Until On Screen    ${PHONE SETTINGS ROW}

Look For New Devices On The Phone
    [Documentation]    Presses the "Pair new device" row: the phone starts looking, lists what it finds, and
    ...    asks about a pairing on its screen.
    On The Phone
    ${pair new device}=    Row Labelled    ${PHONE PAIR NEW DEVICE}
    Press    ${pair new device}

Choose The Head Unit On The Phone
    [Documentation]    Presses the head unit's row in the phone's list of available devices.
    On The Phone
    ${the head unit}=    Row Labelled    ${HEAD UNIT NAME}
    Press    ${the head unit}    timeout=60s

Open Bluetooth Settings On The Head Unit
    On The Head Unit
    ADB Shell    am force-stop com.android.car.settings
    ADB Shell    am start -a android.settings.BLUETOOTH_SETTINGS
    ${pair new device}=    Row Labelled    ${HEAD UNIT PAIR NEW DEVICE}
    Wait Until On Screen    ${pair new device}

Look For New Devices On The Head Unit
    [Documentation]    Presses the "Pair new device" row: the head unit starts looking, and lists what it finds.
    On The Head Unit
    ${pair new device}=    Row Labelled    ${HEAD UNIT PAIR NEW DEVICE}
    Press    ${pair new device}

Choose The Phone On The Head Unit
    [Documentation]    Presses the phone's row in the head unit's list of available devices.
    On The Head Unit
    ${the phone}=    Row Labelled    ${PHONE NAME}
    Press    ${the phone}    timeout=60s

Pairing Codes Should Match On The Head Unit And The Phone
    [Documentation]    Each device now shows a six-digit code and asks whether the other shows the same.
    ${on the head unit}=    Read Pairing Code On The Head Unit
    ${on the phone}=    Read Pairing Code On The Phone
    Should Match Regexp    ${on the head unit}    ^\\d{6}$
    Should Be Equal    ${on the head unit}    ${on the phone}
    ...    The head unit shows ${on the head unit} and the phone shows ${on the phone}.    values=False

Confirm The Pairing On The Head Unit
    [Documentation]    Presses the "Pair" button of the head unit's pairing dialog.
    On The Head Unit
    Press    ${HEAD UNIT PAIR BUTTON}

Confirm The Pairing On The Phone
    [Documentation]    Presses the "Pair" button of the phone's pairing dialog.
    On The Phone
    Press    ${PHONE PAIR BUTTON}

Allow The Head Unit To Read Messages On The Phone
    [Documentation]    Once paired, the head unit asks for the phone's messages, and the phone asks its owner:
    ...    "Allow access to messages?". Presses "Allow".
    On The Phone
    Wait Until On Screen    ${PHONE ACCESS QUESTION}    timeout=60s
    Press    ${PHONE ALLOW ACCESS BUTTON}

Read Pairing Code On The Head Unit
    On The Head Unit
    ${code}=    Read    ${HEAD UNIT PAIRING CODE}
    RETURN    ${code}

Read Pairing Code On The Phone
    On The Phone
    Wait Until On Screen    ${PHONE PAIRING DIALOG}
    ${code}=    Read    ${PHONE PAIRING CODE}
    RETURN    ${code}

# ---- After pairing -------------------------------------------------------------------------------------------------

Phone Should Be Paired With The Head Unit
    On The Phone
    Should Be Paired With    ${HEAD UNIT NAME}

Head Unit Should Be Paired With The Phone
    On The Head Unit
    Should Be Paired With    ${PHONE NAME}

Phone Should Be Connected To The Head Unit
    On The Phone
    Should Be Connected To    ${HEAD UNIT NAME}

Head Unit Should Be Connected To The Phone
    On The Head Unit
    Should Be Connected To    ${PHONE NAME}

Phone Should Not Be Paired With The Head Unit
    On The Phone
    Wait Until Keyword Succeeds    30s    2s    No Device Should Be Paired

Phone Should Not Be Connected To The Head Unit
    On The Phone
    Should Not Be Connected To    ${HEAD UNIT NAME}

Head Unit Should Not Be Connected To The Phone
    On The Head Unit
    Should Not Be Connected To    ${PHONE NAME}

Phone And Head Unit Should Be Connected
    Phone Should Be Connected To The Head Unit
    Head Unit Should Be Connected To The Phone

# ---- Paired devices: disconnecting, connecting again, forgetting ----------------------------------------------------

Open The Head Unit's Page On The Phone
    [Documentation]    Bluetooth settings, then the gear beside the head unit's name: its page has the Disconnect,
    ...    Connect and Forget buttons, and what the head unit may use of the phone.
    Open Bluetooth Settings On The Phone
    Press    ${PHONE DEVICE DETAILS BUTTON}
    Wait Until On Screen    ${PHONE FORGET BUTTON}

Disconnect From The Head Unit On The Phone
    [Documentation]    Presses "Disconnect" on the head unit's page. The two stay paired.
    Open The Head Unit's Page On The Phone
    Press    ${PHONE DISCONNECT BUTTON}

Connect To The Head Unit On The Phone
    [Documentation]    Presses "Connect" on the head unit's page: the phone calls a head unit it already knows.
    Open The Head Unit's Page On The Phone
    Press    ${PHONE CONNECT BUTTON}

Forget The Head Unit On The Phone
    [Documentation]    Presses "Forget" on the head unit's page, and "Forget device" when asked.
    Open The Head Unit's Page On The Phone
    Press    ${PHONE FORGET BUTTON}
    Press    ${PHONE FORGET DEVICE BUTTON}

Disconnect The Phone On The Head Unit
    [Documentation]    Presses the Bluetooth button on the phone's row of the head unit's paired devices.
    Open Bluetooth Settings On The Head Unit
    Press    ${HEAD UNIT PHONE BLUETOOTH BUTTON}

Connect The Phone On The Head Unit
    [Documentation]    The same button again: the head unit calls the phone it knows.
    Open Bluetooth Settings On The Head Unit
    Press    ${HEAD UNIT PHONE BLUETOOTH BUTTON}

Switch Bluetooth Off On The Head Unit
    [Documentation]    Presses the "Use Bluetooth" switch, as a car that is switched off.
    Open Bluetooth Settings On The Head Unit
    Press    ${HEAD UNIT BLUETOOTH SWITCH}
    ADB Shell    cmd bluetooth_manager wait-for-state:STATE_OFF    timeout=60s

Switch Bluetooth On On The Head Unit
    [Documentation]    The switch again, as a car that is started. Nobody presses anything else.
    On The Head Unit
    Press    ${HEAD UNIT BLUETOOTH SWITCH}
    ADB Shell    cmd bluetooth_manager wait-for-state:STATE_ON    timeout=60s

# ---- What the keywords above are made of: ADB --------------------------------------------------------------------------

Get Bluetooth State
    ${state}=    ADB Shell    dumpsys bluetooth_manager
    RETURN    ${state}

Get Bluetooth Identity
    [Documentation]    What a device is on the air: its name, its address and its class, as its own Bluetooth
    ...    stack reports them.
    [Arguments]    ${device}
    Use Device Named    ${device}
    ${state}=    Get Bluetooth State
    ${name}=    Should Match Regexp    ${state}    (?m)^\\s*Name:\\s*(.+)$
    ${class}=    ADB Shell    getprop bluetooth.device.class_of_device
    ${class of device}=    Evaluate    int.from_bytes(bytes(int(part) for part in "${class}".split(",")), "big")
    # (the adapter belongs to the system user, whoever is driving)
    ${address}=    ADB Shell    settings --user 0 get secure bluetooth_address
    ${identity}=    Create Dictionary    session=${device}    name=${name}[1]    address=${address}
    ...    class_of_device=${class of device}
    RETURN    ${identity}

Forget Paired Devices
    [Documentation]    Bluetooth as it is on a device nobody has paired yet, and switched on.
    ADB Shell    am force-stop com.android.settings
    ADB Shell    su 0 cmd bluetooth_manager factoryReset
    ADB Shell    cmd bluetooth_manager enable
    ${on}=    Run Keyword And Return Status
    ...    ADB Shell    cmd bluetooth_manager wait-for-state:STATE_ON    timeout=60s
    IF    not ${on}
        # Seen once on a head unit: after the reset its Bluetooth stayed in TURNING_OFF for minutes, the
        # Bluetooth app saying nothing more (no link was up, and nothing of the bridge was in the way). Android
        # starts the app again when it is killed, and Bluetooth then comes on.
        Log    Bluetooth did not come back on after the reset: restarting the device's Bluetooth app.    WARN
        ADB Shell    su 0 killall com.android.bluetooth
        Sleep    3s
        ADB Shell    cmd bluetooth_manager enable
        ADB Shell    cmd bluetooth_manager wait-for-state:STATE_ON    timeout=60s
    END
    Wait Until Keyword Succeeds    30s    2s    No Device Should Be Paired

No Device Should Be Paired
    ${state}=    Get Bluetooth State
    Should Contain    ${state}    Bonded devices: 0

Should Be Paired With
    [Arguments]    ${name}
    Wait Until Keyword Succeeds    30s    2s    Paired Devices Should Include    ${name}

Paired Devices Should Include
    [Arguments]    ${name}
    ${state}=    Get Bluetooth State
    ${paired}=    Should Match Regexp    ${state}    (?s)Bonded devices:.*?(?:\\n\\s*\\n|\\Z)
    Should Contain    ${paired}    ${name}

Should Be Connected To
    [Documentation]    Paired is remembered; connected is now. A device says so on the line of each device it knows.
    [Arguments]    ${name}
    Wait Until Keyword Succeeds    60s    3s    Connected Devices Should Include    ${name}

Connected Devices Should Include
    [Arguments]    ${name}
    ${state}=    Get Bluetooth State
    Should Match Regexp    ${state}    ACL BR/EDR:Y[^\\n]*${name}

Should Not Be Connected To
    [Arguments]    ${name}
    Wait Until Keyword Succeeds    60s    3s    Connected Devices Should Not Include    ${name}

Connected Devices Should Not Include
    [Arguments]    ${name}
    ${state}=    Get Bluetooth State
    Should Not Match Regexp    ${state}    ACL BR/EDR:Y[^\\n]*${name}

# ---- What the keywords above are made of: Appium -------------------------------------------------------------------------

Row Labelled
    [Documentation]    The locator of the row of a settings list that has this label.
    [Arguments]    ${label}
    RETURN    android=new UiSelector().resourceId("android:id/title").text("${label}")

Press
    [Documentation]    Press the element, once it is on the screen. It looks every few seconds, as a person does.
    [Arguments]    ${locator}    ${timeout}=30s
    Wait Until Keyword Succeeds    ${timeout}    3s    Click Element    ${locator}

Read
    [Documentation]    The text of the element, once it is on the screen.
    [Arguments]    ${locator}    ${timeout}=30s
    ${text}=    Wait Until Keyword Succeeds    ${timeout}    3s    Get Text    ${locator}
    RETURN    ${text}

Wait Until On Screen
    [Arguments]    ${locator}    ${timeout}=30s
    Wait Until Keyword Succeeds    ${timeout}    3s    Page Should Contain Element    ${locator}
