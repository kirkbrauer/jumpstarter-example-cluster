*** Settings ***
Documentation     Text messages in the car: a message that reaches the phone reaches the head unit, word for word.
...
...               The phone's owner allowed it while pairing ("Allow access to messages?", see
...               `Allow The Head Unit To Read Messages On The Phone`). Both devices are read with ADB: this head
...               unit has no messages screen, and keeps the phone's messages for the apps that would show them.
Resource          bluetooth.resource


*** Keywords ***
# ---- Before a message ------------------------------------------------------------------------------------------

Let The Head Unit Keep The Phone's Messages
    [Documentation]    A head unit keeps the messages it receives from the phone for its messaging apps. The
    ...    emulator's Bluetooth is not allowed to on its own, which a car's is: allow it.
    On The Head Unit
    ${user}=    Get Driver's User
    ADB Shell    appops set --user ${user} com.android.bluetooth WRITE_SMS allow

Forget The Text Messages On The Phone
    On The Phone
    ADB Shell    su 0 content delete --uri content://sms

Head Unit Should Be Ready For Messages
    [Documentation]    Paired is not yet connected for messages: the head unit asks for them a moment later.
    On The Head Unit
    Wait Until Keyword Succeeds    60s    3s    Messages Should Be Connected

# ---- A message ------------------------------------------------------------------------------------------------------

Receive A Text Message On The Phone
    [Documentation]    A text message from this number arrives in the phone's inbox. (The emulator has no network
    ...    to send one over, so the message is put where the phone's radio would put it.)
    [Arguments]    ${from}    ${text}
    On The Phone
    ${quoted text}=    Evaluate    shlex.quote($text)    modules=shlex
    ADB Shell    su 0 content insert --uri content://sms/inbox --bind address:s:${from} --bind body:s:${quoted text} --bind read:i:0 --bind date:l:$(date +%s)000

Phone Should Have The Text Message
    [Arguments]    ${from}    ${text}
    On The Phone
    Text Message Should Be Kept    ${from}    ${text}

Head Unit Should Have The Text Message
    [Documentation]    The head unit has the message, from the same number and with the same words.
    [Arguments]    ${from}    ${text}
    On The Head Unit
    Wait Until Keyword Succeeds    60s    3s    Text Message Should Be Kept    ${from}    ${text}

Head Unit Should Have No Text Message
    On The Head Unit
    ${messages}=    Get Text Messages
    Should Be Empty    ${messages}

# ---- What the keywords above are made of: ADB ------------------------------------------------------------------------

Messages Should Be Connected
    ${state}=    Get Bluetooth State
    Should Contain    ${state}    name=MceStateMachine state=Connected

Text Message Should Be Kept
    [Arguments]    ${from}    ${text}
    ${messages}=    Get Text Messages
    Should Contain    ${messages}    ${from}: ${text}

Get Text Messages
    [Documentation]    The device's text messages, as a list of "number: text". A device's messages are those of
    ...    the person driving it.
    ${user}=    Get Driver's User
    ${rows}=    ADB Shell    content query --user ${user} --uri content://sms --projection address:body    expected_rc=None
    ${messages}=    Evaluate
    ...    [f"{row.group(1)}: {row.group(2)}" for row in re.finditer(r"(?s)address=(.*?), body=(.*?)(?=\\nRow: \\d+ address=|\\Z)", $rows.strip())]
    ...    modules=re
    RETURN    ${messages}
