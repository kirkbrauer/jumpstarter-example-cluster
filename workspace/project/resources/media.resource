*** Settings ***
Documentation     Music with the phone paired to the head unit: the phone plays it, and the head unit shows what
...               is playing and has the buttons.
...
...               The phone's player is `apps/test-player`: two tracks, each a tone it generates, and a screen
...               whose every part has an accessibility id. What a person would press on either device is pressed
...               with Appium; what each device believes is playing is read with ADB.
Resource          bluetooth.resource


*** Variables ***
${TEST PLAYER APK}                  ${CURDIR}/../apps/test-player/jumpstarter-test-player.apk
${TEST PLAYER PACKAGE}              dev.jumpstarter.testplayer
${FIRST TRACK}                      Jumpstarter Test Tone
${SECOND TRACK}                     Second Test Tone

# ---- The test player's screen on the phone: accessibility ids throughout ----------------------------------------------
${PHONE TRACK TITLE}                accessibility_id=Track title
${PHONE PLAYBACK STATE}             accessibility_id=Playback state
${PHONE PLAY BUTTON}                accessibility_id=Play
${PHONE PAUSE BUTTON}               accessibility_id=Pause
${PHONE NEXT TRACK BUTTON}          accessibility_id=Next track
${PHONE PREVIOUS TRACK BUTTON}      accessibility_id=Previous track

# ---- The head unit's media app (com.android.car.media) with Bluetooth Audio as its source ---------------------------
# The app launcher and its entry: the launcher's button has an accessibility id; an app in its grid is found by
# its label, the only thing that tells one app from the next.
${HEAD UNIT APP LAUNCHER}           accessibility_id=Applications
${HEAD UNIT BLUETOOTH AUDIO APP}    android=new UiSelector().resourceId("com.android.car.carlauncher:id/app_name").text("Bluetooth Audio")
# What is playing, and the buttons under it (resource ids: the buttons have no accessibility ids)
${HEAD UNIT TRACK TITLE}            id=com.android.car.media:id/minimized_control_bar_title
${HEAD UNIT TRACK ARTIST}           id=com.android.car.media:id/minimized_control_bar_subtitle
${HEAD UNIT PLAY PAUSE BUTTON}      id=com.android.car.media:id/play_pause_stop
${HEAD UNIT NEXT TRACK BUTTON}      id=com.android.car.media:id/skip_next
${HEAD UNIT PREVIOUS TRACK BUTTON}  id=com.android.car.media:id/skip_prev


*** Keywords ***
# ---- Before the music --------------------------------------------------------------------------------------------

Pair The Phone With The Head Unit For Music
    [Documentation]    Pairs the two and waits for the head unit to connect the phone's audio. On these virtual
    ...    radios that connection now and then stays "connecting" after a pairing; a driver would pair again, and
    ...    so does this, up to three times.
    Wait Until Keyword Succeeds    3x    1s    Pair And Wait For Music

Pair And Wait For Music
    Stop Bluetooth Bridge
    Pair The Phone With The Head Unit
    Head Unit Should Be Ready For Music

Head Unit Should Be Ready For Music
    [Documentation]    Paired is not yet playing music: the head unit connects the phone's audio and its remote
    ...    control a moment after pairing, and its music app shows nothing of the phone until then.
    On The Head Unit
    Wait Until Keyword Succeeds    60s    3s    Audio And Remote Control Should Be Connected

Install The Test Player On The Phone
    On The Phone
    ADB Shell    pm uninstall ${TEST PLAYER PACKAGE}    expected_rc=None
    ADB Install    ${TEST PLAYER APK}

Open The Test Player On The Phone
    On The Phone
    ADB Shell    am start -n ${TEST PLAYER PACKAGE}/.MainActivity
    Wait Until On Screen    ${PHONE TRACK TITLE}

Open Bluetooth Audio On The Head Unit
    [Documentation]    Presses the app launcher, then "Bluetooth Audio": the head unit's media app, playing what
    ...    the phone plays. A head unit only lets a phone play while this is its source of music.
    On The Head Unit
    Press    ${HEAD UNIT APP LAUNCHER}
    Press    ${HEAD UNIT BLUETOOTH AUDIO APP}
    Wait Until On Screen    ${HEAD UNIT PLAY PAUSE BUTTON}    timeout=60s

