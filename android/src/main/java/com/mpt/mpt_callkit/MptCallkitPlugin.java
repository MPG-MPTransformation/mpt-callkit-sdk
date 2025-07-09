package com.mpt.mpt_callkit;

/**
 * PortsipFlutterPlugin
 */
import android.net.Uri;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.Build;
import android.widget.Toast;
import androidx.annotation.NonNull;

import com.mpt.mpt_callkit.receiver.PortMessageReceiver;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import android.content.Context;
import com.portsip.PortSipEnumDefine;
import com.portsip.PortSipErrorcode;
import com.portsip.PortSipSdk;
import com.portsip.OnPortSIPEvent;
import android.Manifest;
import android.app.Activity;
import android.content.pm.PackageManager;
import androidx.core.app.ActivityCompat;
import com.mpt.mpt_callkit.util.CallManager;
import com.mpt.mpt_callkit.util.Session;
import com.mpt.mpt_callkit.util.Engine;
import com.mpt.mpt_callkit.util.Ring;
import android.os.Handler;
import io.flutter.embedding.engine.FlutterEngine;
import com.mpt.mpt_callkit.LocalViewFactory;
import com.mpt.mpt_callkit.RemoteViewFactory;
import io.flutter.plugin.common.EventChannel;

import java.nio.charset.StandardCharsets;
import java.util.Map;
import java.util.HashMap;
import java.util.List;
import java.util.ArrayList;
import java.util.Set;
import org.json.JSONObject;

public class MptCallkitPlugin implements FlutterPlugin, MethodCallHandler, ActivityAware {

