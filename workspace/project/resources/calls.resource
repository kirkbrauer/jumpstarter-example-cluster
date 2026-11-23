*** Settings ***
Documentation     Phone calls with the phone paired to the head unit: the phone makes the call, and the head unit,
...               as its hands-free device, has the same call and can end it.
...
...               What a person would press on the phone is pressed with Appium; what each device believes about
...               the call is read with ADB (`dumpsys telecom`, and the head unit's hands-free state).
Resource          bluetooth.resource
Library           String


*** Variables ***
# ---- What is pressed and read on the phone's call screen (com.android.dialer) --------------------------------------
${PHONE CALL SCREEN NUMBER}         id=com.android.dialer:id/contactgrid_contact_name
${PHONE END CALL BUTTON}            accessibility_id=End call


*** Keywords ***
# ---- Before a call ---------------------------------------------------------------------------------------------

Head Unit Should Be Ready For Calls
    [Documentation]    Paired is not yet hands-free: the head unit connects the phone's calls a moment after pairing.
    On The Head Unit
    Wait Until Keyword Succeeds    60s    3s    Hands Free Should Be Connected

# ---- A call --------------------------------------------------------------------------------------------------------

Call From The Phone
    [Documentation]    Dials the number on the phone, and waits for the phone's call screen.
    [Arguments]    ${number}
    On The Phone
    ADB Shell    am start -a android.intent.action.CALL -d tel:${number}
    Wait Until On Screen    ${PHONE CALL SCREEN NUMBER}

Call From The Head Unit
    [Documentation]    Dials the number on the head unit: it has no radio of its own, so the call is the phone's.
    ...    (This head unit's dialer has no keypad to press, so the number is handed to it as a dial request.)
    [Arguments]    ${number}
    On The Head Unit
    ADB Shell    am start --user current -a android.intent.action.CALL -d tel:${number}

Phone Should Have A Call With
    [Documentation]    The phone's own telephony has the call, whoever dialled it.
    [Arguments]    ${number}
    On The Phone
    Wait Until Keyword Succeeds    30s    2s    A Call Should Be In Progress
    Wait Until On Screen    ${PHONE CALL SCREEN NUMBER}
    Phone Should Show A Call With    ${number}

Phone Should Show A Call With
    [Documentation]    The number on the phone's call screen, whatever way the phone writes it: (650) 555-0100.
    [Arguments]    ${number}
    On The Phone
    ${shown}=    Read    ${PHONE CALL SCREEN NUMBER}
    ${digits}=    Remove String Using Regexp    ${shown}    \\D
    Should Be Equal    ${digits}    ${number}

Head Unit Should Have A Call With
    [Arguments]    ${number}
    On The Head Unit
    Wait Until Keyword Succeeds    30s    2s    Hands Free Call Should Be Active With    ${number}

End The Call On The Phone
    [Documentation]    Presses the "End call" button of the phone's call screen.
    On The Phone
    Press    ${PHONE END CALL BUTTON}

Hang Up On The Head Unit
    [Documentation]    Presses the head unit's hang-up key, the one on a steering wheel. (This head unit's dialer
    ...    has no call screen of its own to press.)
    On The Head Unit
    ADB Shell    input keyevent KEYCODE_ENDCALL

Phone Should Have No Call
    On The Phone
    Wait Until Keyword Succeeds    30s    2s    No Call Should Be In Progress

Head Unit Should Have No Call
    On The Head Unit
    Wait Until Keyword Succeeds    30s    2s    No Call Should Be In Progress

# ---- What the keywords above are made of: ADB --------------------------------------------------------------------------

Get Calls In Progress
    [Documentation]    The calls the device's telephony knows of, one line each; empty when there is none.
    ${calls}=    ADB Shell    dumpsys telecom | grep "Call id=TC@" | sort -u    expected_rc=None
    RETURN    ${calls}

A Call Should Be In Progress
    ${calls}=    Get Calls In Progress
    Should Not Be Empty    ${calls}

No Call Should Be In Progress
    ${calls}=    Get Calls In Progress
    Should Be Empty    ${calls}

Hands Free Should Be Connected
    ${state}=    Get Bluetooth State
    Should Contain    ${state}    name=HeadsetClientStateMachine state=Connected

Hands Free Call Should Be Active With
    [Documentation]    The head unit's hands-free profile lists the phone's calls, with their state and number.
    [Arguments]    ${number}
    ${state}=    Get Bluetooth State
    Should Match Regexp    ${state}    HfpClientCall\\{[^}]*mState: ACTIVE, mNumber: ${number}\\b
