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
import com.mpt.mpt_callkit.IncomingActivity;

import java.util.Arrays;
import java.util.HashSet;
import java.util.List;
import java.util.Random;
import java.util.Set;
import java.util.UUID;

import com.mpt.mpt_callkit.MainActivity;

public class PortSipService extends Service implements OnPortSIPEvent, NetWorkReceiver.NetWorkListener {

    private NetWorkReceiver mNetWorkReceiver;
    private NotificationManager mNotificationManager;
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
    private final String APPID = "com.mpt.mpt_callkit";
    protected PowerManager.WakeLock mCpuLock;

    private String getResourceFromContext(Context context, String resName) {
        final int stringRes = context.getResources().getIdentifier(resName, "string", context.getPackageName());
        if (stringRes == 0) {
            throw new IllegalArgumentException(String.format("The 'R.string.%s' value it's not defined in your project's resources file.", resName));
        }
        return context.getString(stringRes);
    }

    private int getDrawableFromContext(Context context, String resName) {
        final int stringRes = context.getResources().getIdentifier(resName, "drawable", context.getPackageName());
        return stringRes;
    }

    public void keepCpuRun(boolean keepRun) {
        PowerManager powerManager = (PowerManager) getSystemService(POWER_SERVICE);
        if (keepRun == true) { //open
            if (mCpuLock == null) {
                if ((mCpuLock = powerManager.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "SipSample:CpuLock.")) == null) {
                    return;
                }
                mCpuLock.setReferenceCounted(false);
            }

            synchronized (mCpuLock) {
                if (!mCpuLock.isHeld()) {
                    mCpuLock.acquire();
                }
            }
        } else {//close
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
        System.out.println("quanth: isForeground - Checking if app is in foreground");
        if (activitys.length > 0) {
            String packagename = getPackageName();
            //String processName= getProcessName();||activityname.contains(processName)
            for (String activityname : activitys) {
                System.out.println("quanth: isForeground - Active package: " + activityname);
                if (activityname.contains(packagename)) {
                    System.out.println("quanth: isForeground - App is in foreground");
                    return true;
                }
            }
            System.out.println("quanth: isForeground - App is NOT in foreground");
            return false;
        }
        System.out.println("quanth: isForeground - No active packages found");
        return false;
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
        System.out.println("quanth: PortSipService onCreate");
        super.onCreate();
        context = getApplicationContext();

        mNotificationManager = (NotificationManager) getSystemService(NOTIFICATION_SERVICE);
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(channelID, getResourceFromContext(context, "app_name"), NotificationManager.IMPORTANCE_DEFAULT);
            channel.enableLights(true);
            NotificationChannel callChannel = new NotificationChannel(callChannelID, getResourceFromContext(context, "app_name"), NotificationManager.IMPORTANCE_HIGH);
            mNotificationManager.createNotificationChannel(channel);
            mNotificationManager.createNotificationChannel(callChannel);
        }
        showServiceNotifiCation();

