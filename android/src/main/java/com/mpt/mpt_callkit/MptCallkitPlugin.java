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
import android.content.SharedPreferences;
import android.preference.PreferenceManager;
import android.graphics.Bitmap;
import com.mpt.mpt_callkit.segmentation.VisionImageProcessorCallback;
import com.mpt.mpt_callkit.segmentation.CameraSource;
import com.mpt.mpt_callkit.segmentation.SegmenterProcessor;

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
import java.io.File;
import java.io.FileOutputStream;
import java.io.FileDescriptor;
import java.io.OutputStream;
import java.io.PrintStream;
import java.io.IOException;
import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.lang.Process;
import java.lang.ProcessBuilder;

public class MptCallkitPlugin implements FlutterPlugin, MethodCallHandler, ActivityAware, VisionImageProcessorCallback {

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
    private  String appId;
    private  String pushToken;
    private static volatile boolean fileLoggingEnabled = false;
    private static FileOutputStream logFileStream;
    private static PrintStream originalOut;
    private static PrintStream originalErr;
    private static class LinePrefixingOutputStream extends OutputStream {
        private final OutputStream delegate;
        private final String platformTag;
        private boolean startOfLine = true;
        LinePrefixingOutputStream(OutputStream delegate, String platformTag) {
            this.delegate = delegate;
            this.platformTag = platformTag;
        }
        @Override
        public synchronized void write(int b) throws IOException {
            if (startOfLine) {
                String prefix = "[" + getTimestamp() + "] [" + platformTag + "] ";
                delegate.write(prefix.getBytes());
                startOfLine = false;
            }
            delegate.write(b);
            if (b == '\n') {
                startOfLine = true;
            }
        }
        @Override
        public synchronized void write(byte[] b, int off, int len) throws IOException {
            int end = off + len;
            for (int i = off; i < end; i++) {
                write(b[i]);
            }
        }
        @Override
        public void flush() throws IOException { delegate.flush(); }
    }

    private static String getTimestamp() {
        java.text.SimpleDateFormat sdf = new java.text.SimpleDateFormat("ddMMyy-HHmmss.SSS");
        return sdf.format(new java.util.Date());
    }
    private static Process logcatProcess;
    private static Thread logcatThread;

    public static MptCallkitPlugin shared = new MptCallkitPlugin();
    private Boolean answeredWithCallKit = false;
    private SharedPreferences preferences;
    private SharedPreferences.Editor editor;
    private boolean socketReady = false;
    private static LocalViewFactory localViewFactory;

    private CameraSource cameraSource = null;
    private boolean isStartCameraSource = false;
    private static String recordLabel = "Agent";
    private static boolean enableBlurBackground = false;
    private SegmenterProcessor segmenterProcessor;

