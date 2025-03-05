package com.mpt.mpt_callkit;

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
import java.net.HttpURLConnection;
import java.net.URL;
import java.io.OutputStream;
import java.io.BufferedReader;
import java.io.InputStreamReader;
import org.json.JSONObject;

/**
 * PortsipFlutterPlugin
 */
public class MptCallkitPlugin implements FlutterPlugin, MethodCallHandler, ActivityAware {

    /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private Activity activity;
    private Context context;
    private FlutterPluginBinding flutterPluginBinding;
    public String pushToken = "e3TKpdmDSJqzW20HYsDe9h:APA91bFdWS9ALxW1I7Zuq7uXsYTL6-8F-A3AARhcrLMY6pB6ecUbWX7RbABnLrzCGjGBWIxJ8QaCQkwkOjrv2BOJjEGfFgIGjlIekFqKQR-dtutszyRLZy1Im6KXNIqDzicWIGKdbcWD";
    public String APPID = "com.portsip.sipsample";
    private MethodChannel.Result pendingResult;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
        this.flutterPluginBinding = flutterPluginBinding;
        context = flutterPluginBinding.getApplicationContext();
        Engine.Instance().setMethodChannel(new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "mpt_callkit"));

        // Đăng ký VideoViewFactory với activity
        if (activity != null) {
            flutterPluginBinding.getPlatformViewRegistry().registerViewFactory(
                    "VideoView",
                    new VideoViewFactory(activity)
            );
        }

        Engine.Instance().getMethodChannel().setMethodCallHandler(this);
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
            // case "call":
            //   String phoneNumber = call.argument("phoneNumber");
            //   boolean hasVideoCall = call.argument("isVideoCall");
            //   boolean callResult = makeCall(phoneNumber, hasVideoCall);
            //   result.success(callResult);
            //   break;

            case "requestPermission":
                requestPermissions(activity, result);
                break;
            case "openAppSetting":
                openAppSetting();
                break;
            // case "appKilled":
            //   stopIntent = new Intent(activity, PortSipService.class);
            //   stopIntent.setAction(PortSipService.ACTION_STOP);
            //   PortSipService.startServiceCompatibility(activity, stopIntent);
            //   if(MainActivity.activity.receiver != null) {
            //     MainActivity.activity.unregisterReceiver(MainActivity.activity.receiver);
            //     MainActivity.activity.receiver = null;
            //   }
            //   MainActivity.activity.finish();
            //   hangup();
            //   activity.finishAndRemoveTask();
            case "hangup":
                hangup();
                break;
            // case "startActivity":
            //   myIntent = new Intent(activity, MainActivity.class);
            //   myIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            //   activity.startActivity(myIntent);
            //   break;

            case "finishActivity":
                System.out.println("quanth: finishActivity");
                stopIntent = new Intent(activity, PortSipService.class);
                stopIntent.setAction(PortSipService.ACTION_STOP);
                PortSipService.startServiceCompatibility(activity, stopIntent);

                if (activity != null && Engine.Instance().getReceiver() != null) {
                    try {
                        activity.unregisterReceiver(Engine.Instance().getReceiver());
                        System.out.println("quanth: Unregistered PortMessageReceiver in finishActivity");
                    } catch (Exception e) {
                        System.out.println("quanth: Error unregistering receiver: " + e.getMessage());
                    }
                }
                if (MainActivity.activity != null) {
                    MainActivity.activity.finish();
                }
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
                boolean isVideoCall = call.argument("isVideoCall");
                String sipServerPort = call.argument("sipServerPort") + "";
                String phoneNumber = call.argument("phoneNumber");
                String baseUrl = call.argument("baseUrl");

                CallManager.Instance().getRegistrationStateStream().subscribe(value -> {
                    if (value.equals("registerSuccess")) {
                        // Thực hiện cuộc gọi
                        boolean callResult = makeCall(phoneNumber, isVideoCall);
                        if (!callResult) {
                            // Nếu cuộc gọi thất bại
                            System.out.println("quanth: call has failed");
                            Engine.Instance().getMethodChannel().invokeMethod("onBusy", true);
                            // Offline và đóng màn hình
                            Intent offIntent = new Intent(activity, PortSipService.class);
                            offIntent.setAction(PortSipService.ACTION_SIP_UNREGIEST);
                            PortSipService.startServiceCompatibility(activity, offIntent);
                            // activity.finish();
                        }
                    } else {
                        System.out.println("quanth: registration has failed!");
                        // activity.finish();
                        // release extension
                        Engine.Instance().getMethodChannel().invokeMethod("onHangOut", true);
                    }
                });

                if (CallManager.Instance().online) {
                    // Toast.makeText(activity,"Please OffLine First",Toast.LENGTH_SHORT).show();
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
        flutterPluginBinding = null;
        Engine.Instance().setEngine(null);
        Engine.Instance().getMethodChannel().setMethodCallHandler(null);
    }

    @Override
    public void onAttachedToActivity(ActivityPluginBinding activityPluginBinding) {
        activity = activityPluginBinding.getActivity();
        // Đăng ký lại VideoViewFactory khi có activity
        if (activity != null && flutterPluginBinding != null) {
            flutterPluginBinding.getPlatformViewRegistry().registerViewFactory(
                    "VideoView",
                    new VideoViewFactory(activity)
            );
        }
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
        // Unregister receiver when activity is detached for config changes
        if (activity != null && Engine.Instance().getReceiver() != null) {
            try {
                activity.unregisterReceiver(Engine.Instance().getReceiver());
                System.out.println("quanth: Unregistered PortMessageReceiver for config changes");
            } catch (Exception e) {
                System.out.println("quanth: Error unregistering receiver: " + e.getMessage());
            }
        }
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
        // Unregister receiver when activity is detached
        if (activity != null && Engine.Instance().getReceiver() != null) {
            try {
                activity.unregisterReceiver(Engine.Instance().getReceiver());
                System.out.println("quanth: Unregistered PortMessageReceiver");
            } catch (Exception e) {
                System.out.println("quanth: Error unregistering receiver: " + e.getMessage());
            }
        }
        activity = null;
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

}
