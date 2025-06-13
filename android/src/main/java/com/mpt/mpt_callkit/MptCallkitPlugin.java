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

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
        System.out.println("quanth: onAttachedToEngine");
        Engine.Instance().setMethodChannel(new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "mpt_callkit"));
        Engine.Instance().getMethodChannel().setMethodCallHandler(this);
        context = flutterPluginBinding.getApplicationContext();
        Engine.Instance().setEngine(new PortSipSdk(context));
        Engine.Instance().setReceiver(new PortMessageReceiver());

        // Đăng ký LocalViewFactory
        flutterPluginBinding
                .getPlatformViewRegistry()
                .registerViewFactory("LocalView", new LocalViewFactory(context));
        flutterPluginBinding
                .getPlatformViewRegistry()
                .registerViewFactory("RemoteView", new RemoteViewFactory(context));
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
        System.out.println("quanth: onMethodCall " + call.method);
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
                System.out.println("quanth: UnregisterServer..");
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
                answerCall();
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
                System.out.println("quanth: finishActivity");
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
                if (CallManager.Instance().online) {
                    System.out.println("quanth: Already online");
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
                    System.out.println("quanth: RegisterServer..");
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
                String sessionId = call.argument("sessionId");
                boolean reinviteResult = reinviteSession(sessionId);
                result.success(reinviteResult);
                break;
            case "updateVideoCall":
                Session currentLine = CallManager.Instance().getCurrentSession();
                Boolean isVideo = call.argument("isVideo");
                // Gửi video từ camera
                int sendVideoResult = Engine.Instance().getEngine().sendVideo(currentLine.sessionID, isVideo);
                System.out.println("quanth: reinviteSession - sendVideo(): " + sendVideoResult);

                // Cập nhật cuộc gọi để thêm video stream
                int updateCallRes = Engine.Instance().getEngine().updateCall(currentLine.sessionID, true, isVideo);
                System.out.println("quanth: reinviteSession - updateCall(): " + updateCallRes);

                result.success(updateCallRes == 0);
                break;
            default:
                result.notImplemented();
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
        System.out.println("quanth: onAttachedToActivity");
        activity = activityPluginBinding.getActivity();
        IntentFilter filter = new IntentFilter();
        filter.addAction(PortSipService.REGISTER_CHANGE_ACTION);
        filter.addAction(PortSipService.CALL_CHANGE_ACTION);
        filter.addAction(PortSipService.PRESENCE_CHANGE_ACTION);
        filter.addAction(PortSipService.ACTION_SIP_AUDIODEVICE);
        filter.addAction(PortSipService.ACTION_HANGOUT_SUCCESS);
        System.out.println("quanth: Registering broadcast receiver for call actions");

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            activity.registerReceiver(Engine.Instance().getReceiver(), filter, Context.RECEIVER_EXPORTED);
            System.out.println("quanth: Registered with RECEIVER_EXPORTED flag");
        } else {
            activity.registerReceiver(Engine.Instance().getReceiver(), filter);
            System.out.println("quanth: Registered without RECEIVER_EXPORTED flag");
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
        System.out.println("quanth: onDetachedFromActivityForConfigChanges");
    }

    @Override
    public void onReattachedToActivityForConfigChanges(ActivityPluginBinding activityPluginBinding) {
        // TODO: your plugin is now attached to a new Activity
        // after a configuration change.
        activity = activityPluginBinding.getActivity();
        System.out.println("quanth: onReattachedToActivityForConfigChanges");
    }

    @Override
    public void onDetachedFromActivity() {
        // TODO: your plugin is no longer associated with an Activity.
        // Clean up references.
        System.out.println("quanth: onDetachedFromActivity");
        // Unregister SIP khi app bị destroy
        unregisterSipAndCleanup();
    }

    private void unregisterSipAndCleanup() {
        if (CallManager.Instance().online) {
            // Unregister SIP
            Engine.Instance().getEngine().unRegisterServer(100);
            Engine.Instance().getEngine().removeUser();
            Engine.Instance().getEngine().unInitialize();

            // Reset các trạng thái
            CallManager.Instance().online = false;
            CallManager.Instance().isRegistered = false;

            // Dọn dẹp resources
            if (activity != null && Engine.Instance().getReceiver() != null) {
                try {
                    activity.unregisterReceiver(Engine.Instance().getReceiver());
                } catch (Exception e) {
                    System.out.println("quanth: Error unregistering receiver: " + e.getMessage());
                }
            }

            // Stop service nếu đang chạy
            if (context != null) {
                context.stopService(new Intent(context, PortSipService.class));
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
            System.out.println("quanth: request permission");
            pendingResult = result;
            ActivityCompat.requestPermissions(activity,
                    permissions.toArray(new String[0]),
                    REQ_DANGERS_PERMISSION);
            return;
        }

        result.success(true);
        System.out.println("quanth: no need request permission");
    }

    private final int REQ_DANGERS_PERMISSION = 2;

    boolean makeCall(String phoneNumber, boolean isVideoCall) {
        Session currentLine = CallManager.Instance().getCurrentSession();
        String callTo = phoneNumber;
        if (!currentLine.IsIdle()) {
            System.out.println("quanth: Current line is busy now, please switch a line.");
            return false;
        }

        // Ensure that we have been added one audio codec at least
        if (Engine.Instance().getEngine().isAudioCodecEmpty()) {
            System.out.println("quanth: Audio Codec Empty,add audio codec at first");
            return false;
        }

        // Usually for 3PCC need to make call without SDP
        long sessionId = Engine.Instance().getEngine().call(callTo, true, isVideoCall);
        if (sessionId <= 0) {
            System.out.println("quanth: Call failure");
            return false;
        }
        // default send video
        Engine.Instance().getEngine().sendVideo(sessionId, isVideoCall);

        currentLine.remote = callTo;

        currentLine.sessionID = sessionId;
        currentLine.state = Session.CALL_STATE_FLAG.TRYING;
        currentLine.hasVideo = isVideoCall;
        System.out.println("quanth: line= " + currentLine.lineName + ": Calling...");
        return true;
    }

    static void hangup() {
        Session currentLine = CallManager.Instance().getCurrentSession();
        Ring.getInstance(MainActivity.activity).stop();
        switch (currentLine.state) {
            case INCOMING:
                Engine.Instance().getEngine().rejectCall(currentLine.sessionID, 486);
                System.out.println("quanth: lineName= " + currentLine.lineName + ": Rejected call");

                Engine.Instance().getMethodChannel().invokeMethod("callState", "CLOSED");
                MptCallkitPlugin.sendToFlutter("callState", "CLOSED");
                System.out.println("quanth: callState - " + "CLOSED");

                break;
            case CONNECTED:
            case TRYING:
                Engine.Instance().getEngine().hangUp(currentLine.sessionID);

                if (Engine.Instance().getMethodChannel() != null) {
                    Engine.Instance().getMethodChannel().invokeMethod("callState", "CLOSED");
                    MptCallkitPlugin.sendToFlutter("callState", "CLOSED");
                    System.out.println("quanth: callState - " + "CLOSED");
                }

                System.out.println("quanth: lineName= " + currentLine.lineName + ": Hang up");
                break;
        }
        currentLine.Reset();
    }

    void holdCall() {
        Session currentLine = CallManager.Instance().getCurrentSession();

        if (currentLine != null && currentLine.sessionID > 0) {
            int rt = Engine.Instance().getEngine().hold(currentLine.sessionID);

            if (rt != 0) {
                currentLine.bHold = false;
                System.out.println("quanth: Hold call failed");
                return;
            }
            currentLine.bHold = true;
            System.out.println("quanth: Hold call success");
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
                System.out.println("quanth: Unhold call failed");
                return;
            }
            currentLine.bHold = false;
            System.out.println("quanth: Unhold call success");
            Engine.Instance().getMethodChannel().invokeMethod("holdCallState", currentLine.bHold);
            MptCallkitPlugin.sendToFlutter("holdCallState", currentLine.bHold);
        }
    }

    public static void muteMicrophone(boolean mute) {
        Session currentLine = CallManager.Instance().getCurrentSession();
        PortSipSdk portSipSdk = Engine.Instance().getEngine();

        if (currentLine != null && currentLine.sessionID > 0) {
            currentLine.bMuteAudioOutGoing = mute;
            int result = Engine.Instance().getEngine().muteSession(
                    currentLine.sessionID,
                    currentLine.bMuteAudioInComing,
                    currentLine.bMuteAudioOutGoing,
                    false,
                    currentLine.bMuteVideo);
            System.out.println("quanth: Mute call result: " + result);
            Engine.Instance().getMethodChannel().invokeMethod("microphoneState", currentLine.bMuteAudioOutGoing);
            MptCallkitPlugin.sendToFlutter("microphoneState", currentLine.bMuteAudioOutGoing);

            HashMap<String, String> msgMap = new HashMap<>();
            msgMap.put("name", "Error");
            msgMap.put("message", "hello");

            JSONObject jsonMsg = new JSONObject(msgMap);
            String msg = jsonMsg.toString();

            long resSendMsg = portSipSdk.sendMessage(currentLine.sessionID, "text", "plain",
                    msg.getBytes(StandardCharsets.UTF_8), msg.length());
            System.out.println("quanth: Send message: " + resSendMsg);
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
        }
    }

    void answerCall() {
        Session currentLine = CallManager.Instance().getCurrentSession();
        System.out.println("quanth: Answer call currentLine: " + currentLine);
        System.out.println("quanth: Answer call sessionID: " + currentLine.sessionID);
        System.out.println("quanth: Answer call state: " + currentLine.state);
        if (currentLine != null && currentLine.sessionID > 0 && currentLine.state == Session.CALL_STATE_FLAG.INCOMING) {
            int result = Engine.Instance().getEngine().answerCall(currentLine.sessionID, currentLine.hasVideo);
            System.out.println("quanth: Answer call with video: " + currentLine.hasVideo);
            System.out.println("quanth: Answer call result: " + result);
            if (result == 0) {
                if (Engine.Instance().getMethodChannel() != null) {
                    Engine.Instance().getMethodChannel().invokeMethod("callState", "ANSWERED");
                    MptCallkitPlugin.sendToFlutter("callState", "ANSWERED");
                    System.out.println("quanth: callState - ANSWERED");
                }
                currentLine.state = Session.CALL_STATE_FLAG.CONNECTED;
                Engine.Instance().getEngine().joinToConference(currentLine.sessionID);
            } else {
                System.out.println("quanth: Answer call failed with error code: " + result);
            }
        }
    }

    void rejectCall() {
        Session currentLine = CallManager.Instance().getCurrentSession();
        if (currentLine != null && currentLine.sessionID > 0 && currentLine.state == Session.CALL_STATE_FLAG.INCOMING) {
            int result = Engine.Instance().getEngine().rejectCall(currentLine.sessionID, 486);
            System.out.println("quanth:" + currentLine.lineName + ": Rejected call");
            currentLine.Reset();
        }
    }

    boolean transfer(String destination) {
        Session currentLine = CallManager.Instance().getCurrentSession();
        if (currentLine == null || currentLine.sessionID <= 0
                || currentLine.state != Session.CALL_STATE_FLAG.CONNECTED) {
            System.out.println("quanth: Cannot transfer - no active call");
            return false;
        }

        // Thực hiện chuyển cuộc gọi không cần tham vấn (Blind Transfer)
        int result = Engine.Instance().getEngine().refer(currentLine.sessionID, destination);

        if (result != 0) {
            System.out.println("quanth: Transfer failed to " + destination + ", error code: " + result);
            return false;
        }

        System.out.println("quanth: Call transfer initiated to " + destination);
        return true;
    }

    boolean reinviteSession(String sessionId) {
        Session currentLine = CallManager.Instance().getCurrentSession();
        System.out.println("quanth: reInvite currentLine: " + currentLine);
        System.out.println("quanth: reInvite sessionID: " + currentLine.sessionID);
        System.out.println("quanth: reInvite sipMessage: " + currentLine.sipMessage);
        if (currentLine == null || currentLine.sessionID <= 0 || currentLine.sipMessage == null) {
            System.out.println("quanth: Cannot reinvite - no active session or missing SIP message");
            return false;
        }

        System.out.println("quanth: SIP message Session-Id: " + sessionId);

        // Lấy X-Session-Id từ sipMessage
        String messageSesssionId = Engine.Instance().getEngine()
                .getSipMessageHeaderValue(currentLine.sipMessage, "X-Session-Id").toString();

        boolean answerMode = Engine.Instance().getEngine()
                .getSipMessageHeaderValue(currentLine.sipMessage, "Answer-Mode").toString().equals("Auto;require");

        // So sánh với sessionId được truyền vào
        if (messageSesssionId.equals(sessionId) && answerMode) {
            // Cập nhật trạng thái video của session
            currentLine.hasVideo = true;

            // Gửi video từ camera
            int sendVideoRes = Engine.Instance().getEngine().sendVideo(currentLine.sessionID, true);
            System.out.println("quanth: reinviteSession - sendVideo(): " + sendVideoRes);

            // Cập nhật cuộc gọi để thêm video stream
            int updateRes = Engine.Instance().getEngine().updateCall(currentLine.sessionID, true, true);
            System.out.println("quanth: reinviteSession - updateCall(): " + updateRes);

            System.out.println("quanth: Successfully updated call with video for session: " + sessionId);
            return true;
        } else {
            System.out.println(
                    "quanth: SessionId not match or not is Answer-Mode. SIP message ID: " + messageSesssionId
                            + ", Request: " + sessionId + ", Answer-Mode: " + answerMode);
            return false;
        }
    }

    boolean switchCamera() {
        boolean value = !Engine.Instance().mUseFrontCamera;
        SetCamera(Engine.Instance().getEngine(), value);
        Engine.Instance().mUseFrontCamera = value;

        // Log để debug
        System.out.println("quanth: Camera switched to " + (value ? "front" : "back"));
        return value;
    }

    private void SetCamera(PortSipSdk portSipLib, boolean userFront) {
        if (userFront) {
            portSipLib.setVideoDeviceId(0);
        } else {
            portSipLib.setVideoDeviceId(1);
        }
    }

    void setSpeaker(String state) {
        Session currentLine = CallManager.Instance().getCurrentSession();
        if (currentLine != null && currentLine.sessionID > 0) {
            System.out.println("quanth: setSpeaker to " + state);
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
                        System.out.println("quanth: Invalid speaker state: " + state);
                        return;
                }

                // Check available audio devices
                Set<PortSipEnumDefine.AudioDevice> availableDevices = Engine.Instance().getEngine().getAudioDevices();
                if (availableDevices.contains(audioDevice)) {
                    CallManager.Instance().setAudioDevice(Engine.Instance().getEngine(), audioDevice);
                    // Gửi thông báo về thiết bị âm thanh hiện tại cho Flutter
                    Engine.Instance().getMethodChannel().invokeMethod("currentAudioDevice", state);
                    MptCallkitPlugin.sendToFlutter("currentAudioDevice", state);
                    System.out.println("quanth: Audio device set to " + state);
                } else {
                    System.out.println("quanth: Audio device " + state + " is not available. Available devices: "
                            + availableDevices);
                }
            } catch (Exception e) {
                System.out.println("quanth: Error setting audio device: " + e.getMessage());
                e.printStackTrace();
            }
        } else {
            System.out.println("quanth: No active call to set speaker status");
        }
    }

    void getAudioDevices() {
        Set<PortSipEnumDefine.AudioDevice> deviceSet = Engine.Instance().getEngine().getAudioDevices();
        List<String> deviceNames = new ArrayList<>();
        for (PortSipEnumDefine.AudioDevice device : deviceSet) {
            deviceNames.add(device.name());
        }

        System.out.println("quanth: audio devices available: " + deviceNames);
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
}
