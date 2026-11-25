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
Resource          bluetooth.resource
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
    On The Head Unit
    ADB Shell    su 0 cmd wifi set-wifi-enabled enabled

Start Open Headunit On The Head Unit
    [Documentation]    Opens the receiver. From then on the head unit offers wireless projection over Bluetooth
    ...    and keeps a Wi-Fi network of its own for the phone to join.
    On The Head Unit
    ADB Shell    logcat -c
    ADB Shell    monkey --pct-syskeys 0 -p ${OPEN HEADUNIT PACKAGE} -c android.intent.category.LAUNCHER 1
    Wait Until Keyword Succeeds    60s    3s    Head Unit Should Offer Wireless Projection

Head Unit Should Offer Wireless Projection
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
    ${state}=    Get Bluetooth State
    Should Contain    ${state}    ${service}

# ---- Projecting --------------------------------------------------------------------------------------------------

Bring The Phone Into The Car
    [Documentation]    A paired phone that comes into reach of the car connects to it over Bluetooth, and
    ...    projection starts from that. Here the phone's Bluetooth is switched off and on: the same to the car.
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
    Should Match Regexp    ${log}    wireless: credentials ssid="DIRECT-[^"]+"
    Should Match Regexp    ${log}    wireless: head unit AAP server [0-9.]+:${PROJECTION PORT}

Phone Should Be On The Head Unit's Network
    On The Phone
    ${log}=    ADB Shell    logcat -d -s Aare:I
    Should Match Regexp    ${log}    wireless: joined "DIRECT-[^"]+" as [0-9.]+

Phone Should Be Projecting
    On The Phone
    ${log}=    ADB Shell    logcat -d -s Aare:I
    Should Contain    ${log}    Projecting to

Head Unit Should Be Showing The Phone
    [Documentation]    The head unit holds the phone's connection on the projection port, and has decoded and
    ...    drawn a picture from it.
    On The Head Unit
    Wait Until Keyword Succeeds    60s    3s    Head Unit Should Have Drawn A Picture
    ${connections}=    ADB Shell    su 0 ss -tn
    Should Match Regexp    ${connections}    ESTAB.*:${PROJECTION PORT}\\s

Head Unit Should Have Drawn A Picture
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