    public MptCallkitPlugin() {
        System.out.println("SDK-Android: MptCallkitPlugin constructor");
    }

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
        System.out.println("SDK-Android: onAttachedToEngine");
        Engine.Instance().setMethodChannel(new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "mpt_callkit"));
        if (Engine.Instance().getMethodChannel() != null) {
            Engine.Instance().getMethodChannel().setMethodCallHandler(this);
        }
        context = flutterPluginBinding.getApplicationContext();
        // Activity will be set in onAttachedToActivity callback
        System.out.println("SDK-Android: Engine attached, waiting for activity attachment...");
        activity = null; // Will be set in onAttachedToActivity
        
        Engine.Instance().setEngine(new PortSipSdk(context));
        // Only create receiver if it doesn't exist
        if (Engine.Instance().getReceiver() == null) {
            Engine.Instance().setReceiver(new PortMessageReceiver());
        }

        MptCallkitPlugin.localViewFactory = new LocalViewFactory(context);
        // Đăng ký LocalViewFactory
        flutterPluginBinding
                .getPlatformViewRegistry()
                .registerViewFactory("LocalView", MptCallkitPlugin.localViewFactory);
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
        MptCallkitPlugin.shared = this;
        System.out.println("SDK-Android: onAttachedToEngine done");
    }

    private byte[] bitmapToYUVData(Bitmap bitmap) {
        int width = bitmap.getWidth();
        int height = bitmap.getHeight();
        
        // Require even dimensions for simple 4:2:0 sampling (matching iOS validation)
        if (width % 2 != 0 || height % 2 != 0) {
            throw new IllegalArgumentException("Width and height must be even for I420 conversion. Got: " + width + "x" + height);
        }
        
        // Get ARGB pixels from bitmap
        int[] argbPixels = new int[width * height];
        bitmap.getPixels(argbPixels, 0, width, 0, 0, width, height);
        
        // YUV420 (I420) format: Y plane + U plane + V plane
        int ySize = width * height;
        int uvWidth = width / 2;
        int uvHeight = height / 2;
        int uvSize = uvWidth * uvHeight;
        byte[] yuvData = new byte[ySize + uvSize * 2];
        
        // Plane pointers
        int yPlaneOffset = 0;
        int uPlaneOffset = ySize;
        int vPlaneOffset = ySize + uvSize;
        
        // Fill Y plane (full resolution) - BT.601 limited-range conversion
        for (int y = 0; y < height; y++) {
            int rowY = y * width;
            for (int x = 0; x < width; x++) {
                int argb = argbPixels[rowY + x];
                
                // Extract RGBA components with proper alpha handling
                int r = (argb >> 16) & 0xFF;
                int g = (argb >> 8) & 0xFF;
                int b = argb & 0xFF;
                int a = (argb >> 24) & 0xFF;
                
                // Handle premultiplied alpha (optimized like iOS)
                int actualR, actualG, actualB;
                if (a == 255) {
                    actualR = r;
                    actualG = g;
                    actualB = b;
                } else if (a > 0) {
                    actualR = Math.min(255, (r * 255) / a);
                    actualG = Math.min(255, (g * 255) / a);
                    actualB = Math.min(255, (b * 255) / a);
                } else {
                    actualR = 0;
                    actualG = 0;
                    actualB = 0;
                }
                
                // BT.601 limited-range Y conversion (matching iOS)
                int yValue = (66 * actualR + 129 * actualG + 25 * actualB + 128) >> 8;
                yuvData[yPlaneOffset + rowY + x] = (byte) Math.max(16, Math.min(235, yValue + 16));
            }
        }
        
        // Fill U and V planes (4:2:0, average 2x2 blocks) - optimized like iOS
        for (int j = 0; j < uvHeight; j++) {
            int uvRowIndex = j * uvWidth;
            for (int i = 0; i < uvWidth; i++) {
                int rSum = 0, gSum = 0, bSum = 0;
                int baseX = i * 2;
                int baseY = j * 2;
                
                // Average 2x2 block (unrolled for performance)
                for (int dy = 0; dy < 2; dy++) {
                    int rowOffset = (baseY + dy) * width;
                    for (int dx = 0; dx < 2; dx++) {
                        int argb = argbPixels[rowOffset + baseX + dx];
                        
                        int r = (argb >> 16) & 0xFF;
                        int g = (argb >> 8) & 0xFF;
                        int b = argb & 0xFF;
                        int a = (argb >> 24) & 0xFF;
                        
                        // Optimized alpha handling
                        if (a == 255) {
                            rSum += r;
                            gSum += g;
                            bSum += b;
                        } else if (a > 0) {
                            rSum += Math.min(255, (r * 255) / a);
                            gSum += Math.min(255, (g * 255) / a);
                            bSum += Math.min(255, (b * 255) / a);
                        }
                    }
                }
                
                // Average the 2x2 block (divide by 4 using bit shift)
                rSum >>= 2;
                gSum >>= 2;
                bSum >>= 2;
                
                // BT.601 limited-range U and V conversion (matching iOS)
                int uVal = ((-38 * rSum - 74 * gSum + 112 * bSum + 128) >> 8) + 128;
                int vVal = ((112 * rSum - 94 * gSum - 18 * bSum + 128) >> 8) + 128;
                
                int uvIndex = uvRowIndex + i;
                yuvData[uPlaneOffset + uvIndex] = (byte) Math.max(16, Math.min(240, uVal));
                yuvData[vPlaneOffset + uvIndex] = (byte) Math.max(16, Math.min(240, vVal));
            }
        }
        
        return yuvData;
    }

    @Override
    public void onDetectionSuccess(Bitmap bitmap, long frameStartMs) {
        if (MptCallkitPlugin.localViewFactory != null) {
            MptCallkitPlugin.localViewFactory.setImage(bitmap);
        }

        Session currentLine = CallManager.Instance().getCurrentSession();
        if (currentLine != null && currentLine.sessionID > 0 && currentLine.hasVideo) {
            // convert bitmap to yuv data
            byte[] yuvData = bitmapToYUVData(bitmap);
            int width = bitmap.getWidth();
            int height = bitmap.getHeight();


            int result = Engine.Instance().getEngine().sendVideoStreamToRemote(currentLine.sessionID, yuvData, yuvData.length, width, height);
            // System.out.println("SDK-Android: MptCallkitPlugin - sendVideoStreamToRemote result: " + result + ", width: " + width + ", height: " + height);
        }
    }

    @Override
    public void onDetectionFailure(Exception e) {
        System.out.println("SDK-Android: MptCallkitPlugin - onDetectionFailure called with exception: " + e.getMessage());
    }

    private void createCameraSource() {
        // If there's no existing cameraSource, create one.
        if (cameraSource == null) {
            cameraSource = new CameraSource(activity);
        }
        if (segmenterProcessor == null) {
            segmenterProcessor = new SegmenterProcessor(activity, this, MptCallkitPlugin.recordLabel, MptCallkitPlugin.enableBlurBackground);
            cameraSource.setMachineLearningFrameProcessor(segmenterProcessor);
        }
    }

    public void startCameraSource() {
        createCameraSource();
        if (cameraSource != null && !isStartCameraSource) {
            try {
                System.out.println("SDK-Android: startCameraSource");
                cameraSource.start();
                isStartCameraSource = true;
            } catch (IOException e) {
                System.out.println("SDK-Android: startCameraSource error: " + e.getMessage());
            }
        }
    }

    public void stopCameraSource() {
        if (cameraSource != null && isStartCameraSource) {
            cameraSource.stop();
            isStartCameraSource = false;
        }
    }

    public void releaseCameraSource() {
        if (cameraSource != null) {
            cameraSource.release();
            cameraSource = null;
            segmenterProcessor = null;
            isStartCameraSource = false;
        }
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

    public void onNewToken(String token) {
        System.out.println("SDK-Android: MptCallkitPlugin - onNewToken called with token: " + token);
        this.pushToken = token;
        this.setPushNoti(false);
        Engine.Instance().getEngine().refreshRegistration(0);
    }

    public void onMessageReceived(Context ctx, Map<String, String> message) {
       System.out.println("SDK-Android: MptCallkitPlugin - onMessageReceived called with message: " + message.toString());

       // Check if context is available
       if (ctx == null) {
           System.out.println("SDK-Android: MptCallkitPlugin - onMessageReceived - context is null, cannot proceed");
           return;
       }
       context = ctx;
       loginIfNeeded(ctx);
    }

    private void loginIfNeeded(Context ctx) {
        // login if needed
       if(ctx != null && (!CallManager.Instance().online || !CallManager.Instance().isRegistered) && context != null && context.getPackageName() != null) {
            preferences = PreferenceManager.getDefaultSharedPreferences(ctx);
            String username = preferences.getString("username", null);
            String password = preferences.getString("password", null);
            String userDomain = preferences.getString("domain", null);
            String sipServer = preferences.getString("sipServer", null);
            String sipServerPort = preferences.getString("port", null);
            String displayName = preferences.getString("displayName", null);
            String transportType = preferences.getString("transportType", null);
            String srtpType = preferences.getString("srtpType", null);
            String appId = preferences.getString("appId", null);
            String pushToken = preferences.getString("pushToken", null);
            Boolean enableDebugLog = preferences.getBoolean("enableDebugLog", false);
            String resolution = preferences.getString("resolution", "720P");
            int bitrate = preferences.getInt("bitrate", 1024);
            int frameRate = preferences.getInt("frameRate", 30);
            MptCallkitPlugin.recordLabel = preferences.getString("recordLabel", "Agent");
            MptCallkitPlugin.enableBlurBackground = preferences.getBoolean("enableBlurBackground", false);
            Boolean autoLogin = preferences.getBoolean("autoLogin", false);

            if (autoLogin && username != null && password != null && userDomain != null && sipServer != null && sipServerPort != null) {
                Intent onLineIntent = new Intent(ctx, PortSipService.class);
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
                onLineIntent.putExtra("enableDebugLog", enableDebugLog);
                onLineIntent.putExtra("resolution", resolution);
                onLineIntent.putExtra("bitrate", bitrate);
                onLineIntent.putExtra("frameRate", frameRate);
                PortSipService.startServiceCompatibility(ctx, onLineIntent);
            }
        }
    }

    private void unregisterIfNeeded() {
        Session currentLine = CallManager.Instance().getCurrentSession();
        if (currentLine != null && currentLine.sessionID > 0 && currentLine.state == Session.CALL_STATE_FLAG.CONNECTED) {
            // IN CALl
            System.out.println("SDK-Android: OnPause - In call, cannot unregister " + currentLine.state);
            return;
        }
        if (activity == null || activity.getPackageName() == null) {
            System.out.println("SDK-Android: OnPause - Activity is null, cannot unregister");
            return;
        }
        Intent offLineIntent = new Intent(activity, PortSipService.class);
        offLineIntent.setAction(PortSipService.ACTION_SIP_UNREGIEST);
        PortSipService.startServiceCompatibility(activity, offLineIntent);
        System.out.println("SDK-Android: UnregisterServer..");
    }

    public void onAccept()   {
        System.out.println("SDK-Android: MptCallkitPlugin - onAccept called socketReady: " + this.socketReady + ", currentSession: " + CallManager.Instance().getCurrentSession() + ", answeredWithCallKit: " + this.answeredWithCallKit);
        this.answeredWithCallKit = true;
        preferences = PreferenceManager.getDefaultSharedPreferences(context);
        this.socketReady = preferences.getBoolean("socketReady", false);
        editor = preferences.edit();
        editor.putBoolean("answeredWithCallKit", true);
        editor.commit();
        Session currentLine = CallManager.Instance().getCurrentSession();
        if (this.socketReady == true && currentLine != null && currentLine.sessionID > 0 && this.answeredWithCallKit) {
            System.out.println("SDK-Android: MptCallkitPlugin - onAccept - Answering call after socket is ready");
            answerCall(false);
            this.answeredWithCallKit = false; // Reset flag after answering
            editor = preferences.edit();
            editor.putBoolean("answeredWithCallKit", false);
            editor.apply();
        }
    }

    public void onDecline()   {
        System.out.println("SDK-Android: MptCallkitPlugin - onDecline called");

        // decline call
        rejectCall();
    }

    public void onResume(Activity activity)   {
        System.out.println("SDK-Android: MptCallkitPlugin - onResume called");
        // this.activity = activity;
        loginIfNeeded(activity);
        Session currentLine = CallManager.Instance().getCurrentSession();
        if (currentLine != null && currentLine.sessionID > 0 && currentLine.hasVideo) {
            startCameraSource();
        }
    }
    public void onPause()   {
        System.out.println("SDK-Android: MptCallkitPlugin - onPause called");
        stopCameraSource();
        unregisterIfNeeded();
    }

    public void onCreate()   {
        System.out.println("SDK-Android: MptCallkitPlugin - onCreate called");
    }

    public void onStart()   {
        System.out.println("SDK-Android: MptCallkitPlugin - onStart called");
    }

    public void onStop()   {
        System.out.println("SDK-Android: MptCallkitPlugin - onStop called");
    }

    public void onDestroy()   {
        System.out.println("SDK-Android: MptCallkitPlugin - onDestroy called");
        unregisterIfNeeded();
        releaseCameraSource();
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        System.out.println("SDK-Android: onMethodCall " + call.method);
        Intent offLineIntent = null;
        Intent myIntent = null;
        Intent stopIntent = null;
        Session currentLine = null;
        switch (call.method) {
            case "getPlatformVersion":
                result.success("Android " + android.os.Build.VERSION.RELEASE);
                break;
            case "Offline":
                boolean disablePushNoti = call.argument("disablePushNoti");
                setPushNoti(disablePushNoti);
                offLineIntent = new Intent(activity, PortSipService.class);
                offLineIntent.setAction(PortSipService.ACTION_SIP_UNREGIEST);
                PortSipService.startServiceCompatibility(activity, offLineIntent);

                if(disablePushNoti == true){
                    // clear all shared preferences
                    preferences.edit().clear().apply();
                    editor.clear().apply();
                    System.out.println("SDK-Android: Clear all shared preferences");
                }

                System.out.println("SDK-Android: UnregisterServer..");
                result.success(true);
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
                int appKilledHangupResult = hangup();
                System.out.println("SDK-Android: appKilled hangup result: " + appKilledHangupResult);
                activity.finishAndRemoveTask();
            case "hangup":
                int hangupResult = hangup();
                result.success(hangupResult);
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
                int answerResult = answerCall(false);
                result.success(answerResult);
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
                this.appId = call.argument("appId");
                this.pushToken = call.argument("pushToken");
                Boolean enableDebugLog = call.argument("enableDebugLog");
                String recordLabel = call.argument("recordLabel");
                Boolean enableBlurBackground = call.argument("enableBlurBackground");
                Boolean autoLogin = call.argument("autoLogin");

                System.out.println("SDK-Android: Login called with enableDebugLog: " + enableDebugLog + ", recordLabel: " + recordLabel + ", enableBlurBackground: " + enableBlurBackground + ", autoLogin: " + autoLogin);
                
                if (recordLabel != null) {
                    MptCallkitPlugin.recordLabel = recordLabel;
                }

                if (enableBlurBackground != null) {
                    MptCallkitPlugin.enableBlurBackground = enableBlurBackground;
                }

                // Video quality parameters
                String resolution = call.argument("resolution");
                Integer bitrateArg = call.argument("bitrate");
                Integer frameRateArg = call.argument("frameRate");

                if (resolution == null || resolution.isEmpty()) {
                    resolution = "720P";
                }
                int bitrate = bitrateArg != null ? bitrateArg : 1024;
                int frameRate = frameRateArg != null ? frameRateArg : 30;

                // Lưu username hiện tại
                currentUsername = username;

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
                onLineIntent.putExtra("enableDebugLog", enableDebugLog);
                onLineIntent.putExtra("resolution", resolution);
                onLineIntent.putExtra("bitrate", bitrate);
                onLineIntent.putExtra("frameRate", frameRate);
                PortSipService.startServiceCompatibility(activity, onLineIntent);
                System.out.println("SDK-Android: RegisterServer..");

                if (autoLogin == true) {
                    // saved login info
                    preferences = PreferenceManager.getDefaultSharedPreferences(activity);
                    editor = preferences.edit();
                    editor.putString("username", username);
                    editor.putString("password", password);
                    editor.putString("domain", userDomain);
                    editor.putString("sipServer", sipServer);
                    editor.putString("port", sipServerPort);
                    editor.putString("displayName", displayName);
                    editor.putString("transportType", transportType);
                    editor.putString("srtpType", srtpType);
                    editor.putString("appId", appId);
                    editor.putString("pushToken", pushToken);
                    editor.putBoolean("enableDebugLog", enableDebugLog != null ? enableDebugLog : false);
                    editor.putString("resolution", resolution);
                    editor.putInt("bitrate", bitrate);
                    editor.putInt("frameRate", frameRate);
                    editor.putString("recordLabel", MptCallkitPlugin.recordLabel);
                    editor.putBoolean("autoLogin", autoLogin);
                    editor.putBoolean("enableBlurBackground", MptCallkitPlugin.enableBlurBackground);
                    editor.commit();
                }

                result.success(true);
                break;
            case "enableFileLogging":
                Boolean enabled = call.argument("enabled");
                if (enabled == null) {
                    result.error("INVALID_ARGUMENTS", "'enabled' is required", null);
                    break;
                }
                try {
                    if (enabled) {
                        String path = call.argument("filePath");
                        if (path == null || path.isEmpty()) {
                            result.error("INVALID_ARGUMENTS", "'filePath' is required when enabling", null);
                            break;
                        }
                        enableAndroidFileLogging(path);
                    } else {
                        disableAndroidFileLogging();
                    }
                    result.success(true);
                } catch (Exception e) {
                    result.error("LOGGING_ERROR", e.getMessage(), null);
                }
                break;
            case "reInvite":
                xSessionId = call.argument("sessionId");
                // boolean reinviteResult = reinviteSession(xSessionId);
                sendCustomMessage(xSessionId, currentUsername, "call_state", "isVideo", true);
                boolean reinviteResult = true;
                result.success(reinviteResult);
                break;
            case "updateVideoCall":
                currentLine = CallManager.Instance().getCurrentSession();
                Boolean isVideo = call.argument("isVideo");
                // Gửi video từ camera
                // int sendVideoResult = Engine.Instance().getEngine().sendVideo(currentLine.sessionID, isVideo);
                // System.out.println("SDK-Android: reinviteSession - sendVideo(): " + sendVideoResult);

                // Cập nhật cuộc gọi để thêm video stream
                int updateCallRes = Engine.Instance().getEngine().updateCall(currentLine.sessionID, true, isVideo);
                System.out.println("SDK-Android: reinviteSession - updateCall(): " + updateCallRes);

                result.success(updateCallRes == 0);
                break;
            case "refreshRegister":
                result.success(Engine.Instance().getEngine().refreshRegistration(0));
                break;

            case "socketStatus":
                socketReady = call.argument("ready");
                preferences = PreferenceManager.getDefaultSharedPreferences(context);
                this.answeredWithCallKit = preferences.getBoolean("answeredWithCallKit", false);
                editor = preferences.edit();
                editor.putBoolean("socketReady", socketReady);
                editor.apply();
                System.out.println("SDK-Android: MptCallkitPlugin - socketStatus - ready: " + socketReady + ", currentSession: " + CallManager.Instance().getCurrentSession() + ", answeredWithCallKit: " + this.answeredWithCallKit);
                currentLine = CallManager.Instance().getCurrentSession();
                if (socketReady == true && currentLine != null && currentLine.sessionID > 0 && this.answeredWithCallKit) {
                    System.out.println("SDK-Android: MptCallkitPlugin - socketStatus - Answering call after socket is ready");
                    answerCall(false);
                    this.answeredWithCallKit = false; // Reset flag after answering
                    editor = preferences.edit();
                    editor.putBoolean("answeredWithCallKit", false);
                    editor.apply();
                }
                result.success(true);
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
    }

    @Override
    public void onAttachedToActivity(ActivityPluginBinding activityPluginBinding) {
        System.out.println("SDK-Android: onAttachedToActivity called");
        activity = activityPluginBinding.getActivity();
        if (activity != null) {
            System.out.println("SDK-Android: Activity successfully attached: " + activity.getClass().getSimpleName());
            System.out.println("SDK-Android: Activity attachment completed successfully");
        } else {
            System.out.println("SDK-Android: Warning - Activity is null in onAttachedToActivity");
        }
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
        MptCallkitPlugin.shared = this;
        MptCallkitPlugin.shared.context = activity.getApplicationContext();
        MptCallkitPlugin.shared.activity = activity;
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
                    Thread.sleep(100);

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
                    int res = engine.unRegisterServer(100);
                    engine.removeUser();
                    engine.unInitialize();
                    if (res == 0) {
                        Engine.Instance().invokeMethod("onlineStatus", false);
                        MptCallkitPlugin.sendToFlutter("onlineStatus", false);
                    }
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

    
    /**
     * Get the current activity instance.
     * This is the recommended way to get the activity in the plugin.
     * @return Current activity or null if not available
     */
    public Activity getCurrentActivity() {
        if (activity != null) {
            System.out.println("SDK-Android: Returning cached activity: " + activity.getClass().getSimpleName());
            return activity;
        }
        
        System.out.println("SDK-Android: No cached activity available");
        return null;
    }
    
    /**
     * Static method to get the current activity from anywhere in the codebase.
     * @return Current activity or null if not available
     */
    public static Activity getActivity() {
        if (shared != null) {
            return shared.getCurrentActivity();
        }
        System.out.println("SDK-Android: MptCallkitPlugin.shared is null");
        return null;
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

    public static int hangup() {
        Session currentLine = CallManager.Instance().getCurrentSession();
        Ring.getInstance(MainActivity.activity).stop();
        MptCallkitPlugin.sendToFlutter("isRemoteVideoReceived", false);
        
        int statusCode = -1; // Success by default

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
                        statusCode = engine.rejectCall(currentLine.sessionID, 486);
                        System.out.println("SDK-Android: lineName= " + currentLine.lineName + ": Rejected call with status: " + statusCode);

                        if (MainActivity.activity != null) {
                            MainActivity.activity.onHangUpCall();
                        }

                        Engine.Instance().invokeMethod("callState", "CLOSED");
                        MptCallkitPlugin.sendToFlutter("callState", "CLOSED");
                        System.out.println("SDK-Android: callState - " + "CLOSED");

                        break;
                    case CONNECTED:
                    case TRYING:
                        statusCode = engine.hangUp(currentLine.sessionID);
                        System.out.println("SDK-Android: hangUp status code: " + statusCode);
                        MptCallkitPlugin.shared.stopCameraSource();

                        if (Engine.Instance() != null) {
                            if (MainActivity.activity != null) {
                                MainActivity.activity.onHangUpCall();
                            }

                            Engine.Instance().invokeMethod("callState", "CLOSED");
                            MptCallkitPlugin.sendToFlutter("callState", "CLOSED");
                            System.out.println("SDK-Android: callState - " + "CLOSED");
                        }

                        System.out.println("SDK-Android: lineName= " + currentLine.lineName + ": Hang up with status: " + statusCode);
                        break;
                    default:
                        statusCode = -1; // No active call to hang up
                        System.out.println("SDK-Android: No active call to hang up");
                        break;
                }
            } else {
                statusCode = -2; // Engine or session null
                System.out.println("SDK-Android: Engine or current session is null");
            }
        } catch (Exception e) {
            statusCode = -3; // Exception occurred
            System.out.println("SDK-Android: Error during hangup: " + e.getMessage());
        } finally {
            if (currentLine != null) {
                currentLine.Reset();
            }
        }
        
        return statusCode;
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
            Engine.Instance().invokeMethod("holdCallState", currentLine.bHold);
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
            Engine.Instance().invokeMethod("holdCallState", currentLine.bHold);
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
            Engine.Instance().invokeMethod("microphoneState", currentLine.bMuteAudioOutGoing);
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
            Engine.Instance().invokeMethod("cameraState", enable);
            MptCallkitPlugin.sendToFlutter("cameraState", enable);

            // Gửi tin nhắn với format mới
            String[] sessionInfo = getCurrentSessionInfo();
            sendCustomMessage(sessionInfo[0], sessionInfo[1], "update_media_state", "camera", enable);
        }
    }

    public static int answerCall(boolean isAutoAnswer) {
        Session currentLine = CallManager.Instance().getCurrentSession();
        System.out.println("SDK-Android: Answer call currentLine: " + currentLine);
        System.out.println("SDK-Android: Answer call sessionID: " + currentLine.sessionID);
        System.out.println("SDK-Android: Answer call state: " + currentLine.state);
        Ring.getInstance(MainActivity.activity).stopRingTone();
        Ring.getInstance(MainActivity.activity).stopRingBackTone();
        if (currentLine != null && currentLine.sessionID > 0 && currentLine.state == Session.CALL_STATE_FLAG.INCOMING) {
            if (Engine.Instance().getEngine() == null) {
                System.out.println("SDK-Android: Answer call Engine is null, setting method channel");
                if (Engine.Instance().getMethodChannel() == null) {
                    Engine.Instance().getMethodChannel().setMethodCallHandler(MptCallkitPlugin.shared);
                }
                Engine.Instance().setEngine(new PortSipSdk(MptCallkitPlugin.shared.context));
                // Only create receiver if it doesn't exist
                if (Engine.Instance().getReceiver() == null) {
                    Engine.Instance().setReceiver(new PortMessageReceiver());
                }
            }
            int result = -1;
            try {
                if (Engine.Instance().getEngine() != null) {
                    result = Engine.Instance().getEngine().answerCall(currentLine.sessionID, currentLine.hasVideo);
                }else {
                    System.out.println("SDK-Android: Answer call Engine is null");
                }
            } catch (Exception e) {
                System.out.println("SDK-Android: Answer call error: " + e.getMessage());
                e.printStackTrace();
            }
            System.out.println("SDK-Android: Answer call with video: " + currentLine.hasVideo);
            System.out.println("SDK-Android: Answer call result: " + result);
            if (result == 0) {
                if (Engine.Instance() != null) {
                    Engine.Instance().invokeMethod("callState", "ANSWERED");
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
            return result;
        } else {
            return -2;
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
                    Engine.Instance().invokeMethod("currentAudioDevice", state);
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
        Engine.Instance().invokeMethod("audioDevices", deviceNames);
        MptCallkitPlugin.sendToFlutter("audioDevices", deviceNames);

        // Gửi thông báo về thiết bị âm thanh hiện tại
        PortSipEnumDefine.AudioDevice currentDevice = CallManager.Instance().getCurrentAudioDevice();
        if (currentDevice != null) {
            String currentDeviceName = currentDevice.name();
            Engine.Instance().invokeMethod("currentAudioDevice", currentDeviceName);
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

    private void setPushNoti(boolean disablePushNoti) {

        String pushMessage = "device-os=android;device-uid=" + pushToken
                + ";allow-call-push=" + !disablePushNoti + ";allow-message-push=" + !disablePushNoti
                + ";app-id=" + appId;

        System.out.println("SDK-Android: setPushNoti - pushMessage: " + pushMessage);

        Engine.Instance().getEngine().addSipMessageHeader(-1, "REGISTER", 1, "X-Push", pushMessage);
        if (disablePushNoti) {
            // disable push noti
            System.out.println("SDK-Android: Disable push noti");
        } else {
            // enable push noti
            System.out.println("SDK-Android: Enable push noti");
        }
    }

    private static synchronized void enableAndroidFileLogging(String filePath) throws IOException {
        if (fileLoggingEnabled) return;
        File file = new File(filePath);
        File parent = file.getParentFile();
        if (parent != null && !parent.exists()) {
            parent.mkdirs();
        }
        logFileStream = new FileOutputStream(file, true);
        originalOut = System.out;
        originalErr = System.err;

        PrintStream multiOut = new PrintStream(new LinePrefixingOutputStream(new OutputStream() {
            @Override
            public void write(int b) throws IOException {
                if (originalOut != null) originalOut.write(b);
                logFileStream.write(new byte[]{(byte)b});
            }

            @Override
            public void write(byte[] b, int off, int len) throws IOException {
                if (originalOut != null) originalOut.write(b, off, len);
                logFileStream.write(b, off, len);
            }

            @Override
            public void flush() throws IOException {
                if (originalOut != null) originalOut.flush();
                logFileStream.flush();
            }
        }, "Android"), true);

        PrintStream multiErr = new PrintStream(new LinePrefixingOutputStream(new OutputStream() {
            @Override
            public void write(int b) throws IOException {
                if (originalErr != null) originalErr.write(b);
                logFileStream.write(new byte[]{(byte)b});
            }

            @Override
            public void write(byte[] b, int off, int len) throws IOException {
                if (originalErr != null) originalErr.write(b, off, len);
                logFileStream.write(b, off, len);
            }

            @Override
            public void flush() throws IOException {
                if (originalErr != null) originalErr.flush();
                logFileStream.flush();
            }
        }, " ssAndroid"), true);

        System.setOut(multiOut);
        System.setErr(multiErr);
        fileLoggingEnabled = true;

        // Also capture this app's logcat output (android.util.Log) without READ_LOGS
        startLogcatCapture();
    }

    private static synchronized void disableAndroidFileLogging() throws IOException {
        if (!fileLoggingEnabled) return;
        try {
            stopLogcatCapture();
            if (logFileStream != null) {
                logFileStream.flush();
                logFileStream.close();
            }
            if (originalOut != null) {
                System.setOut(originalOut);
                originalOut = null;
            }
            if (originalErr != null) {
                System.setErr(originalErr);
                originalErr = null;
            }
        } finally {
            fileLoggingEnabled = false;
            logFileStream = null;
        }
    }

    private static void startLogcatCapture() {
        try {
            String pid = String.valueOf(android.os.Process.myPid());
            ProcessBuilder pb = new ProcessBuilder("logcat", "--pid", pid, "-v", "time");
            pb.redirectErrorStream(true);
            logcatProcess = pb.start();
            logcatThread = new Thread(() -> {
                try (BufferedReader br = new BufferedReader(new InputStreamReader(logcatProcess.getInputStream()))) {
                    String line;
                    while ((line = br.readLine()) != null && fileLoggingEnabled) {
                        synchronized (MptCallkitPlugin.class) {
                            if (logFileStream != null) {
                                boolean flutterTagged = isFlutterLogLine(line);
                                String sourceTag = flutterTagged ? "[flutter] " : "[Android] ";
                                String prefixed = "[" + getTimestamp() + "] " + sourceTag + line + "\n";
                                logFileStream.write(prefixed.getBytes());
                                logFileStream.flush();
                            }
                        }
                    }
                } catch (Exception ignored) {
                }
            });
            logcatThread.setDaemon(true);
            logcatThread.start();
        } catch (Exception e) {
            // ignore
        }
    }

    // Heuristic: treat lines containing "Dart" or "/flutter" or "Flutter" tag as Flutter logs
    private static boolean isFlutterLogLine(String line) {
        if (line == null) return false;
        String lower = line.toLowerCase();
        return lower.contains(" flutter ") || lower.contains("/flutter") || lower.contains("dart ");
    }

    private static void stopLogcatCapture() {
        try {
            if (logcatProcess != null) {
                logcatProcess.destroy();
                logcatProcess = null;
            }
        } catch (Exception ignored) {}
        try {
            if (logcatThread != null) {
                logcatThread.interrupt();
                logcatThread = null;
            }
        } catch (Exception ignored) {}
    }
}
