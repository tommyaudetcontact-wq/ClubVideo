package com.godot.game;

import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.net.Uri;
import android.provider.Settings;

import androidx.core.content.FileProvider;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;

import java.io.File;

public final class ClubUpdatePlugin extends GodotPlugin {
    public ClubUpdatePlugin(Godot godot) {
        super(godot);
    }

    @Override
    public String getPluginName() {
        return "ClubUpdate";
    }

    @UsedByGodot
    public boolean canInstall() {
        Activity activity = getActivity();
        return activity != null && activity.getPackageManager().canRequestPackageInstalls();
    }

    @UsedByGodot
    public void requestInstallPermission() {
        Activity activity = getActivity();
        if (activity == null) return;
        activity.runOnUiThread(() -> {
            try {
                activity.startActivity(new Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                        Uri.parse("package:" + activity.getPackageName())));
            } catch (ActivityNotFoundException | SecurityException ex) {
                android.util.Log.w("ClubUpdate", "Installer permission screen unavailable", ex);
            }
        });
    }

    @UsedByGodot
    public boolean installApk() {
        Activity activity = getActivity();
        if (activity == null || !canInstall()) return false;
        File apk = new File(activity.getFilesDir(), "updates/verified.apk");
        if (!apk.isFile()) return false;
        Intent intent = new Intent(Intent.ACTION_VIEW);
        try {
            Uri uri = FileProvider.getUriForFile(activity, activity.getPackageName() + ".clubupdate", apk);
            intent.setDataAndType(uri, "application/vnd.android.package-archive");
            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
        } catch (IllegalArgumentException ex) {
            android.util.Log.w("ClubUpdate", "Update file cannot be shared", ex);
            return false;
        }
        activity.runOnUiThread(() -> {
            try {
                activity.startActivity(intent);
            } catch (ActivityNotFoundException | SecurityException ex) {
                android.util.Log.w("ClubUpdate", "System installer unavailable", ex);
            }
        });
        return true;
    }
}
