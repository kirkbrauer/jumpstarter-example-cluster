*** Settings ***
Documentation     A Linux head unit in QEMU, as the head unit of the phone projection suite.
...
...               It is not an Android device: there is no ADB and no Appium on it. What a person at its console
...               would type is typed here over SSH or over its serial console (`${HEAD UNIT SHELL}`), and every
...               keyword below is written on that one keyword, `Head Unit Shell`.
...
...               The head unit runs LIVI, an open-source receiver for Linux, on BlueZ and hostapd. Its Bluetooth is
...               one more host of the phone's controller simulator (the lease's `bluetooth` forward), and its
...               simulated Wi-Fi radio is on the phone's air (the `wifi` forward): see
...               `cluster/devices-linux-headunit`.
Resource          devices.resource
Library           Collections
Library           jumpstarter_robot.Driver    qemu.power    client=jumpstarter_driver_power.client.PowerClient
...               prefix=Linux Head Unit Power    session=headunit    AS    headunit.qemu.power
Library           jumpstarter_robot.Driver    qemu.flasher    client=jumpstarter_driver_qemu.client.QemuFlasherClient
...               prefix=Linux Head Unit Disk    session=headunit    AS    headunit.qemu.flasher


*** Variables ***
# The head unit's disk image (images/headunit-linux), as its exporter can fetch it: an `https://` URL of the
# qcow2, or `oci://…`. A device is made anew for each lease, with an empty disk. Empty: the disk is left as it is.
${HEAD UNIT IMAGE}                  ${EMPTY}
# How the head unit is talked to: `ssh` (the exporter's `ssh` driver) or `console` (QEMU's serial console).
${HEAD UNIT SHELL}                  ssh
${HEAD UNIT SSH}                    ssh
${HEAD UNIT CONSOLE}                qemu.console
# Who logs in on the console, and the prompt that follows. (Over SSH the driver has the user and its key.)
${HEAD UNIT USER}                   hu
${HEAD UNIT PASSWORD}               headunit
${HEAD UNIT PROMPT}                 hu@headunit:~$
# Where LIVI keeps its settings, its log and what it is doing now.
${LIVI HOME}                        /home/hu/.config/LIVI
${LIVI SERVICE}                     livi-kiosk
# The simulated Wi-Fi radio LIVI's access point is on.
${HEAD UNIT WIFI INTERFACE}         wlan0


*** Keywords ***
# ---- The one keyword everything else is written on --------------------------------------------------------------

Head Unit Shell
    [Documentation]    Runs a command on the head unit and returns what it printed. Fails if the command does,
    ...    unless `expected_rc=None`.
    [Arguments]    ${command}    ${expected_rc}=0
    ${output}=    Run Keyword    Head Unit Shell Over ${HEAD UNIT SHELL}    ${command}    ${expected_rc}
    RETURN    ${output}

Head Unit Shell Over ssh
    [Arguments]    ${command}    ${expected_rc}
    ${result}=    Execute Over SSH    ${command}    path=${HEAD UNIT SSH}    expected_rc=${expected_rc}
    ...    session=headunit
    RETURN    ${result.stdout}

Head Unit Shell Over console
    [Documentation]    The same on the serial console: the command's exit status is asked for after it, since a
    ...    console has only what is printed. What a terminal adds (the command as it was typed, and the escape
    ...    codes around what it printed) is taken out.
    [Arguments]    ${command}    ${expected_rc}
    Switch Console    headunit
    Clear Console Buffer
    ${raw}=    Console Execute Command    ${command}; echo "headunit-rc=$?"    timeout=90s
    ${text}=    Evaluate    re.sub(r"\\x1b\\[[?0-9;]*[A-Za-z]|\\r", "", $raw)    modules=re
    ${found}=    Evaluate    re.search(r"(?s)(?:^|\\n)(.*)headunit-rc=(\\d+)\\s*$", $text.split('headunit-rc=$?"', 1)[-1])    modules=re
    Should Be True    $found is not None    The console did not say how `${command}` ended: ${text}
    ${output}=    Evaluate    $found.group(1).strip()
    IF    $expected_rc not in (None, "None")
        Should Be Equal As Integers    ${found.group(2)}    ${expected_rc}    `${command}` exited with ${found.group(2)}: ${output}
    END
    RETURN    ${output}

