*** Settings ***
Documentation     A driver's contacts in the car, with the phone paired to it.
...
...               The phone's owner allows the head unit to read the phone book; the head unit downloads it, and
...               has every contact by the same name. The names are the hard part: other scripts, right-to-left
...               writing, accents, emoji and a very long one must all arrive as they are on the phone.
...
...               Run it as it is: `robot --outputdir results tests/bluetooth_contacts.robot`.
Resource          ../resources/contacts.resource
Suite Setup       Run Keywords    Lease The Phone And The Head Unit
...               AND    Forget The Contacts On The Phone
...               AND    Add The Contacts To The Phone
...               AND    Pair The Phone With The Head Unit
Suite Teardown    Run Keywords    Stop Bluetooth Bridge    AND    Release The Phone And The Head Unit


*** Variables ***
# A name, and the number that tells its contact from the others.
&{PLAIN}          name=Ada Lovelace    number=6505550101
&{ACCENTS}        name=Zoë Åström-O'Brien    number=6505550102
&{JAPANESE}       name=山田太郎    number=6505550103
&{KOREAN}         name=김민준    number=6505550104
&{CYRILLIC}       name=Анна Каренина    number=6505550105
&{GREEK}          name=Ελένη Παπαδοπούλου    number=6505550106
&{ARABIC}         name=محمد بن سلمان    number=6505550107
&{HEBREW}         name=שרה כהן    number=6505550108
&{EMOJI}          name=Renée 🚗🎵 Müller    number=6505550109
&{LONG}           name=Maximiliana Wolfeschlegelsteinhausenbergerdorff Featherstonehaugh Cholmondeley Throckmorton Ponsonby Fotheringay Smythe
...               number=6505550110
@{CONTACTS}       ${PLAIN}    ${ACCENTS}    ${JAPANESE}    ${KOREAN}    ${CYRILLIC}    ${GREEK}    ${ARABIC}    ${HEBREW}
...               ${EMOJI}    ${LONG}


*** Test Cases ***
The Head Unit Has No Contacts Until The Phone's Owner Allows It
    Head Unit Should Have No Contact With    ${PLAIN}[number]

The Head Unit Has A Contact Of The Phone
    [Setup]    Share The Phone's Contacts With The Head Unit
    Head Unit Should Have The Contact    ${PLAIN}[name]    ${PLAIN}[number]

Names With Accents And Punctuation Arrive As They Are
    Head Unit Should Have The Contact    ${ACCENTS}[name]    ${ACCENTS}[number]

Names In Other Scripts Arrive As They Are
    Head Unit Should Have The Contact    ${JAPANESE}[name]    ${JAPANESE}[number]
    Head Unit Should Have The Contact    ${KOREAN}[name]    ${KOREAN}[number]
    Head Unit Should Have The Contact    ${CYRILLIC}[name]    ${CYRILLIC}[number]
    Head Unit Should Have The Contact    ${GREEK}[name]    ${GREEK}[number]

Names Written Right To Left Arrive As They Are
    Head Unit Should Have The Contact    ${ARABIC}[name]    ${ARABIC}[number]
    Head Unit Should Have The Contact    ${HEBREW}[name]    ${HEBREW}[number]

A Name With Emoji Arrives As It Is
    Head Unit Should Have The Contact    ${EMOJI}[name]    ${EMOJI}[number]

A Very Long Name Arrives Whole
    Head Unit Should Have The Contact    ${LONG}[name]    ${LONG}[number]


*** Keywords ***
Add The Contacts To The Phone
    FOR    ${contact}    IN    @{CONTACTS}
        Add A Contact To The Phone    ${contact}[name]    ${contact}[number]
        Phone Should Have The Contact    ${contact}[name]    ${contact}[number]
    END
