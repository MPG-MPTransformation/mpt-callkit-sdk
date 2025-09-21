package com.mpt.mpt_callkit;

import android.Manifest;
import android.app.Activity;
import android.app.Fragment;
import android.app.FragmentTransaction;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.PackageManager;

import androidx.annotation.IdRes;
import androidx.annotation.Nullable;
import androidx.core.app.ActivityCompat;

import android.net.Uri;
import android.os.Build;
import android.os.Bundle;

import android.graphics.Color;

import android.os.PowerManager;
import android.widget.RadioGroup;
import android.widget.Toast;

import android.app.PictureInPictureParams;
import android.content.res.Configuration;
import android.util.Rational;
import android.app.RemoteAction;
import android.app.PendingIntent;
import android.graphics.drawable.Icon;
import java.util.ArrayList;

import com.mpt.mpt_callkit.receiver.PortMessageReceiver;
import com.mpt.mpt_callkit.PortSipService;

import com.mpt.mpt_callkit.util.CallManager;
import com.mpt.mpt_callkit.util.Engine;
import com.mpt.mpt_callkit.util.Ring;
import com.mpt.mpt_callkit.util.Session;
import com.portsip.PortSipSdk;

public class MainActivity extends Activity {

    public PortMessageReceiver receiver = null;
    public static MainActivity activity;
    private final int REQ_DANGERS_PERMISSION = 2;
    private boolean isReceiverRegistered = false;

    private boolean isInPictureInPictureMode = false;

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        activity = this;

        // Use Engine's receiver instead of creating a new one to ensure consistency
        receiver = Engine.Instance().getReceiver();
        if (receiver == null) {
            receiver = new PortMessageReceiver();
            Engine.Instance().setReceiver(receiver);
        }

        setContentView(R.layout.main);