Open The Linux Head Unit
    [Documentation]    Waits until Linux has booted and answers, over SSH or on its console.
    IF    "${HEAD UNIT SHELL}" == "console"
        Open Console    ${HEAD UNIT CONSOLE}    alias=headunit    prompt=${HEAD UNIT PROMPT}    session=headunit
        Wait Until Keyword Succeeds    5 min    10s    Log In On The Head Unit's Console
    END
    Wait Until Keyword Succeeds    5 min    10s    Head Unit Shell    true

Log In On The Head Unit's Console
    [Documentation]    A console says nothing until it is spoken to: a head unit that booted a while ago printed
    ...    its login prompt then. A line is sent, and what comes back says where the console is: at the login
    ...    prompt, or with somebody logged in already.
    Clear Console Buffer
    Console Write Line
    ${seen}=    Console Read Until Regexp    login:    \\$\\s*$    timeout=15s
    IF    "login:" in $seen
        Console Write Line
        Console Login    ${HEAD UNIT USER}    ${HEAD UNIT PASSWORD}    timeout=30s
    END
    Console Write Line
    Console Read Until Prompt    timeout=15s

# ---- The lease ---------------------------------------------------------------------------------------------------

Lease The Phone And The Linux Head Unit
    [Documentation]    Both devices in one lease, as `Lease The Phone And The Head Unit`. The phone has the
    ...    Bluetooth controller simulator that both use, so it is powered on first.
    Wait Until Keyword Succeeds    ${LEASE PATIENCE}    15s    Acquire Lease
    Role Should Be Bound    phone
    Role Should Be Bound    headunit
    Phone Power On
    IF    "${HEAD UNIT IMAGE}"    Linux Head Unit Disk Flash    ${HEAD UNIT IMAGE}
    Linux Head Unit Power On
    Wait Until Forward Is Listening    ${BLUETOOTH FORWARD}    timeout=2 min
    Open ADB And Appium    phone
    Open The Linux Head Unit

# ---- The head unit's own Bluetooth (BlueZ) -----------------------------------------------------------------------

Linux Head Unit Bluetooth Name
    [Documentation]    What the head unit calls itself on the air: what the phone lists.
    ${adapter}=    Head Unit Shell    bluetoothctl show
    ${name}=    Should Match Regexp    ${adapter}    (?m)^\\s*Alias:\\s*(.+?)\\s*$
    RETURN    ${name}[1]

Linux Head Unit Bluetooth Should Be On
    ${adapter}=    Head Unit Shell    bluetoothctl show
    Should Contain    ${adapter}    Powered: yes    The head unit's Bluetooth is off, or has no controller: ${adapter}

Forget Paired Devices On The Linux Head Unit
    [Documentation]    Bluetooth as on a head unit nobody has paired with: every device it remembers is removed.
    Head Unit Shell
    ...    for device in $(bluetoothctl devices | cut -d" " -f2); do bluetoothctl remove $device; done
    ...    expected_rc=None

Let The Linux Head Unit Be Found And Paired With
    [Documentation]    A head unit shows itself and agrees to a phone that asks, as a car does while its
    ...    "add a phone" page is open. LIVI does both itself; this makes sure of it, whoever answers first.
    Head Unit Shell    bluetoothctl discoverable on
    Head Unit Shell    bluetoothctl pairable on
    # (an agent that says yes, for a head unit whose receiver has none of its own; a second one is not used)
    Head Unit Shell    pgrep -x bt-agent >/dev/null || (nohup bt-agent -c NoInputNoOutput >/dev/null 2>&1 &)
    ...    expected_rc=None

Linux Head Unit Should Be Paired With
    [Arguments]    ${name}
    ${paired}=    Head Unit Shell    bluetoothctl devices Paired
    Should Contain    ${paired}    ${name}    The head unit has not paired with ${name}: ${paired}

