package com.godot.game;

import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.net.Uri;
import android.net.wifi.WifiManager;
import android.provider.Settings;

import androidx.core.content.FileProvider;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;

import java.io.File;
import java.net.InterfaceAddress;
import java.net.NetworkInterface;
import java.util.ArrayList;
import java.util.Enumeration;

public final class ClubUpdatePlugin extends GodotPlugin {
    public ClubUpdatePlugin(Godot godot) {
        super(godot);
    }

    @Override
    public String getPluginName() {
        return "ClubUpdate";
    }

    private WifiManager.MulticastLock discoveryLock;

    @UsedByGodot
    public void setDiscoveryEnabled(boolean enabled) {
        Activity activity = getActivity();
        if (activity == null) return;
        activity.runOnUiThread(() -> {
            try {
                if (!enabled) {
                    if (discoveryLock != null && discoveryLock.isHeld()) discoveryLock.release();
                    return;
                }
                if (discoveryLock == null) {
                    WifiManager manager = (WifiManager) activity.getApplicationContext().getSystemService(Activity.WIFI_SERVICE);
                    if (manager == null) return;
                    discoveryLock = manager.createMulticastLock("ClubVideoDiscovery");
                    discoveryLock.setReferenceCounted(false);
                }
                if (!discoveryLock.isHeld()) discoveryLock.acquire();
            } catch (SecurityException exception) {
                android.util.Log.w("ClubVideo", "Wi-Fi discovery lock unavailable", exception);
            }
        });
    }

    @UsedByGodot
    public String[] discoveryBroadcasts() {
        ArrayList<String> addresses = new ArrayList<>();
        try {
            Enumeration<NetworkInterface> interfaces = NetworkInterface.getNetworkInterfaces();
            while (interfaces != null && interfaces.hasMoreElements()) {
                NetworkInterface network = interfaces.nextElement();
                if (!network.isUp() || network.isLoopback() || network.isPointToPoint()) continue;
                for (InterfaceAddress address : network.getInterfaceAddresses()) {
                    if (address.getBroadcast() != null && address.getAddress().isSiteLocalAddress()) {
                        addresses.add(address.getBroadcast().getHostAddress());
                    }
                }
            }
        } catch (java.net.SocketException exception) {
            android.util.Log.w("ClubVideo", "Cannot enumerate Wi-Fi interfaces", exception);
        }
        return addresses.toArray(new String[0]);
    }

    @UsedByGodot
    public String[] discoveryProbeHosts() {
        ArrayList<String> hosts = new ArrayList<>();
        try {
            Enumeration<NetworkInterface> interfaces = NetworkInterface.getNetworkInterfaces();
            while (interfaces != null && interfaces.hasMoreElements()) {
                NetworkInterface network = interfaces.nextElement();
                if (!network.isUp() || network.isLoopback() || network.isPointToPoint()) continue;
                for (InterfaceAddress entry : network.getInterfaceAddresses()) {
                    byte[] bytes = entry.getAddress().getAddress();
                    if (bytes.length != 4 || entry.getBroadcast() == null || !entry.getAddress().isSiteLocalAddress()) continue;
                    int prefix = Math.max(24, entry.getNetworkPrefixLength());
                    if (prefix >= 31) continue;
                    int suffix = bytes[3] & 255;
                    int block = 1 << (32 - prefix);
                    int networkStart = suffix & ~(block - 1);
                    String base = (bytes[0] & 255) + "." + (bytes[1] & 255) + "." + (bytes[2] & 255) + ".";
                    for (int host = networkStart + 1; host < networkStart + block - 1; host++) {
                        if (host != suffix) hosts.add(base + host);
                        if (hosts.size() >= 508) return hosts.toArray(new String[0]);
                    }
                }
            }
        } catch (java.net.SocketException exception) {
            android.util.Log.w("ClubVideo", "Cannot find local peers", exception);
        }
        return hosts.toArray(new String[0]);
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
