*** Settings ***
Documentation     Phone projection without wires: what is on the phone is shown on the car's screen, and touched there.
...
...               The phone runs AARE, an open-source phone side of the Android Auto protocol; the head unit runs
...               Open Headunit, an open-source receiver. Neither is Google's Android Auto. They find each other as a
...               phone and a car do: over Bluetooth the head unit tells the phone the name and key of its Wi-Fi
...               network, the phone joins that network, and the picture and the touches go over it. The lease
...               carries both: its `bluetooth` forward and its `wifi` forward. Nothing here carries traffic.
...
...               The two apps are fetched by `apps/projection/fetch.sh`, from each project's release page.
...
...               The head unit is one of two kinds (`${HEAD UNIT KIND}`): an Android Automotive device with Open
...               Headunit, which is what this file is written for, or a Linux device with LIVI
...               (`linux_headunit.resource`). What differs between them is asked of `<kind> Head Unit: …`.
Resource          bluetooth.resource
Resource          linux_headunit.resource
Library           OperatingSystem
Library           Process


*** Variables ***
${PROJECTION APPS}                  ${CURDIR}/../apps/projection
${AARE APK}                         ${PROJECTION APPS}/aare.apk
${AARE PACKAGE}                     net.prototux.aare
${OPEN HEADUNIT APK}                ${PROJECTION APPS}/open-headunit.apk
${OPEN HEADUNIT PACKAGE}            com.andrerinas.headunitrevived
# The service a head unit offers over Bluetooth to a phone that can project to it without wires.
${WIRELESS PROJECTION SERVICE}      4de17a00-52cb-11e6-bdf4-0800200c9a66
# Where the head unit waits for the phone once it is on the head unit's Wi-Fi network.
${PROJECTION PORT}                  5288
# The kind of head unit: `Android` (Open Headunit, over ADB) or `Linux` (LIVI, over SSH or a console).
${HEAD UNIT KIND}                   Android
# The name of the Wi-Fi network the head unit keeps for the phone, as a pattern: Android's is a Wi-Fi Direct group.
${HEAD UNIT NETWORK}                DIRECT-[^"]+
# The devices whose Bluetooth driver records what its stack and controller say to each other.
@{RECORDING RADIOS}                 Phone Radio    Head Unit Radio

# What AARE may do on the phone, and Open Headunit on the head unit: what a person would allow when asked.
@{AARE PERMISSIONS}                 RECORD_AUDIO    ACCESS_FINE_LOCATION    ACCESS_COARSE_LOCATION
...                                 BLUETOOTH_CONNECT    BLUETOOTH_SCAN    NEARBY_WIFI_DEVICES    POST_NOTIFICATIONS
...                                 ACCESS_LOCAL_NETWORK    READ_PHONE_STATE
@{OPEN HEADUNIT PERMISSIONS}        NEARBY_WIFI_DEVICES    ACCESS_FINE_LOCATION    ACCESS_COARSE_LOCATION
...                                 BLUETOOTH_CONNECT    BLUETOOTH_SCAN    BLUETOOTH_ADVERTISE    RECORD_AUDIO
...                                 POST_NOTIFICATIONS    ACCESS_LOCAL_NETWORK

# Android asks the phone's owner before an app joins a Wi-Fi network: the network's row, and "Connect".
${PHONE NETWORK TO JOIN}            android=new UiSelector().textStartsWith("DIRECT-")
${PHONE JOIN NETWORK BUTTON}        id=android:id/button1
# AARE asks once whether the head unit it met is one to trust.
${AARE TRUST HEAD UNIT}             android=new UiSelector().textStartsWith("Trust this head unit")
# Where the projected car screen has its "all apps" button, on the head unit's 1080x600 screen.
${PROJECTED APPS BUTTON}            60 428

# AARE's own screen (net.prototux.aare). It is drawn without ids, so its parts are found by what they say.
${AARE SETUP LEFT TO DO}            android=new UiSelector().text("Finish setting up")
${AARE NOTIFICATION ACCESS}         android=new UiSelector().text("Notification access")
${AARE CAR AUDIO}                   android=new UiSelector().text("Car audio")
# (Android's own Back button, under every screen, is called the same: AARE's is the one inside AARE)
${AARE BACK}                        android=new UiSelector().description("Back").packageName("net.prototux.aare")
${AARE SCREEN CAPTURE METHOD}       android=new UiSelector().text("Screen-capture permission")
${AARE USING SCREEN CAPTURE}        android=new UiSelector().text("Using: Screen-capture permission")
${AARE PREVIEW CAR SCREEN}          android=new UiSelector().text("Preview car screen")
${AARE DISCONNECT}                  android=new UiSelector().text("Disconnect")
${AARE NOT CONNECTED}               android=new UiSelector().text("Not connected")
# The car screen as AARE draws it, on the phone or in the car: its "all apps" button.
${AARE CAR SCREEN APPS}             accessibility_id=Apps
# Android's settings for which apps may read notifications: the app's switch, and the question that follows.
${PHONE NOTIFICATION ACCESS SWITCH}    id=com.android.settings:id/switchWidget
${PHONE ALLOW NOTIFICATION ACCESS}     id=com.android.settings:id/allow_button
# Android asks before an app may record the screen and what the phone plays: "Share your screen with AARE?"
${PHONE SHARE SCREEN QUESTION}      id=com.android.systemui:id/screen_share_dialog_title
${PHONE SHARE SCREEN BUTTON}        id=android:id/button1
# A sound every Android phone has, long enough to be heard in the car: one of its own ringtones.
${SOUND ON THE PHONE}               Sceptrum


*** Keywords ***
# ---- Before projecting -------------------------------------------------------------------------------------------

Fetch The Projection Apps
    [Documentation]    Downloads AARE and Open Headunit from their projects' release pages, unless they are here.
    ${fetched}=    Run Process    ${PROJECTION APPS}/fetch.sh
    Should Be Equal As Integers    ${fetched.rc}    0    ${fetched.stdout}\n${fetched.stderr}

Install The Projection Apps
    [Documentation]    AARE on the phone, Open Headunit on the head unit, each allowed what it asks a person for.
    Fetch The Projection Apps
    On The Phone
    ADB Install    ${AARE APK}
    Allow    ${AARE PACKAGE}    @{AARE PERMISSIONS}
    Run Keyword    ${HEAD UNIT KIND} Head Unit: Install The Receiver

Android Head Unit: Install The Receiver
    On The Head Unit
    ADB Install    ${OPEN HEADUNIT APK}
    Allow    ${OPEN HEADUNIT PACKAGE}    @{OPEN HEADUNIT PERMISSIONS}

Allow
    [Documentation]    Grants an app its permissions for the person using the device.
    [Arguments]    ${package}    @{permissions}
    ${user}=    Get Driver's User
    FOR    ${permission}    IN    @{permissions}
        ADB Shell    pm grant --user ${user} ${package} android.permission.${permission}    expected_rc=None
    END

Switch Wi-Fi On On The Phone And The Head Unit
    [Documentation]    Both devices start with Wi-Fi off. (On a head unit only the system may switch it.)
    On The Phone
    ADB Shell    cmd wifi set-wifi-enabled enabled
    Run Keyword    ${HEAD UNIT KIND} Head Unit: Switch Wi-Fi On

Android Head Unit: Switch Wi-Fi On
    On The Head Unit
    ADB Shell    su 0 cmd wifi set-wifi-enabled enabled

Start Open Headunit On The Head Unit
    [Documentation]    Opens the receiver. From then on the head unit offers wireless projection over Bluetooth
    ...    and keeps a Wi-Fi network of its own for the phone to join.
    Run Keyword    ${HEAD UNIT KIND} Head Unit: Start The Receiver
    Wait Until Keyword Succeeds    90s    3s    Head Unit Should Offer Wireless Projection

Start The Receiver On The Head Unit
    [Documentation]    The same, whatever the receiver is called.
    Start Open Headunit On The Head Unit

Android Head Unit: Start The Receiver
    On The Head Unit
    ADB Shell    logcat -c
    ADB Shell    monkey --pct-syskeys 0 -p ${OPEN HEADUNIT PACKAGE} -c android.intent.category.LAUNCHER 1

Head Unit Should Offer Wireless Projection
    Run Keyword    ${HEAD UNIT KIND} Head Unit: Should Offer Wireless Projection

Android Head Unit: Should Offer Wireless Projection
    On The Head Unit
    ${log}=    ADB Shell    logcat -d -s OPENHU:I
    Should Contain    ${log}    ACTIVELY LISTENING on Android Auto UUID
    Should Contain    ${log}    Received WiFi credentials from manager

Start AARE On The Phone
    On The Phone
    ADB Shell    logcat -c
    ADB Shell    input keyevent KEYCODE_WAKEUP
    ADB Shell    wm dismiss-keyguard
    ADB Shell    am start -n ${AARE PACKAGE}/.ui.MainActivity

Phone Should Know That The Head Unit Offers Wireless Projection
    [Documentation]    A phone learns what a car offers when the two pair: the car's services are in what the
    ...    phone remembers of it.
    On The Phone
    Wait Until Keyword Succeeds    60s    3s    Paired Head Unit Should Offer    ${WIRELESS PROJECTION SERVICE}

Paired Head Unit Should Offer
    [Arguments]    ${service}
    # Whom the phone has bonded with is the same question on any device: its Bluetooth driver answers it.
    ${bluetooth}=    Phone Radio Get Bluetooth State
    ${bonded}=    Evaluate    [bond["name"] for bond in $bluetooth["bonds"]]
    Should Contain    ${bonded}    ${HEAD UNIT NAME}
    # Which services the bonded device offers is Android's own to say.
    ${state}=    Get Bluetooth State
    Should Contain    ${state}    ${service}

Record Bluetooth On The Phone And The Head Unit
    [Documentation]    Each device's Bluetooth driver records what its Bluetooth stack and its controller say to
    ...    each other (HCI), with Android's own snoop log. Starting it restarts the device's Bluetooth once, so
    ...    it is done before the two pair.
    FOR    ${radio}    IN    @{RECORDING RADIOS}
        ${recording}=    Run Keyword    ${radio} Start Capture
        Should Be Equal    ${recording}[mode]    full
    END

Stop Recording Bluetooth
    FOR    ${radio}    IN    @{RECORDING RADIOS}
        Run Keyword And Ignore Error    ${radio} Stop Capture
    END

# ---- Projecting --------------------------------------------------------------------------------------------------

Bring The Phone Into The Car
    [Documentation]    A paired phone that comes into reach of the car connects to it over Bluetooth, and
    ...    projection starts from that. Here the phone's Bluetooth is switched off and on: the same to the car.
    # (what the head unit's Bluetooth records from here on is this arrival)
    IF    "Head Unit Radio" in $RECORDING_RADIOS    Head Unit Radio Start Capture
    On The Phone
    ADB Shell    logcat -c
    ADB Shell    cmd bluetooth_manager disable
    ADB Shell    cmd bluetooth_manager wait-for-state:STATE_OFF    timeout=60s
    ADB Shell    cmd bluetooth_manager enable
    ADB Shell    cmd bluetooth_manager wait-for-state:STATE_ON    timeout=60s

Start Projecting From The Phone To The Head Unit
    [Documentation]    The whole of it, for a phone and a head unit that are paired: the phone comes into the
    ...    car, its owner lets it join the car's network, and trusts the car the first time.
    ...
    ...    When the phone asks is its own business: AARE reaches the head unit on its first try or on its third
    ...    (10 and 20 seconds apart), and only then does Android ask about the network. So nothing is pressed at
    ...    a set time: the phone is watched until it projects, and what it asks on the way is answered.
    Bring The Phone Into The Car
    ${projecting}=    Run Keyword And Return Status
    ...    Wait Until Keyword Succeeds    100s    3s    Phone Should Be Projecting, Its Owner Having Answered
    IF    not ${projecting}
        # AARE has given up for now, or waits behind something else with its question: opened again, it asks.
        Start AARE On The Phone
        Bring The Phone Into The Car
        Wait Until Keyword Succeeds    120s    3s    Phone Should Be Projecting, Its Owner Having Answered
    END

Phone Should Be Projecting, Its Owner Having Answered
    [Documentation]    Answers what the phone is asking now, if it is asking, and holds once it projects.
    On The Phone
    Let The Phone Join The Head Unit's Network If It Asks
    Trust The Head Unit On The Phone If It Asks
    Phone Should Be Projecting

Let The Phone Join The Head Unit's Network If It Asks
    [Documentation]    Android asks the phone's owner before AARE joins the Wi-Fi network the head unit named:
    ...    chooses the network and presses "Connect". Asked once; later Android remembers the answer.
    ${asked}=    Run Keyword And Return Status    Page Should Contain Element    ${PHONE NETWORK TO JOIN}
    IF    ${asked}
        Click Element    ${PHONE NETWORK TO JOIN}
        Press    ${PHONE JOIN NETWORK BUTTON}    timeout=10s
    END

Trust The Head Unit On The Phone If It Asks
    [Documentation]    The first time AARE meets a head unit it stops and asks whether to trust it. Says yes,
    ...    and brings the phone into the car once more: AARE starts over with a head unit it now trusts.
    ${asked}=    Run Keyword And Return Status    Page Should Contain Element    ${AARE TRUST HEAD UNIT}
    IF    ${asked}
        Click Element    ${AARE TRUST HEAD UNIT}
        Bring The Phone Into The Car
    END

Phone Should Have Been Told The Head Unit's Network Over Bluetooth
    [Documentation]    AARE reached the head unit's service over Bluetooth and was given a Wi-Fi network and an
    ...    address there: nothing else told the phone where the car is.
    On The Phone
    ${log}=    ADB Shell    logcat -d -s Aare:I
    Should Contain    ${log}    wireless: RFCOMM connected to
    Should Match Regexp    ${log}    wireless: credentials ssid="${HEAD UNIT NETWORK}"
    Should Match Regexp    ${log}    wireless: head unit AAP server [0-9.]+:${PROJECTION PORT}

Phone Should Be On The Head Unit's Network
    On The Phone
    ${log}=    ADB Shell    logcat -d -s Aare:I
    Should Match Regexp    ${log}    wireless: joined "${HEAD UNIT NETWORK}" as [0-9.]+

Phone Should Be Projecting
    On The Phone
    ${log}=    ADB Shell    logcat -d -s Aare:I
    Should Contain    ${log}    Projecting to

Head Unit Should Be Showing The Phone
    [Documentation]    The head unit holds the phone's connection on the projection port, and has decoded and
    ...    drawn a picture from it.
    Wait Until Keyword Succeeds    60s    3s    Head Unit Should Have Drawn A Picture
    ${connections}=    Run Keyword    ${HEAD UNIT KIND} Head Unit: Connections
    Should Match Regexp    ${connections}    ESTAB.*:${PROJECTION PORT}\\s

Head Unit Should Have Drawn A Picture
    Run Keyword    ${HEAD UNIT KIND} Head Unit: Should Have Drawn A Picture

Android Head Unit: Connections
    On The Head Unit
    ${connections}=    ADB Shell    su 0 ss -tn
    RETURN    ${connections}

Android Head Unit: Should Have Drawn A Picture
    On The Head Unit
    ${log}=    ADB Shell    logcat -d -s OPENHU:I
    Should Contain    ${log}    First frame rendered

Radios Should Be Carrying The Projection
    [Documentation]    The lease's forwards are what is between the two devices: both are connected, and the
    ...    Wi-Fi radios count more frames while the picture is being sent.
    Forward Should Be Listening    ${BLUETOOTH FORWARD}
    Forward Should Be Listening    ${WIFI FORWARD}

Touch The Projected Screen On The Head Unit
    [Documentation]    Presses the "all apps" button of the projected car screen, and waits until the picture
    ...    on the head unit is another one: the touch went to the phone, and the phone drew what it opens.
    On The Head Unit
    ${before}=    Picture On The Head Unit
    ADB Shell    input tap ${PROJECTED APPS BUTTON}
    Wait Until Keyword Succeeds    30s    2s    Picture On The Head Unit Should Not Be    ${before}

Picture On The Head Unit
    [Documentation]    A fingerprint of what the head unit's main screen shows.
    ${display}=    ADB Shell    dumpsys SurfaceFlinger --display-id
    ${id}=    Should Match Regexp    ${display}    Display (\\d+) \\(HWC display 0\\)
    ${fingerprint}=    ADB Shell    screencap -d ${id}[1] | md5sum
    RETURN    ${fingerprint.split()}[0]

Picture On The Head Unit Should Not Be
    [Arguments]    ${before}
    ${now}=    Picture On The Head Unit
    Should Not Be Equal    ${now}    ${before}

Bluetooth Should Have Carried The Phone's Arrival
    [Documentation]    On each device's own record of its Bluetooth: since the phone came into the car a link to
    ...    the other device was made, and it was encrypted. The head unit's network name and key went over it.
    FOR    ${radio}    IN    @{RECORDING RADIOS}
        ${linked}=    Run Keyword    ${radio} Wait For Event    connection_complete    timeout=${30}    status=SUCCESS
        Should Not Be Empty    ${linked}    ${radio}: no Bluetooth link was made since the phone came into the car
        ${encrypted}=    Run Keyword    ${radio} Wait For Event    encryption_change    timeout=${30}
        ...    since=${linked}[index]
        Should Not Be Empty    ${encrypted}    ${radio}: the Bluetooth link was not encrypted
        Should Be Equal As Integers    ${encrypted}[fields][status]    0
        Log    ${radio}: ${linked}[name] at ${linked}[index], ${encrypted}[name] at ${encrypted}[index]
    END

# ---- What the phone's owner does in AARE -------------------------------------------------------------------------

Open AARE's First Page On The Phone
    [Documentation]    AARE, at the page it opens with, wherever it was left.
    On The Phone
    ADB Shell    input keyevent KEYCODE_WAKEUP
    ADB Shell    am start -n ${AARE PACKAGE}/.ui.MainActivity
    FOR    ${page}    IN RANGE    3
        ${first}=    Run Keyword And Return Status    Wait Until On Screen    ${AARE PREVIEW CAR SCREEN}    timeout=6s
        IF    ${first}    BREAK
        Run Keyword And Ignore Error    Click Element    ${AARE BACK}
    END
    Wait Until On Screen    ${AARE PREVIEW CAR SCREEN}

Preview The Car Screen On The Phone
    [Documentation]    AARE shows on the phone what it draws for the car: its owner can look without a car.
    Open AARE's First Page On The Phone
    Press    ${AARE PREVIEW CAR SCREEN}
    Wait Until On Screen    ${AARE CAR SCREEN APPS}
    ${activities}=    ADB Shell    dumpsys activity activities
    Should Match Regexp    ${activities}    topResumedActivity=.*${AARE PACKAGE}/\\.ui\\.CarPreviewActivity
    ADB Shell    input keyevent KEYCODE_BACK
    Wait Until On Screen    ${AARE PREVIEW CAR SCREEN}

Let AARE Read The Phone's Notifications
    [Documentation]    "Notification access", of AARE's "Finish setting up": it opens Android's settings, where the
    ...    phone's owner switches AARE on and says "Allow". Messages and what is playing can then go to the car.
    Open AARE's First Page On The Phone
    Press    ${AARE NOTIFICATION ACCESS}
    ${aare}=    Row Labelled    AARE
    Press    ${aare}
    Press    ${PHONE NOTIFICATION ACCESS SWITCH}
    Press    ${PHONE ALLOW NOTIFICATION ACCESS}
    Wait Until Keyword Succeeds    20s    2s    AARE Should Be Allowed To Read Notifications

AARE Should Be Allowed To Read Notifications
    On The Phone
    ${listeners}=    ADB Shell    settings get secure enabled_notification_listeners
    Should Contain    ${listeners}    ${AARE PACKAGE}/

Disconnect The Phone From The Head Unit In AARE
    [Documentation]    "Disconnect", on AARE's first page: the phone stops projecting. The two stay paired.
    Open AARE's First Page On The Phone
    Press    ${AARE DISCONNECT}
    Wait Until On Screen    ${AARE NOT CONNECTED}

Head Unit Should Not Be Showing The Phone
    [Documentation]    Nothing holds the projection port on the head unit any more.
    Wait Until Keyword Succeeds    30s    2s    Nothing Should Be Connected To The Projection Port

Nothing Should Be Connected To The Projection Port
    ${connections}=    Run Keyword    ${HEAD UNIT KIND} Head Unit: Connections
    Should Not Match Regexp    ${connections}    ESTAB.*:${PROJECTION PORT}\\s

Let The Phone's Sound Reach The Car
    [Documentation]    "Car audio", of AARE's "Finish setting up", by the method that needs nothing but the
    ...    owner's word: Android's screen-capture permission, for the entire screen. Android asks, and its owner
    ...    says "Share screen".
    ...
    ...    AARE takes the answer for the next time the phone projects, and keeps it only until it disconnects: it
    ...    is given while the phone is not projecting, and before it comes into the car.
    Open AARE's First Page On The Phone
    Press    ${AARE CAR AUDIO}
    Press    ${AARE SCREEN CAPTURE METHOD}
    Wait Until On Screen    ${PHONE SHARE SCREEN QUESTION}
    Press    ${PHONE SHARE SCREEN BUTTON}
    Wait Until On Screen    ${AARE USING SCREEN CAPTURE}

AARE Should Have Nothing Left To Set Up
    [Documentation]    Its "Finish setting up" list is gone from the first page: every row of it is done.
    Open AARE's First Page On The Phone
    Page Should Not Contain Element    ${AARE SETUP LEFT TO DO}

Bring The Phone Back Into The Car
    [Documentation]    A phone whose owner has answered everything once is asked nothing again: it comes into
    ...    the car and projects.
    Bring The Phone Into The Car
    Wait Until Keyword Succeeds    120s    3s    Phone Should Be Projecting

Play A Sound On The Phone
    [Documentation]    Plays one of the phone's own ringtones with its music player, as music.
    On The Phone
    ${found}=    ADB Shell
    ...    content query --uri content://media/internal/audio/media --projection _id --where "title='${SOUND ON THE PHONE}'"
    ${sound}=    Should Match Regexp    ${found}    _id=(\\d+)
    Run Keyword    ${HEAD UNIT KIND} Head Unit: Before A Sound
    On The Phone
    ADB Shell    am start -a android.intent.action.VIEW -d content://media/internal/audio/media/${sound}[1] -t audio/ogg

Stop The Sound On The Phone
    On The Phone
    ADB Shell    am force-stop com.android.music

Phone Should Be Sending Its Sound To The Car
    On The Phone
    ${log}=    ADB Shell    logcat -d -s Aare:I
    Should Contain    ${log}    car audio: Screen-capture permission

Head Unit Should Be Playing The Phone's Sound
    [Documentation]    The head unit is receiving sound from the phone over the projection, and playing it.
    Wait Until Keyword Succeeds    60s    3s    Head Unit Should Have Received Sound

Head Unit Should Have Received Sound
    Run Keyword    ${HEAD UNIT KIND} Head Unit: Should Have Received Sound

Android Head Unit: Before A Sound
    On The Head Unit
    ADB Shell    logcat -c

Android Head Unit: Should Have Received Sound
    On The Head Unit
    ${log}=    ADB Shell    logcat -d -s OPENHU:I
    Should Match Regexp    ${log}    AapAudio: AUDIO PCM timing: packets=[1-9]