Offer The Phone's Music To The Head Unit
    [Documentation]    Presses Play on the phone. A head unit follows the player that last played on the phone, and
    ...    pauses music it did not ask for: the music starts, the head unit learns of the player and pauses it, and
    ...    from then on shows it and has its buttons.
    Press Play On The Phone
    Head Unit Should Show The Track    ${FIRST TRACK}

Start From The First Track, Paused
    [Documentation]    Where every test begins, set on the phone itself.
    On The Phone
    Press    ${PHONE PAUSE BUTTON}
    Phone Should Be Paused
    ${title}=    Read    ${PHONE TRACK TITLE}
    IF    $title != $FIRST_TRACK    Press    ${PHONE PREVIOUS TRACK BUTTON}
    Phone Should Show The Track    ${FIRST TRACK}

# ---- The buttons ---------------------------------------------------------------------------------------------------

Press Play On The Head Unit
    [Documentation]    Presses the head unit's play/pause button, with the music paused.
    On The Head Unit
    Press    ${HEAD UNIT PLAY PAUSE BUTTON}

Press Pause On The Head Unit
    [Documentation]    Presses the head unit's play/pause button, with the music playing.
    On The Head Unit
    Press    ${HEAD UNIT PLAY PAUSE BUTTON}

Press Next Track On The Head Unit
    On The Head Unit
    Press    ${HEAD UNIT NEXT TRACK BUTTON}

Press Previous Track On The Head Unit
    On The Head Unit
    Press    ${HEAD UNIT PREVIOUS TRACK BUTTON}

Press Play On The Phone
    On The Phone
    Press    ${PHONE PLAY BUTTON}

Press Next Track On The Phone
    On The Phone
    Press    ${PHONE NEXT TRACK BUTTON}

# ---- What each device shows and believes ---------------------------------------------------------------------------

Phone Should Show The Track
    [Arguments]    ${title}
    On The Phone
    Wait Until Keyword Succeeds    30s    2s    Element Text Should Be    ${PHONE TRACK TITLE}    ${title}

Head Unit Should Show The Track
    [Arguments]    ${title}
    On The Head Unit
    Wait Until Keyword Succeeds    30s    2s    Element Text Should Be    ${HEAD UNIT TRACK TITLE}    ${title}

Head Unit Should Show The Artist
    [Arguments]    ${artist}
    On The Head Unit
    Wait Until Keyword Succeeds    30s    2s    Element Text Should Be    ${HEAD UNIT TRACK ARTIST}    ${artist}

Phone Should Be Playing
    [Documentation]    The player's own screen says so, and so does the phone: its media session is playing, and it
    ...    is sending the music over Bluetooth.
    On The Phone
    Wait Until Keyword Succeeds    30s    2s    Element Text Should Be    ${PHONE PLAYBACK STATE}    Playing
    Wait Until Keyword Succeeds    30s    2s    Media Session Should Be    PLAYING
    Wait Until Keyword Succeeds    30s    2s    Bluetooth Audio Should Be Streaming    true

Phone Should Be Paused
    On The Phone
    Wait Until Keyword Succeeds    30s    2s    Element Text Should Be    ${PHONE PLAYBACK STATE}    Paused
    Wait Until Keyword Succeeds    30s    2s    Media Session Should Be    PAUSED
    Wait Until Keyword Succeeds    30s    2s    Bluetooth Audio Should Be Streaming    false

# ---- What the keywords above are made of: ADB --------------------------------------------------------------------------

Audio And Remote Control Should Be Connected
    [Documentation]    The head unit's side of the two profiles music needs: audio (A2DP) and remote control (AVRCP).
    ${state}=    Get Bluetooth State
    Should Contain    ${state}    name=A2dpSinkStateMachine state=Connected
    Should Contain    ${state}    name=AvrcpControllerStateMachine state=Connected

Media Session Should Be
    [Documentation]    The state of the test player's media session: what the lock screen and a head unit are told.
    [Arguments]    ${state}
    ${sessions}=    ADB Shell    dumpsys media_session
    Should Match Regexp    ${sessions}    (?s)package=${TEST PLAYER PACKAGE}\\b.*?state=PlaybackState \\{state=${state}\\(

Bluetooth Audio Should Be Streaming
    [Documentation]    Whether the phone's Bluetooth audio profile (A2DP) is sending audio now.
    [Arguments]    ${streaming}
    ${state}=    Get Bluetooth State
    Should Contain    ${state}    mIsPlaying: ${streaming}
