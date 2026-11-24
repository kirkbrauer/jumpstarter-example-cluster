*** Settings ***
Documentation     A driver's text messages in the car, with the phone paired to it.
...
...               A message that reaches the phone reaches the head unit, from the same number and with the same
...               words: plain ones, other scripts, emoji, and one too long for a single text message.
...
...               Run it as it is: `robot --outputdir results tests/bluetooth_messages.robot`.
Resource          ../resources/messages.resource
Suite Setup       Run Keywords    Lease The Phone And The Head Unit
...               AND    Forget The Text Messages On The Phone
...               AND    Pair The Phone With The Head Unit
...               AND    Let The Head Unit Keep The Phone's Messages
...               AND    Head Unit Should Be Ready For Messages
Suite Teardown    Release The Phone And The Head Unit


*** Variables ***
${FRIEND}            6505550142
${COLLEAGUE}         6505550143
${LONG MESSAGE}      The meeting moved to the third floor, room 3.14, and starts twenty minutes later than planned. Bring the signed copies, the spare badge and the charger you borrowed last week; parking is behind the building this time, not in front.


*** Test Cases ***
The Head Unit Has No Messages Before One Arrives
    Head Unit Should Have No Text Message

A Text Message To The Phone Reaches The Head Unit
    Receive A Text Message On The Phone    ${FRIEND}    Running late, start without me
    Phone Should Have The Text Message    ${FRIEND}    Running late, start without me
    Head Unit Should Have The Text Message    ${FRIEND}    Running late, start without me

A Message With Emoji Arrives As It Is
    Receive A Text Message On The Phone    ${FRIEND}    On my way 🚗💨 — see you at 7 🎉
    Head Unit Should Have The Text Message    ${FRIEND}    On my way 🚗💨 — see you at 7 🎉

Messages In Other Scripts Arrive As They Are
    Receive A Text Message On The Phone    ${COLLEAGUE}    今日は遅れます、すみません
    Receive A Text Message On The Phone    ${COLLEAGUE}    سأتأخر قليلاً
    Receive A Text Message On The Phone    ${COLLEAGUE}    Буду через десять минут
    Head Unit Should Have The Text Message    ${COLLEAGUE}    今日は遅れます、すみません
    Head Unit Should Have The Text Message    ${COLLEAGUE}    سأتأخر قليلاً
    Head Unit Should Have The Text Message    ${COLLEAGUE}    Буду через десять минут

A Long Message Arrives Whole
    Receive A Text Message On The Phone    ${COLLEAGUE}    ${LONG MESSAGE}
    Head Unit Should Have The Text Message    ${COLLEAGUE}    ${LONG MESSAGE}

Messages From Two People Are Kept Apart
    Receive A Text Message On The Phone    ${FRIEND}    Are you driving?
    Receive A Text Message On The Phone    ${COLLEAGUE}    Call me when you park
    Head Unit Should Have The Text Message    ${FRIEND}    Are you driving?
    Head Unit Should Have The Text Message    ${COLLEAGUE}    Call me when you park
