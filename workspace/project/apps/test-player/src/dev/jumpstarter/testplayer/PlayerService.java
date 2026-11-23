// SPDX-License-Identifier: Apache-2.0
package dev.jumpstarter.testplayer;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.content.Intent;
import android.content.pm.ServiceInfo;
import android.media.AudioAttributes;
import android.media.AudioFocusRequest;
import android.media.AudioFormat;
import android.media.AudioManager;
import android.media.AudioTrack;
import android.media.MediaDescription;
import android.media.MediaMetadata;
import android.media.browse.MediaBrowser;
import android.media.session.MediaSession;
import android.media.session.PlaybackState;
import android.os.Bundle;
import android.os.SystemClock;
import android.service.media.MediaBrowserService;

import java.util.ArrayList;
import java.util.List;

/**
 * A player with nothing to configure and nothing to download: two tracks, each a tone it generates itself.
 *
 * It is what a test needs of a media app: a media session with the track's title, artist, album and length, a
 * playback state, and the transport controls (play, pause, next, previous). Whatever follows media sessions sees
 * and drives it: the lock screen, a watch, and a car's head unit over Bluetooth (AVRCP).
 */
public class PlayerService extends MediaBrowserService {
    static final String ROOT = "root";
    static final int RATE = 44100;
    static final long LENGTH_MS = 180_000;

    /** title, artist, album, the tone's pitch in hertz */
    static final String[][] TRACKS = {
        {"Jumpstarter Test Tone", "Jumpstarter", "Test Tones", "440"},
        {"Second Test Tone", "Jumpstarter", "Test Tones", "660"},
    };

    private MediaSession session;
    private AudioManager audio;
    private AudioFocusRequest focus;
    private volatile boolean playing;
    private volatile int track;
    private volatile long frames;  // of the current track that have been played
    private Thread tone;

    @Override
    public void onCreate() {
        super.onCreate();
        audio = getSystemService(AudioManager.class);
        session = new MediaSession(this, "JumpstarterTestPlayer");
        session.setCallback(new MediaSession.Callback() {
            @Override public void onPlay() { play(); }
            @Override public void onPause() { pause(); }
            @Override public void onStop() { pause(); }
            @Override public void onSkipToNext() { choose((track + 1) % TRACKS.length); }
            @Override public void onSkipToPrevious() { choose((track + TRACKS.length - 1) % TRACKS.length); }
            @Override public void onPlayFromMediaId(String id, Bundle extras) {
                choose(Integer.parseInt(id));
                play();
            }
        });
        setSessionToken(session.getSessionToken());
        describe();
        session.setActive(true);
    }

    @Override
    public void onDestroy() {
        pause();
        session.release();
        super.onDestroy();
    }

    @Override
    public BrowserRoot onGetRoot(String clientPackage, int clientUid, Bundle hints) {
        return new BrowserRoot(ROOT, null);
    }

    @Override
    public void onLoadChildren(String parent, Result<List<MediaBrowser.MediaItem>> result) {
        List<MediaBrowser.MediaItem> items = new ArrayList<>();
        for (int i = 0; i < TRACKS.length; i++) {
            MediaDescription description = new MediaDescription.Builder()
                .setMediaId(String.valueOf(i)).setTitle(TRACKS[i][0]).setSubtitle(TRACKS[i][1]).build();
            items.add(new MediaBrowser.MediaItem(description, MediaBrowser.MediaItem.FLAG_PLAYABLE));
        }
        result.sendResult(items);
    }

    private void choose(int index) {
        track = index;
        frames = 0;
        describe();
    }

    private void play() {
        if (playing) {
            return;
        }
        if (focus == null) {
            focus = new AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                .setAudioAttributes(attributes())
                .setOnAudioFocusChangeListener(change -> { if (change < 0) pause(); })
                .build();
        }
        audio.requestAudioFocus(focus);
        playing = true;
        startForegroundService(new Intent(this, PlayerService.class));
        startForeground(1, notification(), ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK);
        tone = new Thread(this::sound, "tone");
        tone.start();
        describe();
    }

