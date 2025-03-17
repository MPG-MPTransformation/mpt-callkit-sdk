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

public class MptCallkitPlugin implements FlutterPlugin, MethodCallHandler, ActivityAware {

    /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  public Context context;
    public Activity activity;
    public String pushToken = "e3TKpdmDSJqzW20HYsDe9h:APA91bFdWS9ALxW1I7Zuq7uXsYTL6-8F-A3AARhcrLMY6pB6ecUbWX7RbABnLrzCGjGBWIxJ8QaCQkwkOjrv2BOJjEGfFgIGjlIekFqKQR-dtutszyRLZy1Im6KXNIqDzicWIGKdbcWD";
    public String APPID = "com.portsip.sipsample";
    private MethodChannel.Result pendingResult;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
        System.out.println("quanth: onAttachedToEngine");
        Engine.Instance().setMethodChannel(new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "mpt_callkit"));
        Engine.Instance().getMethodChannel().setMethodCallHandler(this);
        context = flutterPluginBinding.getApplicationContext();
        Engine.Instance().setEngine(new PortSipSdk(context));
        Engine.Instance().setReceiver(new PortMessageReceiver());
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        System.out.println("quanth: onMethodCall" + call.method);
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
                muteCall(true);
                break;
            case "unmute":
                muteCall(false);
                break;
            case "cameraOn":
                toggleCamera(true);
                break;
            case "cameraOff":
                toggleCamera(false);
                break;
            case "answer":
                answerCall();
                break;
            case "reject":
                rejectCall();
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
                if (CallManager.Instance().online) {
                    Engine.Instance().getMethodChannel().invokeMethod("onlineStatus", true);
                } else {
                    Intent onLineIntent = new Intent(activity, PortSipService.class);
                    onLineIntent.setAction(PortSipService.ACTION_SIP_REGIEST);
                    onLineIntent.putExtra("username", username);
                    onLineIntent.putExtra("password", password);
                    onLineIntent.putExtra("domain", userDomain);
                    onLineIntent.putExtra("sipServer", sipServer);
                    onLineIntent.putExtra("port", sipServerPort);
                    onLineIntent.putExtra("displayName", displayName);
                    PortSipService.startServiceCompatibility(context, onLineIntent);
                    System.out.println("quanth: RegisterServer..");
                }
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

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            activity.registerReceiver(Engine.Instance().getReceiver(), filter, Context.RECEIVER_EXPORTED);
        } else {
            activity.registerReceiver(Engine.Instance().getReceiver(), filter);
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
    }

    public void requestPermissions(Activity activity, MethodChannel.Result result) {
        if (PackageManager.PERMISSION_GRANTED != ActivityCompat.checkSelfPermission(activity, Manifest.permission.CAMERA)
                || PackageManager.PERMISSION_GRANTED != ActivityCompat.checkSelfPermission(activity, Manifest.permission.RECORD_AUDIO)) {
            System.out.println("quanth: request permission");
            pendingResult = result;
            ActivityCompat.requestPermissions(activity, new String[]{
                Manifest.permission.CAMERA,
                Manifest.permission.RECORD_AUDIO},
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
        //default send video
        Engine.Instance().getEngine().sendVideo(sessionId, isVideoCall);

        currentLine.remote = callTo;

        currentLine.sessionID = sessionId;
        currentLine.state = Session.CALL_STATE_FLAG.TRYING;
        currentLine.hasVideo = isVideoCall;
        System.out.println("quanth: line= " + currentLine.lineName + ": Calling...");
        return true;
    }

    void hangup() {
        Session currentLine = CallManager.Instance().getCurrentSession();
        Ring.getInstance(activity).stop();
        switch (currentLine.state) {
            case INCOMING:
                Engine.Instance().getEngine().rejectCall(currentLine.sessionID, 486);
                System.out.println("quanth: lineName= " + currentLine.lineName + ": Rejected call");
                break;
            case CONNECTED:
            case TRYING:
                Engine.Instance().getEngine().hangUp(currentLine.sessionID);
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
        }
    }

    void unHoldCall() {
        Session currentLine = CallManager.Instance().getCurrentSession();
        if (currentLine != null && currentLine.sessionID > 0 && currentLine.bHold) {
            int result = Engine.Instance().getEngine().unHold(currentLine.sessionID);
            if (result != 0) {
                currentLine.bHold = false;
                System.out.println("quanth: Unhold call failed");
                return;
            }
            currentLine.bHold = false;
            System.out.println("quanth: Unhold call success");
        }
    }

    void muteCall(boolean mute) {
        Session currentLine = CallManager.Instance().getCurrentSession();
        if (currentLine != null && currentLine.sessionID > 0) {
            int result = Engine.Instance().getEngine().muteSession(currentLine.sessionID, !mute, !mute, !mute, !mute);
            System.out.println("quanth: Mute call result: " + result);
            currentLine.bMute = !currentLine.bMute;
        }
    }

    void toggleCamera(boolean enable) {
        Session currentLine = CallManager.Instance().getCurrentSession();
        if (currentLine != null && currentLine.sessionID > 0) {
            currentLine.bMuteVideo = !enable;
            Engine.Instance().getEngine().muteSession(currentLine.sessionID, currentLine.bMute, currentLine.bMute, currentLine.bMute, currentLine.bMute);
        }
    }

    void answerCall() {
        Session currentLine = CallManager.Instance().getCurrentSession();
        if (currentLine != null && currentLine.sessionID > 0 && currentLine.state == Session.CALL_STATE_FLAG.INCOMING) {
            int result = Engine.Instance().getEngine().answerCall(currentLine.sessionID, true);
            System.out.println("quanth: Answer call result: " + result);
            if (result != 0) {
                currentLine.state = Session.CALL_STATE_FLAG.CONNECTED;
                Engine.Instance().getEngine().joinToConference(currentLine.sessionID);
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
        if (currentLine == null || currentLine.sessionID <= 0 || currentLine.state != Session.CALL_STATE_FLAG.CONNECTED) {
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
}