        registerReceiver();
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        Engine.Instance().getEngine().destroyConference();
        unregisterReceiver();
        if (mCpuLock != null) {
            mCpuLock.release();
        }
        mNotificationManager.cancelAll();
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            mNotificationManager.deleteNotificationChannel(channelID);
            mNotificationManager.deleteNotificationChannel(callChannelID);
        }
        mNotificationManager = null;
        Engine.Instance().getEngine().removeUser();
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        System.out.println("quanth: onStartCommand");
        String username = intent.getStringExtra("username");
        String password = intent.getStringExtra("password");
        String domain = intent.getStringExtra("domain");
        String sipServer = intent.getStringExtra("sipServer");
        String port = intent.getStringExtra("port");
        String displayName = intent.getStringExtra("displayName");
        int result = super.onStartCommand(intent, flags, startId);
        if (intent != null) {
            /*if(ACTION_PUSH_MESSAGE.equals(intent.getAction())){
                if(!CallManager.Instance().online){
                    initialSDK();
                }
                if(!CallManager.Instance().isRegistered){
                    registerToServer();
                }
            }else */
            if (ACTION_SIP_REGIEST.equals(intent.getAction())) {
                if (!CallManager.Instance().online) {
                    initialSDK();
                    registerToServer(username, password, domain, sipServer, port, displayName);
                }
            } else if (ACTION_SIP_UNREGIEST.equals(intent.getAction())) {
                System.out.println("quanth: service is doing unregisterToServer...");
                unregisterToServer();
                Engine.Instance().getMethodChannel().invokeMethod("releaseExtension", true);
                context.stopService(new Intent(this, PortSipService.class));
                System.out.println("quanth: service unregisterToServer done");
            } else if (ACTION_STOP.equals(intent.getAction())) {
                return START_NOT_STICKY;
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
            String displayName
    ) {
        SharedPreferences preferences = PreferenceManager.getDefaultSharedPreferences(this);
        int srtpType = preferences.getInt(SRTP, 0);
        String authName = "";
        String stunServer = "";
        String stunPort = "3478";

        int sipServerPort = Integer.parseInt(serverPort);
        int stunServerPort = Integer.parseInt(stunPort);

        if (TextUtils.isEmpty(userName)) {
            showTipMessage("Please enter user name!");
            return;
        }

        if (TextUtils.isEmpty(password)) {
            showTipMessage("Please enter password!");
            return;
        }

        if (TextUtils.isEmpty(sipServer)) {
            showTipMessage("Please enter SIP Server!");
            return;
        }

        if (TextUtils.isEmpty(serverPort)) {
            showTipMessage("Please enter Server Port!");
            return;
        }

        Engine.Instance().getEngine().removeUser();
        int result = Engine.Instance().getEngine().setUser(userName, displayName, authName, password,
                userDomain, sipServer, sipServerPort, stunServer, stunServerPort, null, 5060);

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

        if (!TextUtils.isEmpty(pushToken)) {
            String pushMessage = "device-os=android;device-uid=" + pushToken + ";allow-call-push=true;allow-message-push=true;app-id=" + APPID;
            Engine.Instance().getEngine().addSipMessageHeader(-1, "REGISTER", 1, "portsip-push", pushMessage);
            //new version
            Engine.Instance().getEngine().addSipMessageHeader(-1, "REGISTER", 1, "x-p-push", pushMessage);
        }

        result = Engine.Instance().getEngine().registerServer(90, 0);
        if (result != PortSipErrorcode.ECoreErrorNone) {
            showTipMessage("registerServer failure ErrorCode =" + result);
            Engine.Instance().getEngine().unRegisterServer(100);
            CallManager.Instance().resetAll();
        }
    }

    public void unregisterToServer() {
        System.out.println("quanth: unregisterToServer");
        if (CallManager.Instance().online) {
            Engine.Instance().getEngine().unRegisterServer(100);
            Engine.Instance().getEngine().removeUser();
            Engine.Instance().getEngine().unInitialize();
            CallManager.Instance().online = false;
            Engine.Instance().getMethodChannel().invokeMethod("onlineStatus", false);
            CallManager.Instance().isRegistered = false;
        }
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
                //                .setContentIntent(contentIntent)
                .build();// getNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(SERVICE_NOTIFICATION, builder.build(), ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
                    | ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA
                    | ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK);
        } else {
            startForeground(SERVICE_NOTIFICATION, builder.build());
        }
    }

    private int initialSDK() {
        Engine.Instance().getEngine().setOnPortSIPEvent(this);
        CallManager.Instance().online = true;
        // Engine.Instance().getMethodChannel().invokeMethod("onlineStatus", true);
        String dataPath = getExternalFilesDir(null).getAbsolutePath();
        String certRoot = dataPath + "/certs";
        SharedPreferences preferences = PreferenceManager.getDefaultSharedPreferences(this);
        Random rm = new Random();
        int localPort = 5060 + rm.nextInt(60000);
        int transType = preferences.getInt(TRANS, 0);
        int result = Engine.Instance().getEngine().initialize(getTransType(transType), "0.0.0.0", localPort,
                PortSipEnumDefine.ENUM_LOG_LEVEL_DEBUG, dataPath,
                8, "PortSIP SDK for Android", 0, 0, certRoot, "", false, null);

        if (result != PortSipErrorcode.ECoreErrorNone) {
            showTipMessage("initialize failure ErrorCode = " + result);
            CallManager.Instance().resetAll();
        } else {

            result = Engine.Instance().getEngine().setLicenseKey("LicenseKey");
            if (result == PortSipErrorcode.ECoreWrongLicenseKey) {
                showTipMessage("The wrong license key was detected, please check with sales@portsip.com or support@portsip.com");
            } else if (result == PortSipErrorcode.ECoreTrialVersionLicenseKey) {
                Log.w("Trial Version", "This trial version SDK just allows short conversation, you can't hearing anything after 2-3 minutes, contact us: sales@portsip.com to buy official version.");
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
        System.out.println("quanth: onRegisterSuccess");
        Engine.Instance().getMethodChannel().invokeMethod("onlineStatus", true);
        CallManager.Instance().isRegistered = true;
        Intent broadIntent = new Intent(REGISTER_CHANGE_ACTION);
        broadIntent.putExtra(EXTRA_REGISTER_STATE, statusText);
//        sendPortSipMessage("onRegisterSuccess", broadIntent);
        keepCpuRun(true);
        Engine.Instance().getMethodChannel().invokeMethod("registrationStateStream", true);
    }

    @Override
    public void onRegisterFailure(String statusText, int statusCode, String sipMessage) {
        System.out.println("quanth: onRegisterFailure " + statusText + " - " + statusCode + " - " + sipMessage);
        Intent broadIntent = new Intent(REGISTER_CHANGE_ACTION);
        broadIntent.putExtra(EXTRA_REGISTER_STATE, statusText);
//        sendPortSipMessage("onRegisterFailure" + statusCode, broadIntent);
        CallManager.Instance().isRegistered = false;
        CallManager.Instance().resetAll();

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

        System.out.println("quanth: onInviteIncoming - Debug info:");
        System.out.println("quanth: caller = " + caller);
        System.out.println("quanth: callee = " + callee);
        System.out.println("quanth: sessionId = " + sessionId);
        System.out.println("quanth: existsVideo = " + existsVideo);
        System.out.println("quanth: sipMessage = " + sipMessage);

        if (CallManager.Instance().findIncomingCall() != null) {
            Engine.Instance().getEngine().rejectCall(sessionId, 486); //busy
            System.out.println("quanth: Rejected call - already in a call");
            return;
        }
        Session session = CallManager.Instance().findIdleSession();
        session.state = Session.CALL_STATE_FLAG.INCOMING;
        // session.hasVideo = existsVideo;
        session.sessionID = sessionId;
        session.remote = caller;
        session.displayName = callerDisplayName;

        Intent broadIntent = new Intent(CALL_CHANGE_ACTION);
        String description = session.lineName + " onInviteIncoming";

        broadIntent.putExtra(EXTRA_CALL_SEESIONID, sessionId);
        broadIntent.putExtra(EXTRA_CALL_DESCRIPTION, description);

        sendPortSipMessage(description, broadIntent);

        Ring.getInstance(this).startRingTone();

        // Gửi thông tin cuộc gọi đến đến Flutter
        sendCallStateToFlutter("INCOMING");

        // Gửi thêm thông tin chi tiết về người gọi
        if (Engine.Instance().getMethodChannel() != null) {
            try {
                // Tạo đối tượng chứa thông tin cuộc gọi để gửi về Flutter
                java.util.Map<String, Object> callInfo = new java.util.HashMap<>();
                callInfo.put("sessionId", sessionId);
                callInfo.put("callerName", callerDisplayName);
                callInfo.put("callerNumber", caller);
                callInfo.put("hasVideo", existsVideo);

                Engine.Instance().getMethodChannel().invokeMethod("incomingCall", callInfo);
            } catch (Exception e) {
                System.out.println("quanth: Error sending call info to Flutter: " + e.getMessage());
            }
        }
    }

    public void showPendingCallNotification(Context context, String contenTitle, String contenText, Intent intent) {
        System.out.println("quanth: showPendingCallNotification - Creating notification for incoming call");
        System.out.println("quanth: showPendingCallNotification - contenTitle: " + contenTitle);
        System.out.println("quanth: showPendingCallNotification - contenText: " + contenText);

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
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
        );

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

        System.out.println("quanth: showPendingCallNotification - Displaying notification with ID: " + PENDINGCALL_NOTIFICATION);
        mNotificationManager.notify(PENDINGCALL_NOTIFICATION, builder.build());

        // Thử mở trực tiếp activity nếu notification không hoạt động
        try {
            context.startActivity(intent);
            System.out.println("quanth: showPendingCallNotification - Started IncomingActivity directly");
        } catch (Exception e) {
            System.out.println("quanth: showPendingCallNotification - Failed to start activity: " + e.getMessage());
        }
    }

    @Override
    public void onInviteTrying(long l) {
        sendCallStateToFlutter("TRYING");
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
        System.out.println("quanth: onInviteAnswered");
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
        sendCallStateToFlutter("CONNECTED");
    }

    @Override
    public void onInviteFailure(long sessionId, String callerDisplayName,
            String caller,
            String calleeDisplayName,
            String callee,
            String reason,
            int code,
            String sipMessage) {
        System.out.println("quanth: onInviteFailure");
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
    }

    @Override
    public void onInviteUpdated(long sessionId, String audioCodecs, String videoCodecs, String screenCodecs, boolean existsAudio, boolean existsVideo, boolean existsScreen, String sipMessage) {
        System.out.println("quanth: onInviteUpdated");
        Session session = CallManager.Instance().findSessionBySessionID(sessionId);

        if (session != null) {
            session.state = Session.CALL_STATE_FLAG.CONNECTED;
            session.hasVideo = existsVideo;
            session.bScreenShare = existsScreen;

            Intent broadIntent = new Intent(CALL_CHANGE_ACTION);
            broadIntent.putExtra(EXTRA_CALL_SEESIONID, sessionId);
            String description = session.lineName + " OnInviteUpdated";
            broadIntent.putExtra(EXTRA_CALL_DESCRIPTION, description);

            sendPortSipMessage(description, broadIntent);
        }
    }

    @Override
    public void onInviteConnected(long sessionId) {
        System.out.println("quanth: onInviteConnected");
        Session session = CallManager.Instance().findSessionBySessionID(sessionId);
        if (session != null) {
            session.state = Session.CALL_STATE_FLAG.CONNECTED;
            session.sessionID = sessionId;

            if (/*applicaton.mConference*/true) {
                Engine.Instance().getEngine().joinToConference(session.sessionID);
                Engine.Instance().getEngine().sendVideo(session.sessionID, true);
            }

            Intent broadIntent = new Intent(CALL_CHANGE_ACTION);
            broadIntent.putExtra(EXTRA_CALL_SEESIONID, sessionId);
            String description = session.lineName + " OnInviteConnected";
            broadIntent.putExtra(EXTRA_CALL_DESCRIPTION, description);

            sendPortSipMessage(description, broadIntent);
        }
        sendCallStateToFlutter("CONNECTED");
    }

    @Override
    public void onInviteBeginingForward(String s) {

    }

    @Override
    public void onInviteClosed(long sessionId, String sipMessage) {
        System.out.println("quanth: onInviteClosed");
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
        mNotificationManager.cancel(PENDINGCALL_NOTIFICATION);
        sendCallStateToFlutter("CLOSED");
    }

    @Override
    public void onDialogStateUpdated(String s, String s1, String s2, String s3) {
        System.out.println("quanth: onDialogStateUpdated");
    }

    @Override
    public void onRemoteHold(long l) {
        System.out.println("quanth: onRemoteHold");
    }

    @Override
    public void onRemoteUnHold(long l, String s, String s1, boolean b, boolean b1) {
        System.out.println("quanth: onRemoteUnHold");
    }

    @Override
    public void onReceivedRefer(long l, long l1, String s, String s1, String s2) {
        System.out.println("quanth: onReceivedRefer");
    }

    @Override
    public void onReferAccepted(long sessionId) {
        System.out.println("quanth: onReferAccepted");
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
        System.out.println("quanth: onReferRejected");
    }

    @Override
    public void onTransferTrying(long l) {
        System.out.println("quanth: onTransferTrying");
    }

    @Override
    public void onTransferRinging(long l) {
        System.out.println("quanth: onTransferRinging");
    }

    @Override
    public void onACTVTransferSuccess(long sessionId) {
        System.out.println("quanth: onACTVTransferSuccess");
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
            Engine.Instance().getEngine().hangUp(sessionId);
        }
    }

    @Override
    public void onACTVTransferFailure(long sessionId, String reason, int code) {
        System.out.println("quanth: onACTVTransferFailure");
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
        System.out.println("quanth: onReceivedSignaling");
    }

    @Override
    public void onSendingSignaling(long l, String s) {
        System.out.println("quanth: onSendingSignaling");
    }

    @Override
    public void onWaitingVoiceMessage(String s, int i, int i1, int i2, int i3) {
        System.out.println("quanth: onWaitingVoiceMessage");
    }

    @Override
    public void onWaitingFaxMessage(String s, int i, int i1, int i2, int i3) {
        System.out.println("quanth: onWaitingFaxMessage");
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
        System.out.println("quanth: onPresenceRecvSubscribe");
        Contact contact = ContactManager.Instance().findContactBySipAddr(from);
        if (contact == null) {
            contact = new Contact();
            contact.sipAddr = from;
            ContactManager.Instance().addContact(contact);
        }

        contact.subRequestDescription = subject;
        contact.subId = subscribeId;
        switch (contact.state) {
            case ACCEPTED://This subscribe has accepted
                Engine.Instance().getEngine().presenceAcceptSubscribe(subscribeId);
                break;
            case REJECTED://This subscribe has rejected
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
        System.out.println("quanth: onPresenceOnline");
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
    public void onRecvMessage(long l, String s, String s1, byte[] bytes, int i) {

    }

    @Override
    public void onRecvOutOfDialogMessage(String s, String s1, String s2, String s3, String s4, String s5, byte[] bytes, int i, String s6) {

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
    public void onSendOutOfDialogMessageFailure(long l, String s, String s1, String s2, String s3, String s4, int i, String s5) {

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
    public void onAudioDeviceChanged(PortSipEnumDefine.AudioDevice audioDevice, Set<PortSipEnumDefine.AudioDevice> set) {
        CallManager.Instance().setSelectableAudioDevice(audioDevice, set);

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
    public void onVideoRawCallback(long l, int i, int i1, int i2, byte[] bytes, int i3) {

    }

    @Override
    public void onNetworkChange(int netMobile) {
        System.out.println("quanth: onNetworkChange");
        if (netMobile == -1) {
            //invaluable
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

        sdk.setVideoBitrate(-1, 512);
        sdk.setVideoFrameRate(-1, 20);
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

        String resolution = "720P";
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
        System.out.println("quanth: startServiceCompatibility");
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(intent);
        } else {
            context.startService(intent);
        }
    }

    //--------------------
    public void sendPortSipMessage(String message, Intent broadIntent) {
//        Intent intent = new Intent(this, MainActivity.class);
//        PendingIntent contentIntent = PendingIntent.getActivity(this, 0, intent, PendingIntent.FLAG_IMMUTABLE);

//        Notification.Builder builder;
//        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
//            builder = new Notification.Builder(this, channelID);
//        } else {
//            builder = new Notification.Builder(this);
//        }
//        builder.setSmallIcon(R.drawable.icon)
//                .setContentTitle("Sip Notify")
//                .setContentText(message)
//                .setContentIntent(contentIntent)
//                .build();// getNotification()
//
//        mNotificationManager.notify(1, builder.build());
        sendBroadcast(broadIntent);
    }

    private void sendCallStateToFlutter(String state) {
        if (Engine.Instance().getMethodChannel() != null) {
            Engine.Instance().getMethodChannel().invokeMethod("callState", state);
        }
    }
}