    private void pause() {
        if (!playing) {
            return;
        }
        playing = false;
        try {
            tone.join(1000);
        } catch (InterruptedException ignored) {
            Thread.currentThread().interrupt();
        }
        stopForeground(STOP_FOREGROUND_REMOVE);
        describe();
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int id) {
        return START_NOT_STICKY;
    }

    /** What the session says of itself: the track, and whether and where it is playing. */
    private void describe() {
        String[] now = TRACKS[track];
        session.setMetadata(new MediaMetadata.Builder()
            .putString(MediaMetadata.METADATA_KEY_MEDIA_ID, String.valueOf(track))
            .putString(MediaMetadata.METADATA_KEY_TITLE, now[0])
            .putString(MediaMetadata.METADATA_KEY_ARTIST, now[1])
            .putString(MediaMetadata.METADATA_KEY_ALBUM, now[2])
            .putLong(MediaMetadata.METADATA_KEY_DURATION, LENGTH_MS)
            .putLong(MediaMetadata.METADATA_KEY_TRACK_NUMBER, track + 1)
            .putLong(MediaMetadata.METADATA_KEY_NUM_TRACKS, TRACKS.length)
            .build());
        session.setPlaybackState(new PlaybackState.Builder()
            .setActions(PlaybackState.ACTION_PLAY | PlaybackState.ACTION_PAUSE | PlaybackState.ACTION_PLAY_PAUSE
                | PlaybackState.ACTION_STOP | PlaybackState.ACTION_SKIP_TO_NEXT
                | PlaybackState.ACTION_SKIP_TO_PREVIOUS | PlaybackState.ACTION_PLAY_FROM_MEDIA_ID)
            .setState(playing ? PlaybackState.STATE_PLAYING : PlaybackState.STATE_PAUSED,
                frames * 1000 / RATE, playing ? 1f : 0f, SystemClock.elapsedRealtime())
            .build());
    }

    /** The tone of the current track, until it is paused. A track that ends starts again. */
    private void sound() {
        int size = AudioTrack.getMinBufferSize(RATE, AudioFormat.CHANNEL_OUT_STEREO, AudioFormat.ENCODING_PCM_16BIT);
        AudioTrack out = new AudioTrack.Builder()
            .setAudioAttributes(attributes())
            .setAudioFormat(new AudioFormat.Builder().setSampleRate(RATE)
                .setChannelMask(AudioFormat.CHANNEL_OUT_STEREO).setEncoding(AudioFormat.ENCODING_PCM_16BIT).build())
            .setBufferSizeInBytes(size * 2)
            .build();
        out.play();
        short[] block = new short[2048];
        while (playing) {
            double pitch = Double.parseDouble(TRACKS[track][3]);
            for (int i = 0; i < block.length; i += 2) {
                short sample = (short) (6000 * Math.sin(2 * Math.PI * pitch * frames / RATE));
                block[i] = sample;
                block[i + 1] = sample;
                frames++;
            }
            out.write(block, 0, block.length);
            if (frames * 1000 / RATE >= LENGTH_MS) {
                frames = 0;
            }
        }
        out.pause();
        out.flush();
        out.release();
    }

    private static AudioAttributes attributes() {
        return new AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_MEDIA).setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build();
    }

    private Notification notification() {
        NotificationManager manager = getSystemService(NotificationManager.class);
        manager.createNotificationChannel(
            new NotificationChannel("playback", "Playback", NotificationManager.IMPORTANCE_LOW));
        return new Notification.Builder(this, "playback")
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentTitle(TRACKS[track][0])
            .setContentText(TRACKS[track][1])
            .setStyle(new Notification.MediaStyle().setMediaSession(session.getSessionToken()))
            .build();
    }
}