Pair The Phone With The Linux Head Unit
    [Documentation]    The whole of pairing, started on the phone: its owner finds the head unit in the phone's
    ...    Bluetooth settings and agrees. The two are on one simulated air, so each sees the other as it is.
    Reset Bluetooth    phone    Phone Radio
    Wait Until Keyword Succeeds    2 min    5s    Linux Head Unit Bluetooth Should Be On
    Forget Paired Devices On The Linux Head Unit
    ${phone}=    Get Bluetooth Identity    phone
    ${head unit}=    Linux Head Unit Bluetooth Name
    Set Suite Variable    ${PHONE NAME}    ${phone}[name]
    Set Suite Variable    ${HEAD UNIT NAME}    ${head unit}
    Let The Linux Head Unit Be Found And Paired With
    Open Bluetooth Settings On The Phone
    Look For New Devices On The Phone
    Choose The Head Unit On The Phone
    Confirm The Pairing On The Phone
    # (a head unit that asks for the phone's messages makes the phone ask its owner; LIVI may not)
    Run Keyword And Ignore Error    Allow The Head Unit To Read Messages On The Phone
    Wait Until Keyword Succeeds    60s    3s    Linux Head Unit Should Be Paired With    ${PHONE NAME}
    Phone Should Be Paired With The Head Unit

# ---- The receiver: what the projection keywords ask of a head unit ----------------------------------------------
#
# `projection.resource` asks each of these of the head unit there is, by its kind: `Linux Head Unit: …` here,
# `Android Head Unit: …` there.

Linux Head Unit: Install The Receiver
    [Documentation]    Nothing to install: LIVI is part of the head unit's image. Wireless Android Auto is one
    ...    of its settings, and is switched on.
    Head Unit Shell    test -s ${LIVI HOME}/config.json || (sudo systemctl start ${LIVI SERVICE}; sleep 20)
    Head Unit Shell    sudo systemctl stop ${LIVI SERVICE}    expected_rc=None
    Head Unit Shell
    ...    python3 -c 'import json; p="${LIVI HOME}/config.json"; c=json.load(open(p)); c["wirelessAaEnabled"]=True; c["country"]="US"; json.dump(c, open(p, "w"), indent=2)'

Linux Head Unit: Switch Wi-Fi On
    Head Unit Shell    sudo rfkill unblock wifi    expected_rc=None

Linux Head Unit: Start The Receiver
    [Documentation]    Starts LIVI anew, with an empty log: what it says from here on is this run.
    Head Unit Shell    sudo systemctl stop ${LIVI SERVICE}    expected_rc=None
    Head Unit Shell    : > ${LIVI HOME}/log/LIVI.log    expected_rc=None
    Head Unit Shell    sudo systemctl start ${LIVI SERVICE}

Linux Head Unit: Should Offer Wireless Projection
    [Documentation]    LIVI has told BlueZ its service, BlueZ lists it, and the access point is up.
    ${log}=    Linux Head Unit Receiver Log
    Should Contain    ${log}    [aa] profile registered
    Should Contain    ${log}    the access point is up
    ${adapter}=    Head Unit Shell    bluetoothctl show
    Should Contain    ${adapter}    ${WIRELESS PROJECTION SERVICE}
    ${radio}=    Head Unit Shell    /usr/sbin/iw dev ${HEAD UNIT WIFI INTERFACE} info
    Should Contain    ${radio}    type AP

Linux Head Unit: Should Have Drawn A Picture
    [Documentation]    LIVI says what it is doing in a file of its own: a phone projects, and its picture is
    ...    being shown.
    ${status}=    Linux Head Unit Receiver Status
    Should Be True    $status["projection"]["streaming"]    The head unit is not showing a phone: ${status}[projection]

Linux Head Unit: Connections
    ${connections}=    Head Unit Shell    ss -tn
    RETURN    ${connections}

Linux Head Unit: Should Have Received Sound
    ${status}=    Linux Head Unit Receiver Status
    Should Be True    $status["audio"]["media"]["playing"]    The head unit is not playing the phone's sound: ${status}[audio]

Linux Head Unit: Before A Sound
    No Operation

Linux Head Unit Receiver Log
    ${log}=    Head Unit Shell    cat ${LIVI HOME}/log/LIVI.log
    RETURN    ${log}

Linux Head Unit Receiver Status
    [Documentation]    What LIVI says it is doing now (`state/status.json`), as a dictionary.
    ${text}=    Head Unit Shell    cat ${LIVI HOME}/state/status.json
    ${status}=    Evaluate    json.loads($text)["payload"]    modules=json
    RETURN    ${status}
