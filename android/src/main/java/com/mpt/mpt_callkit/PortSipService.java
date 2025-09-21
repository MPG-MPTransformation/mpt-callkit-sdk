package com.mpt.mpt_callkit;

import android.app.ActivityManager;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.SharedPreferences;
import android.content.pm.ServiceInfo;
import android.graphics.drawable.Drawable;
import android.os.Build;
import android.os.IBinder;
import android.os.PowerManager;
import android.preference.PreferenceManager;
import android.text.TextUtils;
import android.util.Log;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.RequiresApi;
import androidx.core.app.NotificationCompat;

import com.portsip.OnPortSIPEvent;
import com.portsip.PortSipEnumDefine;
import com.portsip.PortSipErrorcode;
import com.portsip.PortSipSdk;
import com.mpt.mpt_callkit.util.CallManager;
import com.mpt.mpt_callkit.util.NetWorkReceiver;
import com.mpt.mpt_callkit.util.Session;
import com.mpt.mpt_callkit.util.ContactManager;
import com.mpt.mpt_callkit.util.Contact;
import com.mpt.mpt_callkit.util.Engine;
import com.mpt.mpt_callkit.util.Ring;
import com.mpt.mpt_callkit.util.ResourceMonitor;
import com.mpt.mpt_callkit.IncomingActivity;

import java.nio.charset.StandardCharsets;
import java.text.SimpleDateFormat;
import java.util.Arrays;
import java.util.Date;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Random;
import java.util.Set;
import java.util.UUID;

import com.mpt.mpt_callkit.MainActivity;
import com.mpt.mpt_callkit.receiver.PortMessageReceiver;

