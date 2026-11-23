// SPDX-License-Identifier: Apache-2.0
package dev.jumpstarter.testplayer;

import android.app.Activity;
import android.content.ComponentName;
import android.media.MediaMetadata;
import android.media.browse.MediaBrowser;
import android.media.session.MediaController;
import android.media.session.PlaybackState;
import android.os.Bundle;
import android.view.Gravity;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;

/**
 * The player's one screen: what is playing, whether it is, and play, pause, next and previous.
 *
 * Everything on it has an accessibility id (its content description), which is how a test finds it: "Track title",
 * "Playback state", "Play", "Pause", "Next track", "Previous track".
 */
public class MainActivity extends Activity {
    private MediaBrowser browser;
    private MediaController controller;
    private TextView title;
    private TextView state;

    @Override
    protected void onCreate(Bundle saved) {
        super.onCreate(saved);
        LinearLayout page = new LinearLayout(this);
        page.setOrientation(LinearLayout.VERTICAL);
        page.setGravity(Gravity.CENTER);
        page.setPadding(48, 48, 48, 48);

        title = text("Track title", 26);
        state = text("Playback state", 18);
        page.addView(title);
        page.addView(state);
        page.addView(button("Play", () -> controller.getTransportControls().play()));
        page.addView(button("Pause", () -> controller.getTransportControls().pause()));
        page.addView(button("Next track", () -> controller.getTransportControls().skipToNext()));
        page.addView(button("Previous track", () -> controller.getTransportControls().skipToPrevious()));
        setContentView(page);

        browser = new MediaBrowser(this, new ComponentName(this, PlayerService.class),
            new MediaBrowser.ConnectionCallback() {
                @Override
                public void onConnected() {
                    controller = new MediaController(MainActivity.this, browser.getSessionToken());
                    controller.registerCallback(new MediaController.Callback() {
                        @Override public void onMetadataChanged(MediaMetadata metadata) { show(); }
                        @Override public void onPlaybackStateChanged(PlaybackState playback) { show(); }
                    });
                    show();
                }
            }, null);
        browser.connect();
    }

    @Override
    protected void onDestroy() {
        browser.disconnect();
        super.onDestroy();
    }

    private void show() {
        MediaMetadata metadata = controller.getMetadata();
        PlaybackState playback = controller.getPlaybackState();
        title.setText(metadata == null ? "" : metadata.getString(MediaMetadata.METADATA_KEY_TITLE));
        boolean playing = playback != null && playback.getState() == PlaybackState.STATE_PLAYING;
        state.setText(playing ? "Playing" : "Paused");
    }

    private TextView text(String description, float size) {
        TextView view = new TextView(this);
        view.setContentDescription(description);
        view.setTextSize(size);
        view.setGravity(Gravity.CENTER);
        return view;
    }

    private Button button(String label, Runnable action) {
        Button view = new Button(this);
        view.setText(label);
        view.setContentDescription(label);
        view.setOnClickListener(pressed -> { if (controller != null) action.run(); });
        return view;
    }
}