        // Only register if not already registered to prevent multiple registrations
        if (!isReceiverRegistered && receiver != null) {
            IntentFilter filter = new IntentFilter();
            filter.addAction(PortSipService.REGISTER_CHANGE_ACTION);
            filter.addAction(PortSipService.CALL_CHANGE_ACTION);
            filter.addAction(PortSipService.PRESENCE_CHANGE_ACTION);
            filter.addAction(PortSipService.ACTION_SIP_AUDIODEVICE);
            filter.addAction(PortSipService.ACTION_HANGOUT_SUCCESS);
            System.out.println("SDK-Android: MainActivity - Registering broadcast receiver (using Engine's receiver)");

            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED);
                    System.out
                            .println(
                                    "SDK-Android: MainActivity - Registered receiver with RECEIVER_NOT_EXPORTED flag");
                } else {
                    registerReceiver(receiver, filter);
                    System.out.println("SDK-Android: MainActivity - Registered receiver without flag");
                }
                isReceiverRegistered = true;
            } catch (Exception e) {
                System.out.println("SDK-Android: MainActivity - Error registering receiver: " + e.getMessage());
                isReceiverRegistered = false;
            }
        } else {
            System.out.println("SDK-Android: MainActivity - Receiver already registered or is null");
        }

        // Add a MainActivity-specific listener for handling broadcasts
        // This will be automatically deduplicated by the new addListener logic
        // Use persistent listener to ensure it's never garbage collected
        receiver.addPersistentListener(new PortMessageReceiver.BroadcastListener() {
            @Override
            public void onBroadcastReceiver(Intent intent) {
                System.out.println("SDK-Android: MainActivity - Persistent backup listener handling broadcast");
                if (intent != null) {
                    String action = intent.getAction();
                    System.out.println("SDK-Android: MainActivity - Handling action: " + action);

                    // Handle specific actions that MainActivity should respond to
                    if (PortSipService.CALL_CHANGE_ACTION.equals(action)) {
                        // MainActivity can handle call state changes for global app behavior
                        System.out.println("SDK-Android: MainActivity - Handling call state change");
                    }
                }
            }
        }, "MainActivityBackup");
        System.out
                .println("SDK-Android: MainActivity - Added MainActivity persistent backup listener, listeners info: "
                        + receiver.getListenersInfo());

        Fragment fragment = getFragmentManager().findFragmentById(R.id.video_fragment);

        FragmentTransaction fTransaction = getFragmentManager().beginTransaction();
        if (fragment != null) {
            fTransaction.show(fragment).commit();
        }
    }

    @Override
    protected void onStart() {
        super.onStart();
        System.out.println("SDK-Android: MainActivity - onStart, isInPip: " + isInPictureInPictureMode);
    }

    @Override
    protected void onStop() {
        super.onStop();
        System.out.println("SDK-Android: MainActivity - onStop, isInPip: " + isInPictureInPictureMode);
        // Don't kill the app if we're going into PIP mode
        if (!isInPictureInPictureMode) {
            System.out.println("SDK-Android: MainActivity - onStop without PIP mode");
        }
    }

    @Override
    protected void onResume() {
        super.onResume();
        requestPermissions(this);
        System.out.println("SDK-Android: MainActivity - onResume");

        // Ensure receiver is still registered
        if (receiver != null && !isReceiverRegistered) {
            System.out.println("SDK-Android: MainActivity - Receiver lost in onResume, attempting to re-register");
            // Re-register if needed
            IntentFilter filter = new IntentFilter();
            filter.addAction(PortSipService.REGISTER_CHANGE_ACTION);
            filter.addAction(PortSipService.CALL_CHANGE_ACTION);
            filter.addAction(PortSipService.PRESENCE_CHANGE_ACTION);
            filter.addAction(PortSipService.ACTION_SIP_AUDIODEVICE);
            filter.addAction(PortSipService.ACTION_HANGOUT_SUCCESS);

            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED);
                } else {
                    registerReceiver(receiver, filter);
                }
                isReceiverRegistered = true;
                System.out.println("SDK-Android: MainActivity - Re-registered receiver in onResume");
            } catch (Exception e) {
                System.out
                        .println("SDK-Android: MainActivity - Error re-registering receiver in onResume: "
                                + e.getMessage());
            }
        }
    }

    @Override
    protected void onDestroy() {
        System.out.println("SDK-Android: MainActivity - onDestroy, current listeners: "
                + (receiver != null ? receiver.getListenersCount() : 0));

        if (receiver != null && isReceiverRegistered) {
            try {
                unregisterReceiver(receiver);
                isReceiverRegistered = false;
                System.out.println("SDK-Android: MainActivity - Unregistered receiver successfully");
            } catch (IllegalArgumentException e) {
                System.out.println("SDK-Android: MainActivity - Receiver was not registered: " + e.getMessage());
                isReceiverRegistered = false;
            } catch (Exception e) {
                System.out.println("SDK-Android: MainActivity - Error unregistering receiver: " + e.getMessage());
                isReceiverRegistered = false;
            }

            // Remove MainActivity-specific listener to prevent memory leaks
            if (receiver != null) {
                receiver.removePersistentListenerByTag("MainActivityBackup");
                System.out.println("SDK-Android: MainActivity - Removed persistent listener");
            }
        } else if (receiver == null) {
            System.out.println("SDK-Android: MainActivity - Receiver is null, nothing to unregister");
        } else {
            System.out.println("SDK-Android: MainActivity - Receiver was not registered by this activity");
        }

        super.onDestroy();
        System.out.println("SDK-Android: MainActivity - onDestroy completed");
    }

    // if you want app always keep run in background ,you need call this function to
    // request ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS permission.
    public void startPowerSavePermissions(Activity activityContext) {
        String packageName = activityContext.getPackageName();
        PowerManager pm = (PowerManager) activityContext.getSystemService(Context.POWER_SERVICE);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !pm.isIgnoringBatteryOptimizations(packageName)) {

            Intent intent = new Intent();
            intent.setAction(android.provider.Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS);
            intent.setData(Uri.parse("package:" + packageName));

            activityContext.startActivity(intent);
        }
    }

    @Override
    public void onRequestPermissionsResult(int requestCode,
            String permissions[], int[] grantResults) {
        switch (requestCode) {
            case REQ_DANGERS_PERMISSION:
                int i = 0;
                for (int result : grantResults) {
                    if (result != PackageManager.PERMISSION_GRANTED) {
                        Toast.makeText(this, "you must grant the permission " + permissions[i], Toast.LENGTH_SHORT)
                                .show();
                        i++;
                        stopService(new Intent(this, PortSipService.class));
                        System.exit(0);
                    }
                }
                break;
        }
    }

    boolean allowBack = false;

    public boolean isAllowBack() {
        return allowBack;
    }

    public void setAllowBack(boolean allowBack) {
        this.allowBack = allowBack;
    }

    @Override
    public void onBackPressed() {
        if (isAllowBack()) {
            super.onBackPressed();
        } else {
            // Only enter PIP if there's an active call
            VideoFragment videoFragment = (VideoFragment) getFragmentManager().findFragmentById(R.id.video_fragment);
            if (videoFragment != null && videoFragment.hasActiveCall()) {
                enterPictureInPictureMode();
            } else {
                super.onBackPressed();
            }
        }
    }

    @Override
    protected void onUserLeaveHint() {
        // Only enter PIP if there's an active call
        VideoFragment videoFragment = (VideoFragment) getFragmentManager().findFragmentById(R.id.video_fragment);
        if (videoFragment != null && videoFragment.hasActiveCall()) {
            enterPictureInPictureMode();
        }
        super.onUserLeaveHint();
    }

    @Override
    public void onPictureInPictureModeChanged(boolean isInPictureInPictureMode, Configuration newConfig) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig);
        this.isInPictureInPictureMode = isInPictureInPictureMode;

        System.out.println("SDK-Android: MainActivity - PIP mode changed: " + isInPictureInPictureMode);

        VideoFragment videoFragment = (VideoFragment) getFragmentManager().findFragmentById(R.id.video_fragment);
        if (videoFragment != null) {
            videoFragment.onPipModeChanged(isInPictureInPictureMode);

            // Handle when user exits PIP mode (closes PIP)
            if (!isInPictureInPictureMode) {
                System.out.println("SDK-Android: MainActivity - Exiting PIP mode");
                handlePipModeExit();
                Session currentLine = CallManager.Instance().getCurrentSession();
                if (currentLine != null) {
                    videoFragment.updateCameraView(currentLine.bMuteVideo);
                    videoFragment.updateMicView(currentLine.bMuteAudioOutGoing);
                }
            } else {
                System.out.println("SDK-Android: MainActivity - Entering PIP mode");
            }
        }
    }

    public void onHangUpCall(){
        VideoFragment videoFragment = (VideoFragment) getFragmentManager().findFragmentById(R.id.video_fragment);
        if (videoFragment != null) {
            videoFragment.onHangUpCall();
        }
    }

    // Handle when user exits PIP mode
    private void handlePipModeExit() {
        // VideoFragment videoFragment = (VideoFragment)
        // getFragmentManager().findFragmentById(R.id.video_fragment);
        // PortSipSdk portSipLib = Engine.Instance().getEngine();
        // Session currentLine = CallManager.Instance().getCurrentSession();

        // if (videoFragment != null && videoFragment.hasActiveCall()) {
        // hangup();
        // /// ve man hinh chinh
        // if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
        // activity.finishAndRemoveTask();
        // }
        // Toast.makeText(this, "Cuộc gọi đã kết thúc", Toast.LENGTH_SHORT).show();
        // }
    }

    public void enterPictureInPictureMode() {
        // Ensure service is running before entering PIP
        ensureServiceRunning();
        enterPictureInPictureMode(9, 16); // Default portrait mode
    }

    private void ensureServiceRunning() {
        try {
            // Start service to ensure it's running when entering PIP mode
            Intent serviceIntent = new Intent(this, PortSipService.class);
            serviceIntent.setAction(PortSipService.ACTION_KEEP_ALIVE);
            PortSipService.startServiceCompatibility(this, serviceIntent);
            System.out.println("SDK-Android: MainActivity - Ensured service is running for PIP mode");
        } catch (Exception e) {
            System.out.println("SDK-Android: MainActivity - Error ensuring service: " + e.getMessage());
        }
    }

    // Overloaded method to customize aspect ratio
    public void enterPictureInPictureMode(int width, int height) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // Check if there's an active call before entering PIP
            VideoFragment videoFragment = (VideoFragment) getFragmentManager().findFragmentById(R.id.video_fragment);
            if (videoFragment != null && videoFragment.hasActiveCall()) {
                // Create PIP parameters with custom aspect ratio only
                Rational aspectRatio = new Rational(width, height);

                PictureInPictureParams params = new PictureInPictureParams.Builder()
                        .setAspectRatio(aspectRatio)
                        .build();

                try {
                    enterPictureInPictureMode(params);
                } catch (IllegalStateException e) {
                    // PIP is not supported or activity is not in valid state
                    Toast.makeText(this, "PIP không được hỗ trợ", Toast.LENGTH_SHORT).show();
                }
            } else {
                Toast.makeText(this, "Không có cuộc gọi đang diễn ra", Toast.LENGTH_SHORT).show();
            }
        } else {
            Toast.makeText(this, "PIP yêu cầu Android 8.0 trở lên", Toast.LENGTH_SHORT).show();
        }
    }

    public boolean isInPipMode() {
        return isInPictureInPictureMode;
    }

    private void switchContent(@IdRes int fragmentId) {
        Fragment fragment = getFragmentManager().findFragmentById(fragmentId);
        Fragment video_fragment = getFragmentManager().findFragmentById(R.id.video_fragment);

        FragmentTransaction fTransaction = getFragmentManager().beginTransaction();
        if (fragment != null) {
            fTransaction.show(fragment).commit();
        }
    }

    public void requestPermissions(Activity activity) {
        // Check if we have write permission
        if (PackageManager.PERMISSION_GRANTED != ActivityCompat.checkSelfPermission(activity,
                Manifest.permission.CAMERA)
                || PackageManager.PERMISSION_GRANTED != ActivityCompat.checkSelfPermission(activity,
                        Manifest.permission.RECORD_AUDIO)) {
            ActivityCompat.requestPermissions(activity, new String[] {
                    Manifest.permission.CAMERA, Manifest.permission.RECORD_AUDIO },
                    REQ_DANGERS_PERMISSION);
        }
    }
}