public class PortSipService extends Service
        implements OnPortSIPEvent, NetWorkReceiver.NetWorkListener, ResourceMonitor.ResourceCleanupListener {

    private static final SimpleDateFormat LOG_DATE_FORMAT = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS",
            Locale.getDefault());

    // Helper method để log với timestamp
    private static void logWithTimestamp(String message) {
        String timestamp = LOG_DATE_FORMAT.format(new Date());
        System.out.println("[" + timestamp + "] " + message);
    }

    private NetWorkReceiver mNetWorkReceiver;
    private NotificationManager mNotificationManager;
    private ResourceMonitor resourceMonitor;
    private String channelID = "PortSipService";
    private String callChannelID = "Call Channel";
    private static final int SERVICE_NOTIFICATION = 31414;
    public static final String TRANS = "trans type";
    public static final String SRTP = "srtp type";
    public static final String INSTANCE_ID = "instanceid";
    public static final String REGISTER_CHANGE_ACTION = "PortSip.AndroidSample.Test.RegisterStatusChagnge";
    public static final String CALL_CHANGE_ACTION = "PortSip.AndroidSample.Test.CallStatusChagnge";
    public static final String PRESENCE_CHANGE_ACTION = "PortSip.AndroidSample.Test.PRESENCEStatusChagnge";
    public static final String EXTRA_REGISTER_STATE = "RegisterStatus";
    public static final String ACTION_PUSH_MESSAGE = "PortSip.AndroidSample.Test.PushMessageIncoming";
    public static final String ACTION_PUSH_TOKEN = "PortSip.AndroidSample.Test.PushToken";
    public static final String ACTION_SIP_REGIEST = "PortSip.AndroidSample.Test.REGIEST";
    public static final String ACTION_SIP_UNREGIEST = "PortSip.AndroidSample.Test.UNREGIEST";
    public static final String ACTION_STOP = "PortSip.AndroidSample.Test.STOP";
    public static final String ACTION_KEEP_ALIVE = "PortSip.AndroidSample.Test.KEEP_ALIVE";
    public static final String EXTRA_CALL_DESCRIPTION = "Description";
    public static final String ACTION_SIP_AUDIODEVICE = "PortSip.AndroidSample.Test.AudioDeviceUpdate";
    public static final String EXTRA_CALL_SEESIONID = "SessionID";
    public static final int PENDINGCALL_NOTIFICATION = SERVICE_NOTIFICATION + 1;
    public static final String STUN_HOST = "stun host";
    public static final String STUN_PORT = "stun port";
    public static final String USER_NAME = "user name";
    public static final String USER_PWD = "user pwd";
    public static final String SVR_HOST = "svr host";
    public static final String SVR_PORT = "svr port";

    public static final String USER_DOMAIN = "user domain";
    public static final String USER_DISPALYNAME = "user dispalay";
    public static final String USER_AUTHNAME = "user authname";

    public static final String ACTION_HANGOUT_SUCCESS = "PortSip.AndroidSample.Test.ACTION_HANGOUT";
    public static final String HANGOUT_SUCCESS = "PortSip.AndroidSample.Test.HANGOUT_SUCCESS";

    public Context context;
    private String pushToken;
    private String appId;
    private boolean enableDebugLog;
    protected PowerManager.WakeLock mCpuLock;
    MainActivity mainActivity;
    private boolean isRemoteVideoReceived = false;

    private String getResourceFromContext(Context context, String resName) {
        final int stringRes = context.getResources().getIdentifier(resName, "string", context.getPackageName());
        if (stringRes == 0) {
            throw new IllegalArgumentException(String
                    .format("The 'R.string.%s' value it's not defined in your project's resources file.", resName));
        }
        return context.getString(stringRes);
    }

    private int getDrawableFromContext(Context context, String resName) {
        final int stringRes = context.getResources().getIdentifier(resName, "drawable", context.getPackageName());
        return stringRes;
    }

    public void keepCpuRun(boolean keepRun) {
        PowerManager powerManager = (PowerManager) getSystemService(POWER_SERVICE);
        if (keepRun == true) { // open
            if (mCpuLock == null) {
                if ((mCpuLock = powerManager.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK,
                        "SipSample:CpuLock.")) == null) {
                    return;
                }
                mCpuLock.setReferenceCounted(false);
            }

            synchronized (mCpuLock) {
                if (!mCpuLock.isHeld()) {
                    mCpuLock.acquire();
                }
            }
        } else {// close
            if (mCpuLock != null) {
                synchronized (mCpuLock) {
                    if (mCpuLock.isHeld()) {
                        mCpuLock.release();
                    }
                }
            }
        }
    }

    private void unregisterReceiver() {
        if (mNetWorkReceiver != null) {
            unregisterReceiver(mNetWorkReceiver);
        }
    }

    private boolean isForeground() {
        String[] activitys;
        if (Build.VERSION.SDK_INT > Build.VERSION_CODES.KITKAT_WATCH) {
            activitys = getActivePackages(this);
        } else {
            activitys = getActivePackagesCompat(this);
        }
        logWithTimestamp("SDK-Android: isForeground - Checking if app is in foreground");
        if (activitys.length > 0) {
            String packagename = getPackageName();
            // String processName= getProcessName();||activityname.contains(processName)
            for (String activityname : activitys) {
                logWithTimestamp("SDK-Android: isForeground - Active package: " + activityname);
                if (activityname.contains(packagename)) {
                    logWithTimestamp("SDK-Android: isForeground - App is in foreground");
                    return true;
                }
            }
            logWithTimestamp("SDK-Android: isForeground - App is NOT in foreground");
            return false;
        }
        logWithTimestamp("SDK-Android: isForeground - No active packages found");
        return false;
    }

    private void refreshPushToken() {
        if (!TextUtils.isEmpty(pushToken) && CallManager.Instance().isRegistered) {
            String pushMessage = "device-os=android;device-uid=" + pushToken
                    + ";allow-call-push=true;allow-message-push=true;app-id=" + appId;
            // old version
            // mEngine.addSipMessageHeader(-1, "REGISTER", 1, "portsip-push", pushMessage);
            // new version
            Engine.Instance().getEngine().addSipMessageHeader(-1, "REGISTER", 1, "X-Push", pushMessage);

            Engine.Instance().getEngine().refreshRegistration(0);

        }
    }

    private String[] getActivePackagesCompat(Context context) {
        ActivityManager mActivityManager = (ActivityManager) context.getSystemService(Context.ACTIVITY_SERVICE);
        final List<ActivityManager.RunningTaskInfo> taskInfo = mActivityManager.getRunningTasks(1);
        final ComponentName componentName = taskInfo.get(0).topActivity;
        final String[] activePackages = new String[1];
        activePackages[0] = componentName.getPackageName();
        return activePackages;
    }

    private String[] getActivePackages(Context context) {
        final Set<String> activePackages = new HashSet<String>();
        ActivityManager mActivityManager = (ActivityManager) context.getSystemService(Context.ACTIVITY_SERVICE);
        final List<ActivityManager.RunningAppProcessInfo> processInfos = mActivityManager.getRunningAppProcesses();
        for (ActivityManager.RunningAppProcessInfo processInfo : processInfos) {
            if (processInfo.importance == ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND) {
                activePackages.addAll(Arrays.asList(processInfo.pkgList));
            }
        }
        return activePackages.toArray(new String[activePackages.size()]);
    }

    @Override
    public void onCreate() {
        logWithTimestamp("SDK-Android: PortSipService onCreate");
        super.onCreate();
        context = getApplicationContext();

        mNotificationManager = (NotificationManager) getSystemService(NOTIFICATION_SERVICE);
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(channelID,
                    getResourceFromContext(context, "app_name"),
                    NotificationManager.IMPORTANCE_DEFAULT);
            channel.enableLights(true);
            NotificationChannel callChannel = new NotificationChannel(callChannelID,
                    getResourceFromContext(context, "app_name"),
                    NotificationManager.IMPORTANCE_HIGH);
            mNotificationManager.createNotificationChannel(channel);
            mNotificationManager.createNotificationChannel(callChannel);
        }

        // Initialize resource monitor
        resourceMonitor = ResourceMonitor.getInstance(this);
        resourceMonitor.addListener(this);
        resourceMonitor.startMonitoring();

        registerReceiver();
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        logWithTimestamp("SDK-Android: onDestroy called!");
        try {
            unregisterToServer();

            unregisterReceiver();

            // Stop resource monitoring
            if (resourceMonitor != null) {
                resourceMonitor.stopMonitoring();
                resourceMonitor.removeListener(this);
            }

            if (mCpuLock != null) {
                mCpuLock.release();
                mCpuLock = null;
            }

            if (mNotificationManager != null) {
                mNotificationManager.cancelAll();
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                    mNotificationManager.deleteNotificationChannel(channelID);
                    mNotificationManager.deleteNotificationChannel(callChannelID);
                }
                mNotificationManager = null;
            }

        } catch (Exception e) {
            logWithTimestamp("SDK-Android: Error during PortSipService cleanup: " + e.getMessage());
        }
    }

    @Override
    public void onResourceCleanupNeeded(int currentFDCount, String reason) {
        System.out
                .println("SDK-Android: Resource cleanup needed - FD count: " + currentFDCount + ", reason: " + reason);

        try {
            // Force garbage collection first
            if (resourceMonitor != null) {
                resourceMonitor.forceGarbageCollection();
            }

            // If critical, perform emergency cleanup
            if ("CRITICAL_FD_COUNT".equals(reason)) {
                logWithTimestamp("SDK-Android: Performing emergency cleanup due to critical FD count");

                // Close idle sessions
                PortSipSdk engine = Engine.Instance().getEngine();
                if (engine != null) {
                    for (int i = 0; i < CallManager.MAX_LINES; i++) {
                        Session session = CallManager.Instance().findSessionByIndex(i);
                        if (session != null && session.IsIdle() && session.sessionID != Session.INVALID_SESSION_ID) {
                            session.cleanupResources(engine);
                            session.Reset();
                        }
                    }
                }
            }
        } catch (Exception e) {
            logWithTimestamp("SDK-Android: Error during resource cleanup: " + e.getMessage());
        }
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        int result = super.onStartCommand(intent, flags, startId);
        if (intent != null) {
            logWithTimestamp("SDK-Android: onStartCommand, action: " + intent.getAction());
            String username = intent.getStringExtra("username");
            String password = intent.getStringExtra("password");
            String domain = intent.getStringExtra("domain");
            String sipServer = intent.getStringExtra("sipServer");
            String port = intent.getStringExtra("port");
            String displayName = intent.getStringExtra("displayName");
            pushToken = intent.getStringExtra("pushToken");
            appId = intent.getStringExtra("appId");
            enableDebugLog = intent.getBooleanExtra("enableDebugLog", false);
            String resolution = intent.getStringExtra("resolution");
            int bitrate = intent.getIntExtra("bitrate", 1024);
            int frameRate = intent.getIntExtra("frameRate", 30);
            if (ACTION_SIP_REGIEST.equals(intent.getAction())) {
                logWithTimestamp("SDK-Android: service is doing registerToServer, online: " + CallManager.Instance().online + ", isRegistered: " + CallManager.Instance().isRegistered);
                if(!CallManager.Instance().online){
                    initialSDK(enableDebugLog);
                }
                if(!CallManager.Instance().isRegistered){
                    registerToServer(username, password, domain, sipServer, port, displayName, appId, pushToken);
                } else {
                    MptCallkitPlugin.sendToFlutter("onlineStatus", true);
                    Engine.Instance().invokeMethod("registrationStateStream", true);
                    MptCallkitPlugin.sendToFlutter("registrationStateStream", true);
                }
            } else if (ACTION_SIP_UNREGIEST.equals(intent.getAction())) {
                logWithTimestamp("SDK-Android: service is doing unregisterToServer...");
                unregisterToServer();
                Engine.Instance().invokeMethod("releaseExtension", true);
                MptCallkitPlugin.sendToFlutter("releaseExtension", true);
                Engine.Instance().invokeMethod("registrationStateStream", false);
                MptCallkitPlugin.sendToFlutter("registrationStateStream", false);
                logWithTimestamp("SDK-Android: service unregisterToServer done");
                stopSelf();
                // return START_NOT_STICKY;
            } else if (ACTION_STOP.equals(intent.getAction())) {
                return START_NOT_STICKY;
            } else if (ACTION_KEEP_ALIVE.equals(intent.getAction())) {
                logWithTimestamp("SDK-Android: service received KEEP_ALIVE action for PIP mode");
                // Ensure service stays alive for PIP mode
                if (!CallManager.Instance().online) {
                    initialSDK(enableDebugLog);
                }
                showServiceNotifiCation();
                keepCpuRun(true);
                return START_STICKY;
            }
        }
        return result;
    }

    public void registerToServer(
            String userName,
            String password,
            String userDomain,
            String sipServer,
            String serverPort,
            String displayName,
            String appId,
            String pushToken) {
        SharedPreferences preferences = PreferenceManager.getDefaultSharedPreferences(this);
        int srtpType = preferences.getInt(SRTP, 0);
        String authName = "";
        String stunServer = "";
        String stunPort = "3478";

        logWithTimestamp("SDK-Android: registerToServer called");
        logWithTimestamp("SDK-Android: Parameters - userName: " + userName + ", sipServer: " + sipServer + ", serverPort: " + serverPort);
        
        // Validate and provide default values for ports
        if (TextUtils.isEmpty(serverPort)) {
            logWithTimestamp("SDK-Android: serverPort is null or empty, using default port 5060");
            serverPort = "5060"; // Default SIP port
        }
        
        int sipServerPort = Integer.parseInt(serverPort);
        int stunServerPort = Integer.parseInt(stunPort);

        if (TextUtils.isEmpty(userName)) {
            showTipMessage("Please enter user name!");
            logWithTimestamp("SDK-Android: Registration failed - userName is empty");
            return;
        }

        if (TextUtils.isEmpty(password)) {
            showTipMessage("Please enter password!");
            logWithTimestamp("SDK-Android: Registration failed - password is empty");
            return;
        }
        
        if (TextUtils.isEmpty(sipServer)) {
            showTipMessage("Please enter SIP server!");
            logWithTimestamp("SDK-Android: Registration failed - sipServer is empty");
            return;
        }


        Engine.Instance().getEngine().removeUser();
        int result = Engine.Instance().getEngine().setUser(userName, displayName, authName, password,
                userDomain, sipServer, sipServerPort, stunServer, stunServerPort, null, 5063);

        if (result != PortSipErrorcode.ECoreErrorNone) {
            showTipMessage("setUser failure ErrorCode = " + result);
            CallManager.Instance().resetAll();
            return;
        }

        Engine.Instance().getEngine().enableAudioManager(true);
        Engine.Instance().getEngine().setAudioDevice(PortSipEnumDefine.AudioDevice.SPEAKER_PHONE);
        Engine.Instance().getEngine().setVideoDeviceId(1);

        Engine.Instance().getEngine().setSrtpPolicy(srtpType);
        ConfigPreferences(this, Engine.Instance().getEngine());

        Engine.Instance().getEngine().enable3GppTags(false);

        if (!TextUtils.isEmpty(pushToken) && !TextUtils.isEmpty(appId)) {
            String pushMessage = "device-os=android;device-uid=" + pushToken
                    + ";allow-call-push=true;allow-message-push=true;app-id=" + appId;
            // Engine.Instance().getEngine().addSipMessageHeader(-1, "REGISTER", 1,
            // "portsip-push", pushMessage);
            // new version
            Engine.Instance().getEngine().addSipMessageHeader(-1, "REGISTER", 1, "X-Push", pushMessage);
            logWithTimestamp("SDK-Android: registerToServer - pushToken or appId not empty" + pushMessage);

        } else {
            logWithTimestamp("SDK-Android: registerToServer - pushToken or appId is empty");
        }

        result = Engine.Instance().getEngine().registerServer(90, 0);

        logWithTimestamp("SDK-Android: registerServer - register result: " + result);

        if (result != PortSipErrorcode.ECoreErrorNone) {
            showTipMessage("registerServer failure ErrorCode =" + result);
            logWithTimestamp("SDK-Android: registerServer failure ErrorCode =" + result);
            Engine.Instance().getEngine().unRegisterServer(100);
            CallManager.Instance().resetAll();
        }

    }

    public void unregisterToServer() {
        logWithTimestamp("SDK-Android: unregisterToServer");
        // if (CallManager.Instance().online) {
            try {
                PortSipSdk engine = Engine.Instance().getEngine();
                if (engine != null) {
                    // Hang up all active calls first
                    // CallManager.Instance().hangupAllCalls(engine);

                    // Wait a bit for hangup to complete
                    // Thread.sleep(200);

                    // Then cleanup
                    // engine.destroyConference();
                    int result = engine.unRegisterServer(100);
                    logWithTimestamp("SDK-Android: unRegisterServer done: " + result);
                    
                    engine.removeUser();
                    engine.unInitialize();
                    Thread.sleep(200);
                    logWithTimestamp("SDK-Android: unInitialize done");
                }

                CallManager.Instance().resetAll();
                CallManager.Instance().online = false;
                CallManager.Instance().isRegistered = false;
                CallManager.Instance().answeredWithCallKit = false;
                CallManager.Instance().socketReady = false;

                if (Engine.Instance() != null) {
                    Engine.Instance().invokeMethod("onlineStatus", false);
                    MptCallkitPlugin.sendToFlutter("onlineStatus", false);
                }

            } catch (Exception e) {
                logWithTimestamp("SDK-Android: Error during unregisterToServer: " + e.getMessage());
            }
        // }
    }

    private void registerReceiver() {
        IntentFilter filter = new IntentFilter();
        filter.addAction("android.net.conn.CONNECTIVITY_CHANGE");
        mNetWorkReceiver = new NetWorkReceiver();
        mNetWorkReceiver.setListener(this);

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(mNetWorkReceiver, filter, Context.RECEIVER_NOT_EXPORTED);
        } else {
            registerReceiver(mNetWorkReceiver, filter);
        }
    }

    private void showServiceNotifiCation() {
        Intent intent = new Intent(this, MainActivity.class);
        intent.setFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP | Intent.FLAG_ACTIVITY_NEW_TASK);
        PendingIntent contentIntent = PendingIntent.getActivity(this, 0, intent, PendingIntent.FLAG_IMMUTABLE);

        Notification.Builder builder;
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            builder = new Notification.Builder(this, channelID);
        } else {
            builder = new Notification.Builder(this);
        }
        builder.setSmallIcon(getDrawableFromContext(context, "icon"))
                .setContentTitle(getResourceFromContext(context, "app_name"))
                .setContentText("Service Running")
                // .setContentIntent(contentIntent)
                .build();// getNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(SERVICE_NOTIFICATION, builder.build(), ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
                    | ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA
                    | ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK);
        } else {
            startForeground(SERVICE_NOTIFICATION, builder.build());
        }
    }

    private int initialSDK(boolean enableDebugLog) {
        if (Engine.Instance().getEngine() == null && MptCallkitPlugin.shared.context != null) {
            Engine.Instance().setEngine(new PortSipSdk(MptCallkitPlugin.shared.context));
            // Only create receiver if it doesn't exist
            if (Engine.Instance().getReceiver() == null) {
                Engine.Instance().setReceiver(new PortMessageReceiver());
            }
        }
        Engine.Instance().getEngine().setOnPortSIPEvent(this);
        CallManager.Instance().online = true;
        logWithTimestamp("SDK-Android: initialSDK - enableDebugLog: " + enableDebugLog);

        String dataPath = getExternalFilesDir(null).getAbsolutePath();
        String certRoot = dataPath + "/certs";
        SharedPreferences preferences = PreferenceManager.getDefaultSharedPreferences(this);
        Random rm = new Random();
        int localPort = 5063 + rm.nextInt(60000);
        // int transType = preferences.getInt(TRANS, 0);
        int transType = 2;

        // Reduce max lines to minimize resource usage
        int maxLines = 4; // Reduced from default 8

        int result = Engine.Instance().getEngine().initialize(getTransType(transType), "0.0.0.0", localPort,
                enableDebugLog ? PortSipEnumDefine.ENUM_LOG_LEVEL_DEBUG : PortSipEnumDefine.ENUM_LOG_LEVEL_ERROR,
                dataPath, // Changed to ERROR level to reduce logging overhead
                maxLines, "PortSIP SDK for Android", 0, 0, certRoot, "", false, null);

        if (result != PortSipErrorcode.ECoreErrorNone) {
            showTipMessage("initialize failure ErrorCode = " + result);
            CallManager.Instance().resetAll();
        } else {
            // Apply video settings from preferences (preferences already initialized above)
            String resolution = preferences.getString("resolution", "720P");
            int bitrate = preferences.getInt("bitrate", 1024);
            int frameRate = preferences.getInt("frameRate", 30);

            int width = 1280;
            int height = 720;
            if ("QCIF".equals(resolution)) {
                width = 176; height = 144;
            } else if ("CIF".equals(resolution)) {
                width = 352; height = 288;
            } else if ("VGA".equals(resolution)) {
                width = 640; height = 480;
            } else if ("720P".equals(resolution)) {
                width = 1280; height = 720;
            } else if ("1080P".equals(resolution)) {
                width = 1920; height = 1080;
            }

            Engine.Instance().getEngine().setVideoResolution(width, height);
            Engine.Instance().getEngine().setVideoBitrate(-1, bitrate);
            Engine.Instance().getEngine().setVideoFrameRate(-1, frameRate);

            result = Engine.Instance().getEngine().setLicenseKey("LicenseKey");
            if (result == PortSipErrorcode.ECoreWrongLicenseKey) {
                showTipMessage(
                        "The wrong license key was detected, please check with sales@portsip.com or support@portsip.com");
            } else if (result == PortSipErrorcode.ECoreTrialVersionLicenseKey) {
                Log.w("Trial Version",
                        "This trial version SDK just allows short conversation, you can't hearing anything after 2-3 minutes, contact us: sales@portsip.com to buy official version.");
                showTipMessage("This Is Trial Version");
                Engine.Instance().getEngine().setInstanceId(getInstanceID());
            }
        }
        return result;
    }

    private int getTransType(int select) {
        switch (select) {
            case 0:
                return PortSipEnumDefine.ENUM_TRANSPORT_UDP;
            case 1:
                return PortSipEnumDefine.ENUM_TRANSPORT_TLS;
            case 2:
                return PortSipEnumDefine.ENUM_TRANSPORT_TCP;
        }
        return PortSipEnumDefine.ENUM_TRANSPORT_UDP;
    }

    String getInstanceID() {
        SharedPreferences preferences = PreferenceManager.getDefaultSharedPreferences(this);

        String insanceid = preferences.getString(INSTANCE_ID, "");
        if (TextUtils.isEmpty(insanceid)) {
            insanceid = UUID.randomUUID().toString();
            preferences.edit().putString(INSTANCE_ID, insanceid).commit();
        }
        return insanceid;
    }

    private void showTipMessage(String tipMessage) {
        Intent broadIntent = new Intent(REGISTER_CHANGE_ACTION);
        broadIntent.putExtra(EXTRA_REGISTER_STATE, tipMessage);
        sendPortSipMessage(tipMessage, broadIntent);
    }

    @Nullable
    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    @Override
    public void onRegisterSuccess(String statusText, int statusCode, String sipMessage) {
        logWithTimestamp("SDK-Android: onRegisterSuccess - statusText: " + statusText + " - statusCode: "+ statusCode + " - sipMessage: "+ sipMessage);
        CallManager.Instance().isRegistered = true;
        Engine.Instance().invokeMethod("onlineStatus", true);
        MptCallkitPlugin.sendToFlutter("onlineStatus", true);
        Intent broadIntent = new Intent(REGISTER_CHANGE_ACTION);
        broadIntent.putExtra(EXTRA_REGISTER_STATE, statusText);
        sendPortSipMessage("onRegisterSuccess", broadIntent);
        keepCpuRun(true);
        Engine.Instance().invokeMethod("registrationStateStream", true);
        MptCallkitPlugin.sendToFlutter("registrationStateStream", true);
    }

    @Override
    public void onRegisterFailure(String statusText, int statusCode, String sipMessage) {
        logWithTimestamp("SDK-Android: onRegisterFailure " + statusText + " - " + statusCode + " - " + sipMessage);
        Engine.Instance().invokeMethod("onlineStatus", false);
        MptCallkitPlugin.sendToFlutter("onlineStatus", false);
        Intent broadIntent = new Intent(REGISTER_CHANGE_ACTION);
        broadIntent.putExtra(EXTRA_REGISTER_STATE, statusText);
        sendPortSipMessage("onRegisterFailure" + statusCode, broadIntent);
        CallManager.Instance().resetAll();
        Engine.Instance().invokeMethod("registrationStateStream", false);
        MptCallkitPlugin.sendToFlutter("registrationStateStream", false);

        keepCpuRun(false);
    }

    @Override
    public void onInviteIncoming(long sessionId,
            String callerDisplayName,
            String caller,
            String calleeDisplayName,
            String callee,
            String audioCodecNames,
            String videoCodecNames,
            boolean existsAudio,
            boolean existsVideo,
            String sipMessage) {

        logWithTimestamp("SDK-Android: onInviteIncoming - "
                + "sessionId: " + sessionId
                + ", callerDisplayName: " + callerDisplayName
                + ", caller: " + caller
                + ", calleeDisplayName: " + calleeDisplayName
                + ", callee: " + callee
                + ", audioCodecNames: " + audioCodecNames
                + ", videoCodecNames: " + videoCodecNames
                + ", existsAudio: " + existsAudio
                + ", existsVideo: " + existsVideo
                + ", sipMessage: " + sipMessage);

        // if (CallManager.Instance().findIncomingCall() != null) {
        //     Engine.Instance().getEngine().rejectCall(sessionId, 486); // busy
        //     logWithTimestamp("SDK-Android: Rejected call - already in a call");
        //     return;
        // }
        Session session = CallManager.Instance().findIdleSession();
        session.state = Session.CALL_STATE_FLAG.INCOMING;
        session.sessionID = sessionId;
        session.remote = caller;
        session.displayName = callerDisplayName;

        // Lưu trữ sipMessage
        session.setSipMessage(sipMessage);

        Intent broadIntent = new Intent(CALL_CHANGE_ACTION);
        String description = session.lineName + " onInviteIncoming";

        broadIntent.putExtra(EXTRA_CALL_SEESIONID, sessionId);
        broadIntent.putExtra(EXTRA_CALL_DESCRIPTION, description);

        sendPortSipMessage(description, broadIntent);

        Ring.getInstance(this).startRingTone();

        // Gửi thông tin cuộc gọi đến đến Flutter
        sendCallStateToFlutter("INCOMING");

        // Gửi thêm thông tin chi tiết về người gọi
        if (Engine.Instance() != null) {
            try {
                // Tạo đối tượng chứa thông tin cuộc gọi để gửi về Flutter
                java.util.Map<String, Object> callInfo = new java.util.HashMap<>();
                callInfo.put("sessionId", sessionId);
                callInfo.put("callerName", callerDisplayName);
                callInfo.put("callerNumber", caller);
                callInfo.put("hasVideo", existsVideo);

                Engine.Instance().invokeMethod("incomingCall", callInfo);
                MptCallkitPlugin.sendToFlutter("incomingCall", callInfo);
            } catch (Exception e) {
                logWithTimestamp("SDK-Android: Error sending call info to Flutter: " + e.getMessage());
            }
        }

        // Lưu thông tin về video capability
        session.hasVideo = existsVideo;

        // Answer call
        if (Engine.Instance().getEngine().getSipMessageHeaderValue(sipMessage, "Answer-Mode").toString()
                .equals("Auto;require")) {
            logWithTimestamp("SDK-Android: Auto answering call with video preference: " + existsVideo);
            Ring.getInstance(this).stopRingTone();
            // Ring.getInstance(this).startRingBackTone();
            // Answer với video status hiện tại (có thể là false)
            int result = MptCallkitPlugin.answerCall(true);
            logWithTimestamp("SDK-Android: onInviteIncoming - On auto answer call");
            sendCallTypeToFlutter("OUTGOING_CALL");
            if (result == 0) {
                // sendCallStateToFlutter("ANSWERED");
                logWithTimestamp("SDK-Android: onInviteIncoming - auto answer call success");
            } else {
                logWithTimestamp("SDK-Android: auto answer call failed with code: " + result);
            }
        } else {
            logWithTimestamp("SDK-Android: onInviteIncoming - On not auto answer call");
            sendCallTypeToFlutter("INCOMING_CALL");
        }

        // Lấy X-Session-Id từ sipMessage
        String messageSesssionId = Engine.Instance().getEngine()
                .getSipMessageHeaderValue(CallManager.Instance().getCurrentSession().sipMessage, "X-Session-Id")
                .toString();

        Engine.Instance().invokeMethod("curr_sessionId", messageSesssionId);

        MptCallkitPlugin.sendToFlutter("curr_sessionId", messageSesssionId);
        MptCallkitPlugin.sendToFlutter("isRemoteVideoReceived", false);
        isRemoteVideoReceived = false;

        logWithTimestamp("SDK-Android: onInviteIncoming X-Session-Id = " + messageSesssionId);
        // sendCallStateToFlutter("IN_CONFERENCE");

        // Set<PortSipEnumDefine.AudioDevice> availableDevices = Engine.Instance().getEngine().getAudioDevices();
        // logWithTimestamp("SDK-Android: onInviteIncoming - allDevices: " + availableDevices.toString());
        // if (availableDevices.contains(PortSipEnumDefine.AudioDevice.BLUETOOTH)) {
        //     Engine.Instance().getEngine().setAudioDevice(PortSipEnumDefine.AudioDevice.BLUETOOTH);
        //     Engine.Instance().invokeMethod("currentAudioDevice",
        //             PortSipEnumDefine.AudioDevice.BLUETOOTH.toString());
        //     MptCallkitPlugin.sendToFlutter("currentAudioDevice", PortSipEnumDefine.AudioDevice.BLUETOOTH.toString());
        // } else {
        //     Engine.Instance().getEngine().setAudioDevice(PortSipEnumDefine.AudioDevice.SPEAKER_PHONE);
        //     Engine.Instance().invokeMethod("currentAudioDevice",
        //             PortSipEnumDefine.AudioDevice.SPEAKER_PHONE.toString());
        //     MptCallkitPlugin.sendToFlutter("currentAudioDevice",
        //             PortSipEnumDefine.AudioDevice.SPEAKER_PHONE.toString());
        // }
    }

    public void showPendingCallNotification(Context context, String contenTitle, String contenText, Intent intent) {
        logWithTimestamp("SDK-Android: showPendingCallNotification - Creating notification for incoming call");
        logWithTimestamp("SDK-Android: showPendingCallNotification - contenTitle: " + contenTitle);
        logWithTimestamp("SDK-Android: showPendingCallNotification - contenText: " + contenText);

        // Đảm bảo intent không bị clear khi nhiều notification được tạo
        intent.setAction("INCOMING_CALL_" + System.currentTimeMillis());

        // Quan trọng: thêm flag để mở activity từ notification
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK
                | Intent.FLAG_ACTIVITY_CLEAR_TOP
                | Intent.FLAG_ACTIVITY_SINGLE_TOP);

        // Sử dụng flag FLAG_UPDATE_CURRENT để cập nhật PendingIntent nếu đã tồn tại
        PendingIntent contentIntent = PendingIntent.getActivity(
                context,
                (int) System.currentTimeMillis(),
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);

        NotificationCompat.Builder builder = new NotificationCompat.Builder(context, callChannelID)
                .setSmallIcon(R.drawable.icon)
                .setContentTitle(contenTitle)
                .setContentText(contenText)
                .setAutoCancel(true)
                .setShowWhen(true)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setCategory(NotificationCompat.CATEGORY_CALL)
                .setContentIntent(contentIntent)
                .setFullScreenIntent(contentIntent, true);

        logWithTimestamp(
                "SDK-Android: showPendingCallNotification - Displaying notification with ID: "
                        + PENDINGCALL_NOTIFICATION);
        mNotificationManager.notify(PENDINGCALL_NOTIFICATION, builder.build());

        // Thử mở trực tiếp activity nếu notification không hoạt động
        try {
            context.startActivity(intent);
            logWithTimestamp("SDK-Android: showPendingCallNotification - Started IncomingActivity directly");
        } catch (Exception e) {
            System.out
                    .println("SDK-Android: showPendingCallNotification - Failed to start activity: " + e.getMessage());
        }
    }

    @Override
    public void onInviteTrying(long l) {
        sendCallStateToFlutter("TRYING");
    }

    @Override
    public void onRecvMessage(long sessionId,
            String mimeType,
            String subMimeType,
            byte[] messageData,
            int messageDataLength) {
        logWithTimestamp("SDK-Android: onRecvMessage");

        String str = new String(messageData, StandardCharsets.UTF_8);
        logWithTimestamp("SDK-Android: onRecvMessage - "
                + "sessionId: " + sessionId
                + ", mimeType: " + mimeType
                + ", subMimeType: " + subMimeType
                + ", messageData: " + str
                + ", messageDataLength: " + messageDataLength);

        MptCallkitPlugin.sendToFlutter("recvCallMessage", str);
    }

    @Override
    public void onInviteSessionProgress(
            long sessionId,
            String audioCodecNames,
            String videoCodecNames,
            boolean existsEarlyMedia,
            boolean existsAudio,
            boolean existsVideo,
            String sipMessage) {
        Session session = CallManager.Instance().findSessionBySessionID(sessionId);

        if (session != null) {
            session.bEarlyMedia = existsEarlyMedia;
        }
    }

    @Override
    public void onInviteRinging(long sessionId, String statusText, int statusCode, String sipMessage) {
        Session session = CallManager.Instance().findSessionBySessionID(sessionId);

        if (session != null && !session.bEarlyMedia) {
            Ring.getInstance(this).startRingBackTone();
        }
    }

    @Override
    public void onInviteAnswered(long sessionId,
            String callerDisplayName,
            String caller,
            String calleeDisplayName,
            String callee,
            String audioCodecNames,
            String videoCodecNames,
            boolean existsAudio,
            boolean existsVideo,
            String sipMessage) {
        logWithTimestamp("SDK-Android: onInviteAnswered");
        Session session = CallManager.Instance().findSessionBySessionID(sessionId);

        if (session != null) {
            session.state = Session.CALL_STATE_FLAG.CONNECTED;
            // session.hasVideo = existsVideo;

            Intent broadIntent = new Intent(CALL_CHANGE_ACTION);
            broadIntent.putExtra(EXTRA_CALL_SEESIONID, sessionId);

            String description = session.lineName + " onInviteAnswered";
            broadIntent.putExtra(EXTRA_CALL_DESCRIPTION, description);

            sendPortSipMessage(description, broadIntent);
        }

        Ring.getInstance(this).stopRingBackTone();
    }

    @Override
    public void onInviteFailure(long sessionId, String callerDisplayName,
            String caller,
            String calleeDisplayName,
            String callee,
            String reason,
            int code,
            String sipMessage) {
        logWithTimestamp("SDK-Android: onInviteFailure");
        Session session = CallManager.Instance().findSessionBySessionID(sessionId);

        if (session != null) {
            session.state = Session.CALL_STATE_FLAG.FAILED;
            session.sessionID = sessionId;

            Intent broadIntent = new Intent(CALL_CHANGE_ACTION);
            broadIntent.putExtra(EXTRA_CALL_SEESIONID, sessionId);
            String description = session.lineName + " onInviteFailure";
            broadIntent.putExtra(EXTRA_CALL_DESCRIPTION, description);

            sendPortSipMessage(description, broadIntent);
        }

        Ring.getInstance(this).stopRingBackTone();
        sendCallStateToFlutter("FAILED");
        sendCallTypeToFlutter("ENDED");
        MptCallkitPlugin.sendToFlutter("isRemoteVideoReceived", false);
        isRemoteVideoReceived = false;
    }

    @Override
    public void onInviteUpdated(long sessionId, String audioCodecs, String videoCodecs, String screenCodecs,
            boolean existsAudio, boolean existsVideo, boolean existsScreen, String sipMessage) {
        logWithTimestamp("SDK-Android: onInviteUpdated - "
                + "sessionId: " + sessionId
                + ", audioCodecs: " + audioCodecs
                + ", videoCodecs: " + videoCodecs
                + ", screenCodecs: " + screenCodecs
                + ", existsAudio: " + existsAudio
                + ", existsVideo: " + existsVideo
                + ", existsScreen: " + existsScreen
                + ", sipMessage: " + sipMessage);

        Session session = CallManager.Instance().findSessionBySessionID(sessionId);

        if (session != null) {

            if (existsVideo) {
                // for receive video stream
                Engine.Instance().getEngine().enableVideoStreamCallback(sessionId,
                        PortSipEnumDefine.ENUM_DIRECTION_RECV);
                int result = Engine.Instance().getEngine().enableSendVideoStreamToRemote(sessionId, true);
                System.out.println("SDK-Android: enableSendVideoStream result: " + result);
                MptCallkitPlugin.shared.startCameraSource();
            }

            if (session.hasVideo && !existsVideo && videoCodecs.isEmpty()) {
                // Gửi video từ camera
                int sendVideoRes = Engine.Instance().getEngine().sendVideo(session.sessionID, true);
                logWithTimestamp("SDK-Android: onInviteUpdated - re-sendVideo(): " + sendVideoRes);

                // Cập nhật cuộc gọi để thêm video stream
                int updateRes = Engine.Instance().getEngine().updateCall(session.sessionID, true, true);
                logWithTimestamp("SDK-Android: onInviteUpdated - re-updateCall(): " + updateRes);
            }

            session.state = Session.CALL_STATE_FLAG.CONNECTED;
            session.hasVideo = existsVideo;
            logWithTimestamp("SDK-Android: onInviteUpdated - existsVideo: " + existsVideo);
            session.bScreenShare = existsScreen;

            Intent broadIntent = new Intent(CALL_CHANGE_ACTION);
            broadIntent.putExtra(EXTRA_CALL_SEESIONID, sessionId);
            String description = session.lineName + " OnInviteUpdated";
            broadIntent.putExtra(EXTRA_CALL_DESCRIPTION, description);

            sendPortSipMessage(description, broadIntent);

            // // Cập nhật cuộc gọi để thêm video stream
            // int result = Engine.Instance().getEngine().updateCall(sessionId, true, true);
            // logWithTimestamp("SDK-Android: onInviteUpdated - updateCall(): " + result);
        }

        // Nếu video codecs là rỗng, có thể đó là lý do existsVideo = false
        if (videoCodecs == null || videoCodecs.isEmpty()) {
            // logWithTimestamp("SDK-Android: No video codecs available in updated
            // session");
        }
    }

    @Override
    public void onInviteConnected(long sessionId) {
        logWithTimestamp("SDK-Android: onInviteConnected");
        Session session = CallManager.Instance().findSessionBySessionID(sessionId);
        if (session != null) {
            session.state = Session.CALL_STATE_FLAG.CONNECTED;
            session.sessionID = sessionId;

            if (/* applicaton.mConference */true) {
                Engine.Instance().getEngine().joinToConference(session.sessionID);
                Engine.Instance().getEngine().sendVideo(session.sessionID, true);
            }

            Intent broadIntent = new Intent(CALL_CHANGE_ACTION);
            broadIntent.putExtra(EXTRA_CALL_SEESIONID, sessionId);
            String description = session.lineName + " OnInviteConnected";
            broadIntent.putExtra(EXTRA_CALL_DESCRIPTION, description);

            sendPortSipMessage(description, broadIntent);
        }

        // Set<PortSipEnumDefine.AudioDevice> availableDevices = Engine.Instance().getEngine().getAudioDevices();
        // logWithTimestamp("SDK-Android: onInviteIncoming - allDevices: " + availableDevices.toString());
        // if (availableDevices.contains(PortSipEnumDefine.AudioDevice.BLUETOOTH)) {
        //     Engine.Instance().getEngine().setAudioDevice(PortSipEnumDefine.AudioDevice.BLUETOOTH);
        //     Engine.Instance().invokeMethod("currentAudioDevice",
        //             PortSipEnumDefine.AudioDevice.BLUETOOTH.toString());
        //     MptCallkitPlugin.sendToFlutter("currentAudioDevice", PortSipEnumDefine.AudioDevice.BLUETOOTH.toString());
        // } else {
        //     Engine.Instance().getEngine().setAudioDevice(PortSipEnumDefine.AudioDevice.SPEAKER_PHONE);
        //     Engine.Instance().invokeMethod("currentAudioDevice",
        //             PortSipEnumDefine.AudioDevice.SPEAKER_PHONE.toString());
        //     MptCallkitPlugin.sendToFlutter("currentAudioDevice",
        //             PortSipEnumDefine.AudioDevice.SPEAKER_PHONE.toString());
        // }
        
        sendCallStateToFlutter("CONNECTED");
    }

    @Override
    public void onInviteBeginingForward(String s) {
    }

    @Override
    public void onInviteClosed(long sessionId, String sipMessage) {
        logWithTimestamp("SDK-Android: onInviteClosed");
        MptCallkitPlugin.shared.stopCameraSource();
        Session session = CallManager.Instance().findSessionBySessionID(sessionId);
        if (session != null) {
            session.state = Session.CALL_STATE_FLAG.CLOSED;
            session.sessionID = sessionId;

            Intent broadIntent = new Intent(CALL_CHANGE_ACTION);
            broadIntent.putExtra(EXTRA_CALL_SEESIONID, sessionId);
            String description = session.lineName + " OnInviteClosed";
            broadIntent.putExtra(EXTRA_CALL_DESCRIPTION, description);

            sendPortSipMessage(description, broadIntent);
        }
        Ring.getInstance(this).stopRingTone();
        if (mNotificationManager != null) {
            mNotificationManager.cancel(PENDINGCALL_NOTIFICATION);
        }
        sendCallStateToFlutter("CLOSED");
        sendCallTypeToFlutter("ENDED");
        MptCallkitPlugin.sendToFlutter("isRemoteVideoReceived", false);
        isRemoteVideoReceived = false;

        // Reset camera to front camera when call ends
        Engine.Instance().mUseFrontCamera = true;
        Engine.Instance().getEngine().setVideoDeviceId(1);
    }

    @Override
    public void onDialogStateUpdated(String s, String s1, String s2, String s3) {
        logWithTimestamp("SDK-Android: onDialogStateUpdated");
    }

    @Override
    public void onRemoteHold(long l) {
        logWithTimestamp("SDK-Android: onRemoteHold");
    }

    @Override
    public void onRemoteUnHold(long l, String s, String s1, boolean b, boolean b1) {
        logWithTimestamp("SDK-Android: onRemoteUnHold");
    }

    @Override
    public void onReceivedRefer(long l, long l1, String s, String s1, String s2) {
        logWithTimestamp("SDK-Android: onReceivedRefer");
    }

    @Override
    public void onReferAccepted(long sessionId) {
        logWithTimestamp("SDK-Android: onReferAccepted");
        Session session = CallManager.Instance().findSessionBySessionID(sessionId);
        if (session != null) {
            session.state = Session.CALL_STATE_FLAG.CLOSED;
            session.sessionID = sessionId;

            Intent broadIntent = new Intent(CALL_CHANGE_ACTION);
            broadIntent.putExtra(EXTRA_CALL_SEESIONID, sessionId);
            String description = session.lineName + " onReferAccepted";
            broadIntent.putExtra(EXTRA_CALL_DESCRIPTION, description);

            sendPortSipMessage(description, broadIntent);
        }
        Ring.getInstance(this).stopRingTone();
    }

    @Override
    public void onReferRejected(long l, String s, int i) {
        logWithTimestamp("SDK-Android: onReferRejected");
    }

    @Override
    public void onTransferTrying(long l) {
        logWithTimestamp("SDK-Android: onTransferTrying");
    }

    @Override
    public void onTransferRinging(long l) {
        logWithTimestamp("SDK-Android: onTransferRinging");
    }

    @Override
    public void onACTVTransferSuccess(long sessionId) {
        logWithTimestamp("SDK-Android: onACTVTransferSuccess");
        Session session = CallManager.Instance().findSessionBySessionID(sessionId);
        if (session != null) {
            session.state = Session.CALL_STATE_FLAG.CLOSED;
            session.sessionID = sessionId;

            Intent broadIntent = new Intent(CALL_CHANGE_ACTION);
            broadIntent.putExtra(EXTRA_CALL_SEESIONID, sessionId);
            String description = session.lineName + " Transfer succeeded, call closed";
            broadIntent.putExtra(EXTRA_CALL_DESCRIPTION, description);

            sendPortSipMessage(description, broadIntent);
            // Close the call after succeeded transfer the call
            MptCallkitPlugin.hangup();
        }
    }

    @Override
    public void onACTVTransferFailure(long sessionId, String reason, int code) {
        logWithTimestamp("SDK-Android: onACTVTransferFailure");
        Session session = CallManager.Instance().findSessionBySessionID(sessionId);
        if (session != null) {
            Intent broadIntent = new Intent(CALL_CHANGE_ACTION);
            broadIntent.putExtra(EXTRA_CALL_SEESIONID, sessionId);
            String description = session.lineName + " Transfer failure!";
            broadIntent.putExtra(EXTRA_CALL_DESCRIPTION, description);

            sendPortSipMessage(description, broadIntent);

        }
    }

    @Override
    public void onReceivedSignaling(long l, String s) {
        logWithTimestamp("SDK-Android: onReceivedSignaling");
    }

    @Override
    public void onSendingSignaling(long l, String s) {
        logWithTimestamp("SDK-Android: onSendingSignaling");
    }

    @Override
    public void onWaitingVoiceMessage(String s, int i, int i1, int i2, int i3) {
        logWithTimestamp("SDK-Android: onWaitingVoiceMessage");
    }

    @Override
    public void onWaitingFaxMessage(String s, int i, int i1, int i2, int i3) {
        logWithTimestamp("SDK-Android: onWaitingFaxMessage");
    }

    @Override
    public void onRecvDtmfTone(long l, int i) {

    }

    @Override
    public void onRecvOptions(String s) {

    }

    @Override
    public void onRecvInfo(String s) {

    }

    @Override
    public void onRecvNotifyOfSubscription(long l, String s, byte[] bytes, int i) {

    }

    @Override
    public void onPresenceRecvSubscribe(long subscribeId,
            String fromDisplayName,
            String from,
            String subject) {
        logWithTimestamp("SDK-Android: onPresenceRecvSubscribe");
        Contact contact = ContactManager.Instance().findContactBySipAddr(from);
        if (contact == null) {
            contact = new Contact();
            contact.sipAddr = from;
            ContactManager.Instance().addContact(contact);
        }

        contact.subRequestDescription = subject;
        contact.subId = subscribeId;
        switch (contact.state) {
            case ACCEPTED:// This subscribe has accepted
                Engine.Instance().getEngine().presenceAcceptSubscribe(subscribeId);
                break;
            case REJECTED:// This subscribe has rejected
                Engine.Instance().getEngine().presenceRejectSubscribe(subscribeId);
                break;
            case UNSETTLLED:
                break;
            case UNSUBSCRIBE:
                contact.state = Contact.SUBSCRIBE_STATE_FLAG.UNSETTLLED;
                break;
        }
        Intent broadIntent = new Intent(PRESENCE_CHANGE_ACTION);
        sendPortSipMessage("OnPresenceRecvSubscribe", broadIntent);
    }

    @Override
    public void onPresenceOnline(String fromDisplayName, String from, String stateText) {
        logWithTimestamp("SDK-Android: onPresenceOnline");
        Contact contact = ContactManager.Instance().findContactBySipAddr(from);
        if (contact == null) {

        } else {
            contact.subDescription = stateText;
        }

        Intent broadIntent = new Intent(PRESENCE_CHANGE_ACTION);
        sendPortSipMessage("OnPresenceRecvSubscribe", broadIntent);
    }

    @Override
    public void onPresenceOffline(String fromDisplayName, String from) {
        Contact contact = ContactManager.Instance().findContactBySipAddr(from);
        if (contact == null) {

        } else {
            contact.subDescription = "Offline";
        }

        Intent broadIntent = new Intent(PRESENCE_CHANGE_ACTION);
        sendPortSipMessage("OnPresenceRecvSubscribe", broadIntent);
    }

    @Override
    public void onRecvOutOfDialogMessage(String s, String s1, String s2, String s3, String s4, String s5, byte[] bytes,
            int i, String s6) {

    }

    @Override
    public void onSendMessageSuccess(long l, long l1, String s) {

    }

    @Override
    public void onSendMessageFailure(long l, long l1, String s, int i, String s1) {

    }

    @Override
    public void onSendOutOfDialogMessageSuccess(long l, String s, String s1, String s2, String s3, String s4) {

    }

    @Override
    public void onSendOutOfDialogMessageFailure(long l, String s, String s1, String s2, String s3, String s4, int i,
            String s5) {

    }

    @Override
    public void onSubscriptionFailure(long l, int i) {

    }

    @Override
    public void onSubscriptionTerminated(long l) {

    }

    @Override
    public void onPlayFileFinished(long l, String s) {

    }

    @Override
    public void onStatistics(long l, String s) {

    }

    @Override
    public void onAudioDeviceChanged(PortSipEnumDefine.AudioDevice audioDevice,
            Set<PortSipEnumDefine.AudioDevice> set) {
        logWithTimestamp("SDK-Android: onAudioDeviceChanged - " + audioDevice);
        CallManager.Instance().setSelectableAudioDevice(audioDevice, set);

        Engine.Instance().invokeMethod("currentAudioDevice", audioDevice.toString());
        MptCallkitPlugin.sendToFlutter("currentAudioDevice", audioDevice.toString());

        Intent intent = new Intent();
        intent.setAction(ACTION_SIP_AUDIODEVICE);
        sendBroadcast(intent);
    }

    @Override
    public void onAudioFocusChange(int i) {

    }

    @Override
    public void onRTPPacketCallback(long l, int i, int i1, byte[] bytes, int i2) {

    }

    @Override
    public void onAudioRawCallback(long l, int i, byte[] bytes, int i1, int i2) {

    }

    @Override
    public void onVideoRawCallback(long sessionId,
            int enum_direction,
            int width,
            int height,
            byte[] data,
            int dataLength) {

        if (!isRemoteVideoReceived) {
             logWithTimestamp("SDK-Android: onVideoRawCallback - " +
                "sessionId: " + sessionId +
                "enum_direction: " + enum_direction +
                "width: " + width +
                "height: " + height +
                "dataLength: " + dataLength);
            isRemoteVideoReceived = true;
            Engine.Instance().getEngine().enableVideoStreamCallback(sessionId, PortSipEnumDefine.ENUM_DIRECTION_NONE);

            // Post to main thread to avoid crash - don't call SDK API or Flutter methods
            // directly in this callback
            new android.os.Handler(android.os.Looper.getMainLooper()).post(new Runnable() {
                @Override
                public void run() {
                    try {
                        MptCallkitPlugin.sendToFlutter("isRemoteVideoReceived", true);
                        logWithTimestamp("SDK-Android: Posted isRemoteVideoReceived to Flutter on main thread");
                    } catch (Exception e) {
                        logWithTimestamp(
                                "SDK-Android: Error sending isRemoteVideoReceived to Flutter: " + e.getMessage());
                    }
                }
            });
        }
    };

    @Override
    public void onNetworkChange(int netMobile) {
        logWithTimestamp("SDK-Android: onNetworkChange");
        if (netMobile == -1) {
            // invaluable
        } else {
            if (CallManager.Instance().online) {
                Engine.Instance().getEngine().refreshRegistration(0);
            } else {
                //
            }
        }
    }

    public static void ConfigPreferences(Context context, PortSipSdk sdk) {
        if (sdk == null) {
            return;
        }
        sdk.clearAudioCodec();
        sdk.addAudioCodec(PortSipEnumDefine.ENUM_AUDIOCODEC_PCMA);
        sdk.addAudioCodec(PortSipEnumDefine.ENUM_AUDIOCODEC_PCMU);
        sdk.addAudioCodec(PortSipEnumDefine.ENUM_AUDIOCODEC_G729);

        sdk.clearVideoCodec();
        sdk.addVideoCodec(PortSipEnumDefine.ENUM_VIDEOCODEC_H264);
        sdk.addVideoCodec(PortSipEnumDefine.ENUM_VIDEOCODEC_VP8);
        sdk.addVideoCodec(PortSipEnumDefine.ENUM_VIDEOCODEC_VP9);

        // Apply video params from preferences
        SharedPreferences prefs = PreferenceManager.getDefaultSharedPreferences(context);
        int prefBitrate = prefs.getInt("bitrate", 1024);
        int prefFrameRate = prefs.getInt("frameRate", 30);
        String prefResolution = prefs.getString("resolution", "720P");

        sdk.setVideoBitrate(-1, prefBitrate);
        sdk.setVideoFrameRate(-1, prefFrameRate);
        sdk.setAudioSamples(20, 60);

        // 1 - FrontCamra 0 - BackCamra
        sdk.setVideoDeviceId(1);

        sdk.setVideoNackStatus(true);

        sdk.enableAEC(true);
        sdk.enableAGC(true);
        sdk.enableCNG(true);
        sdk.enableVAD(true);
        sdk.enableANS(false);

        boolean foward = false;
        boolean fowardBusy = false;
        String fowardto = null;
        if (foward && !TextUtils.isEmpty(fowardto)) {
            sdk.enableCallForward(fowardBusy, fowardto);
        }

        sdk.setReliableProvisional(0);

        String resolution = prefResolution != null ? prefResolution : "720P";
        int width = 352;
        int height = 288;
        if (resolution.equals("QCIF")) {
            width = 176;
            height = 144;
        } else if (resolution.equals("CIF")) {
            width = 352;
            height = 288;
        } else if (resolution.equals("VGA")) {
            width = 640;
            height = 480;
        } else if (resolution.equals("720P")) {
            width = 1280;
            height = 720;
        } else if (resolution.equals("1080P")) {
            width = 1920;
            height = 1080;
        }

        sdk.setVideoResolution(width, height);
    }

    public static void startServiceCompatibility(@NonNull Context context, @NonNull Intent intent) {
        // logWithTimestamp("SDK-Android: startServiceCompatibility");
        // if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        // context.startForegroundService(intent);
        // } else {
        // context.startService(intent);
        // }
        context.startService(intent);
    }

    // --------------------
    public void sendPortSipMessage(String message, Intent broadIntent) {
        // Intent intent = new Intent(this, MainActivity.class);
        // PendingIntent contentIntent = PendingIntent.getActivity(this, 0, intent,
        // PendingIntent.FLAG_IMMUTABLE);

        // Notification.Builder builder;
        // if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
        // builder = new Notification.Builder(this, channelID);
        // } else {
        // builder = new Notification.Builder(this);
        // }
        // builder.setSmallIcon(R.drawable.icon)
        // .setContentTitle("Sip Notify")
        // .setContentText(message)
        // .setContentIntent(contentIntent)
        // .build();// getNotification()
        //
        // mNotificationManager.notify(1, builder.build());
        sendBroadcast(broadIntent);
    }

    private void sendCallStateToFlutter(String state) {
        if (Engine.Instance() != null) {
            Engine.Instance().invokeMethod("callState", state);
            MptCallkitPlugin.sendToFlutter("callState", state);
            logWithTimestamp("SDK-Android: callState - " + state);
        }
    }

    private void sendCallTypeToFlutter(String state) {
        if (Engine.Instance() != null) {
            Engine.Instance().invokeMethod("callType", state);
            MptCallkitPlugin.sendToFlutter("callType", state);
        }
    }
}