    /// The MethodChannel that will the communication between Flutter and native
    /// Android
    ///
    /// This local reference serves to register the plugin with the Flutter Engine
    /// and unregister it
    /// when the Flutter Engine is detached from the Activity
    public Context context;
    public Activity activity;
    // public String pushToken =
    // "e3TKpdmDSJqzW20HYsDe9h:APA91bFdWS9ALxW1I7Zuq7uXsYTL6-8F-A3AARhcrLMY6pB6ecUbWX7RbABnLrzCGjGBWIxJ8QaCQkwkOjrv2BOJjEGfFgIGjlIekFqKQR-dtutszyRLZy1Im6KXNIqDzicWIGKdbcWD";
    // public String APPID = "com.portsip.sipsample";
    private MethodChannel.Result pendingResult;
    private static final String CHANNEL = "native_events";
    private static EventChannel.EventSink eventSink;
    private static String xSessionId;
    private static String currentUsername; // Lưu username hiện tại

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
        System.out.println("SDK-Android: onAttachedToEngine");
        Engine.Instance().setMethodChannel(new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "mpt_callkit"));
        Engine.Instance().getMethodChannel().setMethodCallHandler(this);
        context = flutterPluginBinding.getApplicationContext();
        Engine.Instance().setEngine(new PortSipSdk(context));
        // Only create receiver if it doesn't exist
        if (Engine.Instance().getReceiver() == null) {
            Engine.Instance().setReceiver(new PortMessageReceiver());
        }

        // Đăng ký LocalViewFactory
        flutterPluginBinding
                .getPlatformViewRegistry()
                .registerViewFactory("LocalView", new LocalViewFactory(context));
        flutterPluginBinding
                .getPlatformViewRegistry()
                .registerViewFactory("RemoteView", new RemoteViewFactory());
        new EventChannel(flutterPluginBinding.getBinaryMessenger(), CHANNEL)
                .setStreamHandler(new EventChannel.StreamHandler() {
                    @Override
                    public void onListen(Object arguments, EventChannel.EventSink events) {
                        eventSink = events;
                        events.success("👋 Hello from native Java!");
                    }

                    @Override
                    public void onCancel(Object arguments) {
                        eventSink = null;
                    }
                });
    }

    public static void sendToFlutter(String message) {
        if (eventSink != null) {
            eventSink.success(message);
        }
    }

    public static void sendToFlutter(String message, Object data) {
        if (eventSink != null) {
            Map<String, Object> result = new HashMap<>();
            result.put("message", message);
            result.put("data", data);
            eventSink.success(result);
        }
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        System.out.println("SDK-Android: onMethodCall " + call.method);
        Intent offLineIntent = null;
        Intent myIntent = null;
        Intent stopIntent = null;
        switch (call.method) {
            case "getPlatformVersion":
                result.success("Android " + android.os.Build.VERSION.RELEASE);
                break;
            case "Offline":
                offLineIntent = new Intent(activity, PortSipService.class);
                offLineIntent.setAction(PortSipService.ACTION_SIP_UNREGIEST);
                PortSipService.startServiceCompatibility(activity, offLineIntent);
                result.success(true);
                System.out.println("SDK-Android: UnregisterServer..");
                break;
            case "call":
                String destinationNumber = call.argument("destination");
                boolean isVideoCall = call.argument("isVideoCall");
                boolean callResult = makeCall(destinationNumber, isVideoCall);
                result.success(callResult);
                break;
            case "requestPermission":
                requestPermissions(activity, result);
                break;
            case "openAppSetting":
                openAppSetting();
                break;
            case "ensureViewListenersRegistered":
                ensureViewListenersRegistered();
                result.success(true);
                break;
            case "appKilled":
                stopIntent = new Intent(activity, PortSipService.class);
                stopIntent.setAction(PortSipService.ACTION_STOP);
                PortSipService.startServiceCompatibility(activity, stopIntent);
                if (MainActivity.activity.receiver != null) {
                    MainActivity.activity.unregisterReceiver(MainActivity.activity.receiver);
                    MainActivity.activity.receiver = null;
                }
                MainActivity.activity.finish();
                hangup();
                activity.finishAndRemoveTask();
            case "hangup":
                hangup();
                break;
            case "hold":
                holdCall();
                break;
            case "unhold":
                unHoldCall();
                break;
            case "mute":
                muteMicrophone(true);
                break;
            case "unmute":
                muteMicrophone(false);
                break;
            case "cameraOn":
                toggleCameraOn(true);
                break;
            case "cameraOff":
                toggleCameraOn(false);
                break;
            case "answer":
                answerCall(false);
                break;
            case "switchCamera":
                boolean switchResult = switchCamera();
                result.success(switchResult);
                break;
            case "reject":
                rejectCall();
                break;
            case "setSpeaker":
                if (call.hasArgument("state")) {
                    String state = call.argument("state");
                    setSpeaker(state);
                    result.success(true);
                } else {
                    result.error("INVALID_ARGUMENTS", "Missing or invalid arguments for setSpeaker", null);
                }
                break;
            case "getAudioDevices":
                getAudioDevices();
                result.success(true);
                break;
            case "transfer":
                String destination = call.argument("destination");
                if (destination != null && !destination.isEmpty()) {
                    boolean transferResult = transfer(destination);
                    result.success(transferResult);
                } else {
                    result.error("INVALID_ARGUMENT", "Destination is required for transfer", null);
                }
                break;
            case "startActivity":
                myIntent = new Intent(activity, MainActivity.class);
                myIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                activity.startActivity(myIntent);
                break;
            case "finishActivity":
                System.out.println("SDK-Android: finishActivity");
                stopIntent = new Intent(activity, PortSipService.class);
                stopIntent.setAction(PortSipService.ACTION_STOP);
                PortSipService.startServiceCompatibility(activity, stopIntent);

                if (MainActivity.activity.receiver != null) {
                    MainActivity.activity.unregisterReceiver(MainActivity.activity.receiver);
                    MainActivity.activity.receiver = null;
                }
                MainActivity.activity.finish();
                break;
            case "Login":
                String username = call.argument("username");
                String displayName = call.argument("displayName") + "";
                String authName = call.argument("authName") + "";
                String password = call.argument("password");
                String userDomain = call.argument("userDomain");
                String sipServer = call.argument("sipServer");
                String transportType = call.argument("transportType") + "";
                String srtpType = call.argument("srtpType") + "";
                String sipServerPort = call.argument("sipServerPort") + "";
                String appId = call.argument("appId");
                String pushToken = call.argument("pushToken");

                // Lưu username hiện tại
                currentUsername = username;

                if (CallManager.Instance().online) {
                    System.out.println("SDK-Android: Already online");
                    Engine.Instance().getMethodChannel().invokeMethod("onlineStatus", CallManager.Instance().online);
                    MptCallkitPlugin.sendToFlutter("onlineStatus", CallManager.Instance().online);
                } else {
                    Intent onLineIntent = new Intent(activity, PortSipService.class);
                    onLineIntent.setAction(PortSipService.ACTION_SIP_REGIEST);
                    onLineIntent.putExtra("username", username);
                    onLineIntent.putExtra("password", password);
                    onLineIntent.putExtra("domain", userDomain);
                    onLineIntent.putExtra("sipServer", sipServer);
                    onLineIntent.putExtra("port", sipServerPort);
                    onLineIntent.putExtra("displayName", displayName);
                    onLineIntent.putExtra("transportType", transportType);
                    onLineIntent.putExtra("srtpType", srtpType);
                    onLineIntent.putExtra("appId", appId);
                    onLineIntent.putExtra("pushToken", pushToken);
                    PortSipService.startServiceCompatibility(context, onLineIntent);
                    System.out.println("SDK-Android: RegisterServer..");
                    pendingResult = result;
                    // Set timeout handler
                    new Handler().postDelayed(() -> {
                        if (pendingResult != null) {
                            pendingResult.success(false);
                            Engine.Instance().getMethodChannel().invokeMethod("registerFailure",
                                    "Request Timeout - 408 - SIP/2.0 408 Request Timeout");
                            pendingResult = null;
                            MptCallkitPlugin.sendToFlutter("registerFailure",
                                    "Request Timeout - 408 - SIP/2.0 408 Request Timeout");
                        }
                    }, 30000); // 30 seconds timeout
                }
                break;
            case "reInvite":
                xSessionId = call.argument("sessionId");
                boolean reinviteResult = reinviteSession(xSessionId);
                result.success(reinviteResult);
                break;
            case "updateVideoCall":
                Session currentLine = CallManager.Instance().getCurrentSession();
                Boolean isVideo = call.argument("isVideo");
                // Gửi video từ camera
                int sendVideoResult = Engine.Instance().getEngine().sendVideo(currentLine.sessionID, isVideo);
                System.out.println("SDK-Android: reinviteSession - sendVideo(): " + sendVideoResult);

                // Cập nhật cuộc gọi để thêm video stream
                int updateCallRes = Engine.Instance().getEngine().updateCall(currentLine.sessionID, true, isVideo);
                System.out.println("SDK-Android: reinviteSession - updateCall(): " + updateCallRes);

                result.success(updateCallRes == 0);
                break;
            default:
                result.notImplemented();
        }
    }

    /**
     * Ensure LocalView and RemoteView listeners are registered
     * Call this when app returns from background, especially after FCM processing
     */
    private void ensureViewListenersRegistered() {
        System.out.println("SDK-Android: ensureViewListenersRegistered - Checking and re-registering view listeners");

        if (Engine.Instance().getReceiver() == null) {
            System.out.println("SDK-Android: ensureViewListenersRegistered - Receiver is null, creating new one");
            Engine.Instance().setReceiver(new PortMessageReceiver());
        }

        // We don't have direct access to View instances here, but we can ensure the
        // receiver is ready
        // The actual re-registration will happen in View constructors or when they
        // detect missing listeners
        PortMessageReceiver receiver = Engine.Instance().getReceiver();
        if (receiver != null) {
            System.out.println("SDK-Android: ensureViewListenersRegistered - Current listeners count: "
                    + receiver.getListenersCount());
            System.out.println(
                    "SDK-Android: ensureViewListenersRegistered - Listeners info: " + receiver.getListenersInfo());
        }
    }

    void openAppSetting() {
        Intent intent = new Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS);
        intent.setData(Uri.parse("package:" + context.getPackageName()));
        activity.startActivity(intent);
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        Engine.Instance().setEngine(null);
        Engine.Instance().getMethodChannel().setMethodCallHandler(null);
    }

    @Override
    public void onAttachedToActivity(ActivityPluginBinding activityPluginBinding) {
        // TODO: your plugin is now attached to an Activity
        System.out.println("SDK-Android: onAttachedToActivity");
        activity = activityPluginBinding.getActivity();
        IntentFilter filter = new IntentFilter();
        filter.addAction(PortSipService.REGISTER_CHANGE_ACTION);
        filter.addAction(PortSipService.CALL_CHANGE_ACTION);
        filter.addAction(PortSipService.PRESENCE_CHANGE_ACTION);
        filter.addAction(PortSipService.ACTION_SIP_AUDIODEVICE);
        filter.addAction(PortSipService.ACTION_HANGOUT_SUCCESS);
        filter.addAction("CAMERA_SWITCH_ACTION");
        System.out.println("SDK-Android: Registering broadcast receiver for call actions");

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            activity.registerReceiver(Engine.Instance().getReceiver(), filter, Context.RECEIVER_EXPORTED);
            System.out.println("SDK-Android: Registered with RECEIVER_EXPORTED flag");
        } else {
            activity.registerReceiver(Engine.Instance().getReceiver(), filter);
            System.out.println("SDK-Android: Registered without RECEIVER_EXPORTED flag");
        }
        activityPluginBinding.addRequestPermissionsResultListener((requestCode, permissions, grantResults) -> {
            if (requestCode == REQ_DANGERS_PERMISSION) {
                if (grantResults.length > 0) {
                    boolean isAllGranted = true;
                    for (int result : grantResults) {
                        if (result != PackageManager.PERMISSION_GRANTED) {
                            isAllGranted = false;
                            break;
                        }
                    }
                    if (pendingResult != null) {
                        pendingResult.success(isAllGranted);
                        pendingResult = null;
                    }
                } else {
                    if (pendingResult != null) {
                        pendingResult.success(false);
                        pendingResult = null;
                    }
                }
                return true;
            }
            return false;
        });
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
        // TODO: the Activity your plugin was attached to was
        // destroyed to change configuration.
        // This call will be followed by onReattachedToActivityForConfigChanges().
        System.out.println("SDK-Android: onDetachedFromActivityForConfigChanges");
    }

    @Override
    public void onReattachedToActivityForConfigChanges(ActivityPluginBinding activityPluginBinding) {
        // TODO: your plugin is now attached to a new Activity
        // after a configuration change.
        activity = activityPluginBinding.getActivity();
        System.out.println("SDK-Android: onReattachedToActivityForConfigChanges");
    }

    @Override
    public void onDetachedFromActivity() {
        // TODO: your plugin is no longer associated with an Activity.
        // Clean up references.
        System.out.println("SDK-Android: onDetachedFromActivity");
        // Unregister SIP khi app bị destroy
        unregisterSipAndCleanup();
    }

    private void unregisterSipAndCleanup() {
        if (CallManager.Instance().online) {
            try {
                PortSipSdk engine = Engine.Instance().getEngine();
                if (engine != null) {
                    // Hang up all active calls first
                    CallManager.Instance().hangupAllCalls(engine);

                    // Wait a bit for cleanup
                    Thread.sleep(300);

                    // Destroy conference and cleanup video resources
                    engine.destroyConference();
                    engine.displayLocalVideo(false, false, null);

                    // Cleanup all sessions
                    for (int i = 0; i < CallManager.MAX_LINES; i++) {
                        Session session = CallManager.Instance().findSessionByIndex(i);
                        if (session != null && session.sessionID != Session.INVALID_SESSION_ID) {
                            engine.setRemoteVideoWindow(session.sessionID, null);
                            engine.setRemoteScreenWindow(session.sessionID, null);
                        }
                    }

                    // Unregister and cleanup
                    engine.unRegisterServer(100);
                    engine.removeUser();
                    engine.unInitialize();
                }

                // Reset các trạng thái
                CallManager.Instance().resetAll();
                CallManager.Instance().online = false;
                CallManager.Instance().isRegistered = false;

                // Dọn dẹp resources
                if (activity != null && Engine.Instance().getReceiver() != null) {
                    try {
                        activity.unregisterReceiver(Engine.Instance().getReceiver());
                    } catch (Exception e) {
                        System.out.println("SDK-Android: Error unregistering receiver: " + e.getMessage());
                    }
                }

                // Stop service nếu đang chạy
                if (context != null) {
                    context.stopService(new Intent(context, PortSipService.class));
                }

            } catch (Exception e) {
                System.out.println("SDK-Android: Error during unregisterSipAndCleanup: " + e.getMessage());
            }
        }
    }

    public void requestPermissions(Activity activity, MethodChannel.Result result) {
        // Create permission list based on Android version
        List<String> permissions = new ArrayList<>();
        permissions.add(Manifest.permission.CAMERA);
        permissions.add(Manifest.permission.RECORD_AUDIO);

        // Add BLUETOOTH_CONNECT permission only on Android 12+ (API 31+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            permissions.add(Manifest.permission.BLUETOOTH_CONNECT);
        }

        // Check if any permission is not granted
        boolean needPermission = false;
        for (String permission : permissions) {
            if (ActivityCompat.checkSelfPermission(activity, permission) != PackageManager.PERMISSION_GRANTED) {
                needPermission = true;
                break;
            }
        }

        if (needPermission) {
            System.out.println("SDK-Android: request permission");
            pendingResult = result;
            ActivityCompat.requestPermissions(activity,
                    permissions.toArray(new String[0]),
                    REQ_DANGERS_PERMISSION);
            return;
        }

        result.success(true);
        System.out.println("SDK-Android: no need request permission");
    }

    private final int REQ_DANGERS_PERMISSION = 2;

    boolean makeCall(String phoneNumber, boolean isVideoCall) {
        Session currentLine = CallManager.Instance().getCurrentSession();
        String callTo = phoneNumber;
        if (!currentLine.IsIdle()) {
            System.out.println("SDK-Android: Current line is busy now, please switch a line.");
            return false;
        }

        // Ensure that we have been added one audio codec at least
        if (Engine.Instance().getEngine().isAudioCodecEmpty()) {
            System.out.println("SDK-Android: Audio Codec Empty,add audio codec at first");
            return false;
        }

        // Usually for 3PCC need to make call without SDP
        long sessionId = Engine.Instance().getEngine().call(callTo, true, isVideoCall);
        if (sessionId <= 0) {
            System.out.println("SDK-Android: Call failure");
            return false;
        }
        // default send video
        Engine.Instance().getEngine().sendVideo(sessionId, isVideoCall);

        currentLine.remote = callTo;

        currentLine.sessionID = sessionId;
        currentLine.state = Session.CALL_STATE_FLAG.TRYING;
        currentLine.hasVideo = isVideoCall;
        System.out.println("SDK-Android: line= " + currentLine.lineName + ": Calling...");
        return true;
    }

    static void hangup() {
        Session currentLine = CallManager.Instance().getCurrentSession();
        Ring.getInstance(MainActivity.activity).stop();

        try {
            PortSipSdk engine = Engine.Instance().getEngine();
            if (engine != null && currentLine != null) {
                // Cleanup video resources for this session
                if (currentLine.sessionID != Session.INVALID_SESSION_ID) {
                    engine.setRemoteVideoWindow(currentLine.sessionID, null);
                    engine.setRemoteScreenWindow(currentLine.sessionID, null);
                }

                switch (currentLine.state) {
                    case INCOMING:
                        engine.rejectCall(currentLine.sessionID, 486);
                        System.out.println("SDK-Android: lineName= " + currentLine.lineName + ": Rejected call");

                        if (MainActivity.activity != null) {
                            MainActivity.activity.onHangUpCall();
                        }

                        Engine.Instance().getMethodChannel().invokeMethod("callState", "CLOSED");
                        MptCallkitPlugin.sendToFlutter("callState", "CLOSED");
                        System.out.println("SDK-Android: callState - " + "CLOSED");

                        break;
                    case CONNECTED:
                    case TRYING:
                        engine.hangUp(currentLine.sessionID);

                        if (Engine.Instance().getMethodChannel() != null) {
                            if (MainActivity.activity != null) {
                                MainActivity.activity.onHangUpCall();
                            }

                            Engine.Instance().getMethodChannel().invokeMethod("callState", "CLOSED");
                            MptCallkitPlugin.sendToFlutter("callState", "CLOSED");
                            System.out.println("SDK-Android: callState - " + "CLOSED");
                        }

                        System.out.println("SDK-Android: lineName= " + currentLine.lineName + ": Hang up");
                        break;
                }
            }
        } catch (Exception e) {
            System.out.println("SDK-Android: Error during hangup: " + e.getMessage());
        } finally {
            if (currentLine != null) {
                currentLine.Reset();
            }
        }
    }

    void holdCall() {
        Session currentLine = CallManager.Instance().getCurrentSession();

        if (currentLine != null && currentLine.sessionID > 0) {
            int rt = Engine.Instance().getEngine().hold(currentLine.sessionID);

            if (rt != 0) {
                currentLine.bHold = false;
                System.out.println("SDK-Android: Hold call failed");
                return;
            }
            currentLine.bHold = true;
            System.out.println("SDK-Android: Hold call success");
            Engine.Instance().getMethodChannel().invokeMethod("holdCallState", currentLine.bHold);
            MptCallkitPlugin.sendToFlutter("holdCallState", currentLine.bHold);
        }
    }

    void unHoldCall() {
        Session currentLine = CallManager.Instance().getCurrentSession();
        if (currentLine != null && currentLine.sessionID > 0) {
            int result = Engine.Instance().getEngine().unHold(currentLine.sessionID);
            if (result != 0) {
                currentLine.bHold = false;
                System.out.println("SDK-Android: Unhold call failed");
                return;
            }
            currentLine.bHold = false;
            System.out.println("SDK-Android: Unhold call success");
            Engine.Instance().getMethodChannel().invokeMethod("holdCallState", currentLine.bHold);
            MptCallkitPlugin.sendToFlutter("holdCallState", currentLine.bHold);
        }
    }

    public static void muteMicrophone(boolean mute) {
        Session currentLine = CallManager.Instance().getCurrentSession();

        if (currentLine != null && currentLine.sessionID > 0) {
            currentLine.bMuteAudioOutGoing = mute;
            int result = Engine.Instance().getEngine().muteSession(
                    currentLine.sessionID,
                    currentLine.bMuteAudioInComing,
                    currentLine.bMuteAudioOutGoing,
                    false,
                    currentLine.bMuteVideo);
            System.out.println("SDK-Android: Mute call result: " + result);
            Engine.Instance().getMethodChannel().invokeMethod("microphoneState", currentLine.bMuteAudioOutGoing);
            MptCallkitPlugin.sendToFlutter("microphoneState", currentLine.bMuteAudioOutGoing);

            // Gửi tin nhắn với format mới
            String[] sessionInfo = getCurrentSessionInfo();
            sendCustomMessage(sessionInfo[0], sessionInfo[1], "update_media_state", "microphone", !mute);
        }
    }

    public static void toggleCameraOn(boolean enable) {
        Session currentLine = CallManager.Instance().getCurrentSession();
        if (currentLine != null && currentLine.sessionID > 0) {
            currentLine.bMuteVideo = !enable;
            Engine.Instance().getEngine().muteSession(
                    currentLine.sessionID,
                    currentLine.bMuteAudioInComing,
                    currentLine.bMuteAudioOutGoing,
                    false,
                    currentLine.bMuteVideo);
            Engine.Instance().getMethodChannel().invokeMethod("cameraState", enable);
            MptCallkitPlugin.sendToFlutter("cameraState", enable);

            // Gửi tin nhắn với format mới
            String[] sessionInfo = getCurrentSessionInfo();
            sendCustomMessage(sessionInfo[0], sessionInfo[1], "update_media_state", "camera", enable);
        }
    }

    public static boolean answerCall(boolean isAutoAnswer) {
        Session currentLine = CallManager.Instance().getCurrentSession();
        System.out.println("SDK-Android: Answer call currentLine: " + currentLine);
        System.out.println("SDK-Android: Answer call sessionID: " + currentLine.sessionID);
        System.out.println("SDK-Android: Answer call state: " + currentLine.state);
        Ring.getInstance(MainActivity.activity).stopRingTone();
        Ring.getInstance(MainActivity.activity).stopRingBackTone();
        if (currentLine != null && currentLine.sessionID > 0 && currentLine.state == Session.CALL_STATE_FLAG.INCOMING) {
            int result = Engine.Instance().getEngine().answerCall(currentLine.sessionID, currentLine.hasVideo);
            System.out.println("SDK-Android: Answer call with video: " + currentLine.hasVideo);
            System.out.println("SDK-Android: Answer call result: " + result);
            if (result == 0) {
                if (Engine.Instance().getMethodChannel() != null) {
                    Engine.Instance().getMethodChannel().invokeMethod("callState", "ANSWERED");
                    MptCallkitPlugin.sendToFlutter("callState", "ANSWERED");
                    System.out.println("SDK-Android: callState - ANSWERED");
                }
                currentLine.state = Session.CALL_STATE_FLAG.CONNECTED;
                Engine.Instance().getEngine().joinToConference(currentLine.sessionID);

                if (!isAutoAnswer) {
                    // Notice to remote
                    String[] sessionInfo = getCurrentSessionInfo();
                    sendCustomMessage(sessionInfo[0], sessionInfo[1], "call_state", "answered", true);
                }

                // re-invite to update video call
                reinviteSession(xSessionId);
            } else {
                System.out.println("SDK-Android: Answer call failed with error code: " + result);
            }
            return result == 0;
        } else {
            return false;
        }
    }

    void rejectCall() {
        Session currentLine = CallManager.Instance().getCurrentSession();
        if (currentLine != null && currentLine.sessionID > 0 && currentLine.state == Session.CALL_STATE_FLAG.INCOMING) {
            int result = Engine.Instance().getEngine().rejectCall(currentLine.sessionID, 486);
            System.out.println("SDK-Android" + currentLine.lineName + ": Rejected call");
            currentLine.Reset();
        }
    }

    boolean transfer(String destination) {
        Session currentLine = CallManager.Instance().getCurrentSession();
        if (currentLine == null || currentLine.sessionID <= 0
                || currentLine.state != Session.CALL_STATE_FLAG.CONNECTED) {
            System.out.println("SDK-Android: Cannot transfer - no active call");
            return false;
        }

        // Thực hiện chuyển cuộc gọi không cần tham vấn (Blind Transfer)
        int result = Engine.Instance().getEngine().refer(currentLine.sessionID, destination);

        if (result != 0) {
            System.out.println("SDK-Android: Transfer failed to " + destination + ", error code: " + result);
            return false;
        }

        System.out.println("SDK-Android: Call transfer initiated to " + destination);
        return true;
    }

    public static boolean reinviteSession(String sessionId) {
        Session currentLine = CallManager.Instance().getCurrentSession();
        System.out.println("SDK-Android: reInvite currentLine: " + currentLine);
        System.out.println("SDK-Android: reInvite sessionID: " + currentLine.sessionID);
        System.out.println("SDK-Android: reInvite sipMessage: " + currentLine.sipMessage);
        if (currentLine == null || currentLine.sessionID <= 0 || currentLine.sipMessage == null) {
            System.out.println("SDK-Android: Cannot reinvite - no active session or missing SIP message");
            return false;
        }

        System.out.println("SDK-Android: SIP message X-Session-Id: " + sessionId);

        // Lấy X-Session-Id từ sipMessage
        String messageSesssionId = Engine.Instance().getEngine()
                .getSipMessageHeaderValue(currentLine.sipMessage, "X-Session-Id").toString();

        boolean answerMode = Engine.Instance().getEngine()
                .getSipMessageHeaderValue(currentLine.sipMessage, "Answer-Mode").toString().equals("Auto;require");

        // So sánh với sessionId được truyền vào
        if (messageSesssionId.equals(sessionId) && !currentLine.hasVideo) {
            // Cập nhật trạng thái video của session
            currentLine.hasVideo = true;

            // Gửi video từ camera
            int sendVideoRes = Engine.Instance().getEngine().sendVideo(currentLine.sessionID, true);
            System.out.println("SDK-Android: reinviteSession - sendVideo(): " + sendVideoRes);

            // Cập nhật cuộc gọi để thêm video stream
            int updateRes = Engine.Instance().getEngine().updateCall(currentLine.sessionID, true, true);
            System.out.println("SDK-Android: reinviteSession - updateCall(): " + updateRes);

            System.out.println("SDK-Android: Successfully updated call with video for session: " + sessionId);
            return true;
        } else {
            System.out.println(
                    "SDK-Android: SessionId not match or already is video-call. SIP message ID: " + messageSesssionId
                            + ", Request: " + sessionId + ", has video before: " + currentLine.hasVideo);
            return false;
        }
    }

    boolean switchCamera() {
        boolean value = !Engine.Instance().mUseFrontCamera;
        setCamera(Engine.Instance().getEngine(), value);
        Engine.Instance().mUseFrontCamera = value;

        // Gửi broadcast để thông báo LocalView cập nhật mirror
        // Camera trước: mirror = true, Camera sau: mirror = false
        if (context != null) {
            Intent updateMirrorIntent = new Intent("CAMERA_SWITCH_ACTION");
            updateMirrorIntent.putExtra("useFrontCamera", value);
            context.sendBroadcast(updateMirrorIntent);
            System.out.println("SDK-Android: Sent broadcast to update camera mirror: " + value);
        }

        // Log để debug
        System.out.println("SDK-Android: Camera switched to " + (value ? "front" : "back") + " with mirror: " + value);
        return value;
    }

    private void setCamera(PortSipSdk portSipLib, boolean userFront) {
        int deviceId = userFront ? 1 : 0;
        portSipLib.setVideoDeviceId(deviceId);
    }

    void setSpeaker(String state) {
        Session currentLine = CallManager.Instance().getCurrentSession();
        if (currentLine != null && currentLine.sessionID > 0) {
            System.out.println("SDK-Android: setSpeaker to " + state);
            PortSipEnumDefine.AudioDevice audioDevice = null;
            try {
                switch (state) {
                    case "EARPIECE":
                        audioDevice = PortSipEnumDefine.AudioDevice.EARPIECE;
                        break;
                    case "SPEAKER_PHONE":
                        audioDevice = PortSipEnumDefine.AudioDevice.SPEAKER_PHONE;
                        break;
                    case "BLUETOOTH":
                        audioDevice = PortSipEnumDefine.AudioDevice.BLUETOOTH;
                        break;
                    case "WIRED_HEADSET":
                        audioDevice = PortSipEnumDefine.AudioDevice.WIRED_HEADSET;
                        break;
                    default:
                        System.out.println("SDK-Android: Invalid speaker state: " + state);
                        return;
                }

                // Check available audio devices
                Set<PortSipEnumDefine.AudioDevice> availableDevices = Engine.Instance().getEngine().getAudioDevices();
                if (availableDevices.contains(audioDevice)) {
                    CallManager.Instance().setAudioDevice(Engine.Instance().getEngine(), audioDevice);
                    // Gửi thông báo về thiết bị âm thanh hiện tại cho Flutter
                    Engine.Instance().getMethodChannel().invokeMethod("currentAudioDevice", state);
                    MptCallkitPlugin.sendToFlutter("currentAudioDevice", state);
                    System.out.println("SDK-Android: Audio device set to " + state);
                } else {
                    System.out.println("SDK-Android: Audio device " + state + " is not available. Available devices: "
                            + availableDevices);
                }
            } catch (Exception e) {
                System.out.println("SDK-Android: Error setting audio device: " + e.getMessage());
                e.printStackTrace();
            }
        } else {
            System.out.println("SDK-Android: No active call to set speaker status");
        }
    }

    void getAudioDevices() {
        Set<PortSipEnumDefine.AudioDevice> deviceSet = Engine.Instance().getEngine().getAudioDevices();
        List<String> deviceNames = new ArrayList<>();
        for (PortSipEnumDefine.AudioDevice device : deviceSet) {
            deviceNames.add(device.name());
        }

        System.out.println("SDK-Android: audio devices available: " + deviceNames);
        Engine.Instance().getMethodChannel().invokeMethod("audioDevices", deviceNames);
        MptCallkitPlugin.sendToFlutter("audioDevices", deviceNames);

        // Gửi thông báo về thiết bị âm thanh hiện tại
        PortSipEnumDefine.AudioDevice currentDevice = CallManager.Instance().getCurrentAudioDevice();
        if (currentDevice != null) {
            String currentDeviceName = currentDevice.name();
            Engine.Instance().getMethodChannel().invokeMethod("currentAudioDevice", currentDeviceName);
            MptCallkitPlugin.sendToFlutter("currentAudioDevice", currentDeviceName);
        }
    }

    /**
     * Gửi tin nhắn với format JSON mới
     * 
     * @param xSessionId   ID của session
     * @param extension    Extension number
     * @param type         Loại message (update_media_state, etc.)
     * @param payloadKey   Key của payload
     * @param payloadValue Value của payload
     */
    public static void sendCustomMessage(String xSessionId, String extension, String type, String payloadKey,
            Object payloadValue) {
        Session currentLine = CallManager.Instance().getCurrentSession();
        PortSipSdk portSipSdk = Engine.Instance().getEngine();

        if (currentLine != null && currentLine.sessionID > 0) {
            try {
                // Tạo payload object
                JSONObject payload = new JSONObject();
                payload.put(payloadKey, payloadValue);

                // Tạo message object
                JSONObject message = new JSONObject();
                message.put("sessionId", xSessionId);
                message.put("extension", extension);
                message.put("type", type);
                message.put("payload", payload);

                String msg = message.toString();
                System.out.println("SDK-Android: Sending custom message: " + msg);

                long resSendMsg = portSipSdk.sendMessage(currentLine.sessionID, "text", "plain",
                        msg.getBytes(StandardCharsets.UTF_8), msg.length());
                System.out.println("SDK-Android: Send custom message result: " + resSendMsg);
            } catch (Exception e) {
                System.out.println("SDK-Android: Error creating custom message: " + e.getMessage());
                e.printStackTrace();
            }
        }
    }

    /**
     * Helper method để lấy session ID và extension hiện tại
     */
    private static String[] getCurrentSessionInfo() {
        Session currentLine = CallManager.Instance().getCurrentSession();
        String sessionId = Engine.Instance().getEngine()
                .getSipMessageHeaderValue(currentLine.sipMessage, "X-Session-Id")
                .toString() != null
                        ? Engine.Instance().getEngine()
                                .getSipMessageHeaderValue(currentLine.sipMessage, "X-Session-Id").toString()
                        : "empty_X_Session_Id";
        String extension = currentUsername != null ? currentUsername : "unknown";
        return new String[] { sessionId, extension };
    }
}
