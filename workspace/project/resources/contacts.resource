*** Settings ***
Documentation     The phone's contacts in the car: once the phone's owner allows it, the head unit downloads the
...               phone book and has every contact, by the same name and number.
...
...               What the owner presses on the phone is pressed with Appium; what each device then has in its
...               contacts is read with ADB. (This head unit has no contacts screen of its own to read.)
Resource          bluetooth.resource
Library           Collections


*** Variables ***
# The switch on the head unit's page in the phone's Bluetooth settings, by its label
${PHONE CONTACT SHARING ROW}    Allow access to contacts and call history


*** Keywords ***
# ---- Before the head unit has the contacts --------------------------------------------------------------------

Forget The Contacts On The Phone
    [Documentation]    A phone with an empty contact list.
    On The Phone
    ADB Shell    pm clear com.android.providers.contacts

Add A Contact To The Phone
    [Documentation]    A contact with a name and a mobile number, as the phone's Contacts app would save it.
    [Arguments]    ${name}    ${number}
    On The Phone
    ADB Shell    content insert --uri content://com.android.contacts/raw_contacts --bind account_type:n: --bind account_name:n:
    ${rows}=    ADB Shell    content query --uri content://com.android.contacts/raw_contacts --projection _id
    ${ids}=    Evaluate    [int(i) for i in re.findall(r"_id=(\\d+)", $rows)]    modules=re
    ${contact}=    Evaluate    max($ids)
    ${quoted name}=    Evaluate    shlex.quote($name)    modules=shlex
    ADB Shell    content insert --uri content://com.android.contacts/data --bind raw_contact_id:i:${contact} --bind mimetype:s:vnd.android.cursor.item/name --bind data1:s:${quoted name}
    ADB Shell    content insert --uri content://com.android.contacts/data --bind raw_contact_id:i:${contact} --bind mimetype:s:vnd.android.cursor.item/phone_v2 --bind data1:s:${number} --bind data2:i:2

Share The Phone's Contacts With The Head Unit
    [Documentation]    On the head unit's page in the phone's Bluetooth settings, switches on "Allow access to
    ...    contacts and call history". The head unit asks for the phone book when it connects, so the phone then
    ...    disconnects and connects again.
    Open The Head Unit's Page On The Phone
    ${contact sharing}=    Row Labelled    ${PHONE CONTACT SHARING ROW}
    Press    ${contact sharing}
    Press    ${PHONE DISCONNECT BUTTON}
    Phone Should Not Be Connected To The Head Unit
    Press    ${PHONE CONNECT BUTTON}
    Head Unit Should Have Downloaded The Phone Book

Head Unit Should Have Downloaded The Phone Book
    On The Head Unit
    Wait Until Keyword Succeeds    90s    3s    Phone Book Should Be Connected

# ---- What each device has ----------------------------------------------------------------------------------------

Phone Should Have The Contact
    [Arguments]    ${name}    ${number}
    On The Phone
    Contact Should Be    ${name}    ${number}

Head Unit Should Have The Contact
    [Documentation]    The head unit has a contact with this number, and its name is this one, character for character.
    [Arguments]    ${name}    ${number}
    On The Head Unit
    Wait Until Keyword Succeeds    60s    3s    Contact Should Be    ${name}    ${number}

Head Unit Should Have No Contact With
    [Arguments]    ${number}
    On The Head Unit
    ${names}=    Get Names Of Contacts With    ${number}
    Should Be Empty    ${names}

# ---- What the keywords above are made of: ADB ------------------------------------------------------------------------

Phone Book Should Be Connected
    ${state}=    Get Bluetooth State
    Should Contain    ${state}    name=PbapClientStateMachine state=Connected

Contact Should Be
    [Arguments]    ${name}    ${number}
    ${names}=    Get Names Of Contacts With    ${number}
    Should Not Be Empty    ${names}    No contact has the number ${number}.
    Should Be Equal    ${names}[0]    ${name}

Get Names Of Contacts With
    [Documentation]    The names of the contacts that have this number, however the device writes the number
    ...    (650-555-0100). A device's contacts are those of the person driving it.
    [Arguments]    ${number}
    ${user}=    Get Driver's User
    ${rows}=    ADB Shell    content query --user ${user} --uri content://com.android.contacts/data/phones --projection data1:display_name    expected_rc=None
    ${names}=    Evaluate
    ...    [row.group(2) for row in re.finditer(r"data1=(.*?), display_name=(.*)", $rows) if re.sub(r"\\D", "", row.group(1)) == $number]
    ...    modules=re
    RETURN    ${names}
