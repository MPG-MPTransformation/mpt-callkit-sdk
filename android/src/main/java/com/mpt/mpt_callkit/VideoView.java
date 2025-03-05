package com.mpt.mpt_callkit;

import android.content.Context;
import android.view.LayoutInflater;
import android.view.View;
import android.widget.ImageButton;
import android.widget.LinearLayout;
import android.widget.TextView;
import io.flutter.plugin.platform.PlatformView;
import com.mpt.mpt_callkit.receiver.PortMessageReceiver;
import com.portsip.PortSIPVideoRenderer;
import com.mpt.mpt_callkit.util.Engine;
import com.mpt.mpt_callkit.util.CallManager;
import com.mpt.mpt_callkit.util.Session;
import com.portsip.PortSipEnumDefine;
import android.os.CountDownTimer;
import android.os.Build;
import android.content.Intent;
import com.portsip.PortSipSdk;
import android.content.IntentFilter;
import android.Manifest;
import androidx.core.app.ActivityCompat;
import android.net.Uri;
import android.os.PowerManager;
import android.content.pm.PackageManager;
import android.widget.Toast;
import android.app.Activity;
import android.content.BroadcastReceiver;
import android.app.AlertDialog;
import android.content.DialogInterface;

public class VideoView implements PlatformView {

    private final View view;
    private final Activity activity;
    private PortSIPVideoRenderer remoteRenderScreen;
    private PortSIPVideoRenderer localRenderScreen;
    private PortSIPVideoRenderer remoteRenderSmallScreen;
    private PortSIPVideoRenderer.ScalingType scalingType = PortSIPVideoRenderer.ScalingType.SCALE_ASPECT_BALANCED;
    private ImageButton imgSwitchCamera;
    private ImageButton imgScaleType;
    private ImageButton imgMicOn;
    private ImageButton imgHangOut;
    private ImageButton imgMute;
    private ImageButton imgVideo;
    private ImageButton imgBack;
    private LinearLayout llWaitingView;
    private LinearLayout llLocalView;
    private boolean shareInSmall = true;
    private boolean isMicOn = true;
    private boolean isVolumeOn = true;
    private boolean isVideoOn = true;
    private CountDownTimer countDownTimer;
    private Context context;
    private PortMessageReceiver receiver;
    private final int REQ_DANGERS_PERMISSION = 2;

    VideoView(Context context, Activity activity, int viewId) {
        this.context = context;
        this.activity = activity;
        view = LayoutInflater.from(context).inflate(R.layout.video, null);
        receiver = new PortMessageReceiver();
        initializeViews();
        setupClickListeners();
        setupInitialState();
        setupReceiver();
        
        // Khởi tạo và bắt đầu timer
        startCallTimer();
        
        // Yêu cầu quyền
        requestPermissions();
    }

    private void initializeViews() {
        remoteRenderScreen = view.findViewById(R.id.remote_video_view);
        localRenderScreen = view.findViewById(R.id.local_video_view);
        remoteRenderSmallScreen = view.findViewById(R.id.share_video_view);
        imgSwitchCamera = view.findViewById(R.id.ibcamera);
        imgScaleType = view.findViewById(R.id.ibscale);
        imgMicOn = view.findViewById(R.id.ibmicon);
        imgHangOut = view.findViewById(R.id.ibhangout);
        imgMute = view.findViewById(R.id.mute);
        imgVideo = view.findViewById(R.id.ibvideo);
        imgBack = view.findViewById(R.id.ibback);
        llWaitingView = view.findViewById(R.id.llWaitingView);
        llLocalView = view.findViewById(R.id.llLocalView);
    }

    private void setupClickListeners() {
        imgSwitchCamera.setOnClickListener(v -> handleSwitchCamera());
        imgScaleType.setOnClickListener(v -> handleScaleType());
        imgMicOn.setOnClickListener(v -> handleMicToggle());
        imgHangOut.setOnClickListener(v -> handleHangout());
        imgMute.setOnClickListener(v -> handleMuteToggle());
        imgVideo.setOnClickListener(v -> handleVideoToggle());
        imgBack.setOnClickListener(v -> handleBack());
    }

    private void setupInitialState() {
        // Ẩn các controls ban đầu
        imgSwitchCamera.setVisibility(View.GONE);
        imgMicOn.setVisibility(View.GONE);
        imgHangOut.setVisibility(View.GONE);
        imgMute.setVisibility(View.GONE);
        imgVideo.setVisibility(View.GONE);

        // Thiết lập scaling type
        remoteRenderScreen.setScalingType(scalingType);

        // Cập nhật video nếu có session đang active
        updateVideo(Engine.Instance().getEngine());
    }

    private void handleSwitchCamera() {
        if (Engine.Instance().mUseFrontCamera) {
            imgSwitchCamera.setImageResource(R.drawable.flip_camera);
        } else {
            imgSwitchCamera.setImageResource(R.drawable.flip_camera_behind);
        }
        boolean value = !Engine.Instance().mUseFrontCamera;
        SetCamera(Engine.Instance().getEngine(), value);
        Engine.Instance().mUseFrontCamera = value;
    }

    private void handleScaleType() {
        if (scalingType == PortSIPVideoRenderer.ScalingType.SCALE_ASPECT_FIT) {
            imgScaleType.setImageResource(R.drawable.fullscreen_on);
            scalingType = PortSIPVideoRenderer.ScalingType.SCALE_ASPECT_FILL;
        } else if (scalingType == PortSIPVideoRenderer.ScalingType.SCALE_ASPECT_FILL) {
            imgScaleType.setImageResource(R.drawable.aspect_balanced);
            scalingType = PortSIPVideoRenderer.ScalingType.SCALE_ASPECT_BALANCED;
        } else {
            imgScaleType.setImageResource(R.drawable.fullscreen_off);
            scalingType = PortSIPVideoRenderer.ScalingType.SCALE_ASPECT_FIT;
        }

        localRenderScreen.setScalingType(scalingType);
        remoteRenderScreen.setScalingType(scalingType);
        updateVideo(Engine.Instance().getEngine());
    }

    private void handleMicToggle() {
        Session currentLine = CallManager.Instance().getCurrentSession();
        currentLine.bMuteAudioOutGoing = !currentLine.bMuteAudioOutGoing;

        Engine.Instance().getEngine().muteSession(
                currentLine.sessionID,
                currentLine.bMuteAudioInComing,
                currentLine.bMuteAudioOutGoing,
                false,
                currentLine.bMuteVideo
        );

        if (currentLine.bMuteAudioOutGoing) {
            imgMicOn.setImageResource(R.drawable.mic_off);
        } else {
            imgMicOn.setImageResource(R.drawable.mic_on);
        }
    }

    private void handleHangout() {
        countDownTimer.cancel();
        Session currentLine = CallManager.Instance().getCurrentSession();

        // Tắt cuộc gọi
        Engine.Instance().getEngine().hangUp(currentLine.sessionID);
        currentLine.Reset();

        // Logout
        Intent offLineIntent = new Intent(context, PortSipService.class);
        offLineIntent.setAction(PortSipService.ACTION_SIP_UNREGIEST);
        PortSipService.startServiceCompatibility(context, offLineIntent);
    }

    private void handleMuteToggle() {
        if (CallManager.Instance().getCurrentAudioDevice() == PortSipEnumDefine.AudioDevice.EARPIECE) {
            CallManager.Instance().setAudioDevice(Engine.Instance().getEngine(), PortSipEnumDefine.AudioDevice.SPEAKER_PHONE);
            imgMute.setImageResource(R.drawable.volume_on);
        } else {
            CallManager.Instance().setAudioDevice(Engine.Instance().getEngine(), PortSipEnumDefine.AudioDevice.EARPIECE);
            imgMute.setImageResource(R.drawable.headphones);
        }
    }

    private void handleVideoToggle() {
        Session currentLine = CallManager.Instance().getCurrentSession();
        PortSipSdk portSipLib = Engine.Instance().getEngine();
        
        if (isVideoOn) {
            currentLine.bMuteVideo = !currentLine.bMuteVideo;
            portSipLib.muteSession(
                    currentLine.sessionID,
                    currentLine.bMuteAudioInComing,
                    currentLine.bMuteAudioOutGoing,
                    false,
                    currentLine.bMuteVideo
            );

            if (currentLine.bMuteVideo) {
                imgVideo.setImageResource(R.drawable.camera_off);
                llLocalView.setVisibility(View.GONE);
            } else {
                imgVideo.setImageResource(R.drawable.camera_on);
                llLocalView.setVisibility(View.VISIBLE);
            }
        } else {
            // Chuyển từ cuộc gọi âm thanh sang video
            Toast.makeText(context, "Switch to video call", Toast.LENGTH_SHORT).show();
            isVideoOn = true;
            CallManager callManager = CallManager.Instance();
            Session cur = CallManager.Instance().getCurrentSession();
            
            imgSwitchCamera.setVisibility(View.VISIBLE);
            localRenderScreen.setVisibility(View.VISIBLE);
            remoteRenderScreen.setVisibility(View.VISIBLE);
            
            callManager.setShareVideoWindow(portSipLib, cur.sessionID, null);
            callManager.setRemoteVideoWindow(portSipLib, cur.sessionID, remoteRenderScreen);
            portSipLib.displayLocalVideo(true, true, localRenderScreen);
            portSipLib.updateCall(cur.sessionID, true, true);
        }
    }

    private void handleBack() {
        // Hiển thị dialog xác nhận
        showConfirmDialog();
    }

    private void showConfirmDialog() {
        PortSipSdk portSipLib = Engine.Instance().getEngine();
        Session currentLine = CallManager.Instance().getCurrentSession();
        
        AlertDialog.Builder builder = new AlertDialog.Builder(context);
        builder.setMessage("Bạn có muốn dừng cuộc gọi?");
        builder.setCancelable(true);

        builder.setPositiveButton(
                "Có",
                new DialogInterface.OnClickListener() {
                    public void onClick(DialogInterface dialog, int id) {
                        // Tắt cuộc gọi
                        portSipLib.hangUp(currentLine.sessionID);
                        currentLine.Reset();
                        // Logout
                        Intent offLineIntent = new Intent(context, PortSipService.class);
                        offLineIntent.setAction(PortSipService.ACTION_SIP_UNREGIEST);
                        PortSipService.startServiceCompatibility(context, offLineIntent);
                        dialog.cancel();
                    }
                });

        builder.setNegativeButton(
                "Không",
                new DialogInterface.OnClickListener() {
                    public void onClick(DialogInterface dialog, int id) {
                        dialog.cancel();
                    }
                });

        AlertDialog dialog = builder.create();
        dialog.show();
    }

    private void SetCamera(PortSipSdk portSipLib, boolean userFront) {
        if (userFront) {
            portSipLib.setVideoDeviceId(0);
        } else {
            portSipLib.setVideoDeviceId(1);
        }
    }

    private void updateVideo(PortSipSdk portSipLib) {
        CallManager callManager = CallManager.Instance();
        Session cur = CallManager.Instance().getCurrentSession();

        if (cur != null && !cur.IsIdle() && cur.sessionID != -1) {
            // Hiển thị các nút điều khiển
            imgSwitchCamera.setVisibility(View.VISIBLE);
            imgMicOn.setVisibility(View.VISIBLE);
            imgHangOut.setVisibility(View.VISIBLE);
            imgMute.setVisibility(View.VISIBLE);
            imgVideo.setVisibility(View.VISIBLE);
            
            if (cur.hasVideo) {
                isVideoOn = true;
                imgSwitchCamera.setVisibility(View.VISIBLE);
                localRenderScreen.setVisibility(View.VISIBLE);
                remoteRenderScreen.setVisibility(View.VISIBLE);

                if (cur.bScreenShare) {
                    remoteRenderSmallScreen.setVisibility(View.VISIBLE);
                    callManager.setRemoteVideoWindow(portSipLib, cur.sessionID, null);
                    callManager.setShareVideoWindow(portSipLib, cur.sessionID, null);

                    if (shareInSmall) {
                        callManager.setRemoteVideoWindow(portSipLib, cur.sessionID, remoteRenderScreen);
                        callManager.setShareVideoWindow(portSipLib, cur.sessionID, remoteRenderSmallScreen);
                    } else {
                        callManager.setRemoteVideoWindow(portSipLib, cur.sessionID, remoteRenderSmallScreen);
                        callManager.setShareVideoWindow(portSipLib, cur.sessionID, remoteRenderScreen);
                    }
                } else {
                    remoteRenderSmallScreen.setVisibility(View.GONE);
                    callManager.setShareVideoWindow(portSipLib, cur.sessionID, null);
                    callManager.setRemoteVideoWindow(portSipLib, cur.sessionID, remoteRenderScreen);
                }

                imgVideo.setImageResource(R.drawable.camera_on);
                portSipLib.displayLocalVideo(true, true, localRenderScreen);
                portSipLib.sendVideo(cur.sessionID, true);
            } else {
                isVideoOn = false;
                imgSwitchCamera.setVisibility(View.INVISIBLE);
                remoteRenderSmallScreen.setVisibility(View.GONE);
                localRenderScreen.setVisibility(View.GONE);
                remoteRenderScreen.setVisibility(View.VISIBLE);
                imgVideo.setImageResource(R.drawable.switch_video_call);
                portSipLib.displayLocalVideo(false, false, null);
                callManager.setRemoteVideoWindow(portSipLib, cur.sessionID, null);
                if (cur.bScreenShare) {
                    callManager.setShareVideoWindow(portSipLib, cur.sessionID, remoteRenderScreen);
                }
            }
            
            // Cập nhật trạng thái các nút
            if (cur.bMuteAudioOutGoing) {
                imgMicOn.setImageResource(R.drawable.mic_off);
            } else {
                imgMicOn.setImageResource(R.drawable.mic_on);
            }
            
            updateAudioDeviceUI();
        } else {
            // Ẩn các nút điều khiển nếu không có cuộc gọi
            imgSwitchCamera.setVisibility(View.GONE);
            imgMicOn.setVisibility(View.GONE);
            imgHangOut.setVisibility(View.GONE);
            imgMute.setVisibility(View.GONE);
            imgVideo.setVisibility(View.GONE);
            remoteRenderSmallScreen.setVisibility(View.GONE);
            portSipLib.displayLocalVideo(false, false, null);
            callManager.setRemoteVideoWindow(portSipLib, -1, null);
        }
    }

    private void setupReceiver() {
        IntentFilter filter = new IntentFilter();
        filter.addAction(PortSipService.REGISTER_CHANGE_ACTION);
        filter.addAction(PortSipService.CALL_CHANGE_ACTION);
        filter.addAction(PortSipService.PRESENCE_CHANGE_ACTION);
        filter.addAction(PortSipService.ACTION_SIP_AUDIODEVICE);
        filter.addAction(PortSipService.ACTION_HANGOUT_SUCCESS);

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED);
        } else {
            context.registerReceiver(receiver, filter);
        }
        
        // Thêm xử lý sự kiện broadcast
        receiver.broadcastReceiver = new PortMessageReceiver.BroadcastListener() {
            @Override
            public void onBroadcastReceiver(Intent intent) {
                handleBroadcastReceiver(intent);
            }
        };
    }

    private void handleBroadcastReceiver(Intent intent) {
        PortSipSdk portSipLib = Engine.Instance().getEngine();
        Session currentLine = CallManager.Instance().getCurrentSession();
        String action = intent == null ? "" : intent.getAction();
        
        if (PortSipService.CALL_CHANGE_ACTION.equals(action)) {
            long sessionId = intent.getLongExtra(PortSipService.EXTRA_CALL_SEESIONID, Session.INVALID_SESSION_ID);
            String status = intent.getStringExtra(PortSipService.EXTRA_CALL_DESCRIPTION);
            Session session = CallManager.Instance().findSessionBySessionID(sessionId);
            
            if (session != null) {
                switch (session.state) {
                    case CLOSED:
                        // Tắt cuộc gọi
                        portSipLib.hangUp(currentLine.sessionID);
                        currentLine.Reset();
                        // Logout
                        Intent offLineIntent = new Intent(context, PortSipService.class);
                        offLineIntent.setAction(PortSipService.ACTION_SIP_UNREGIEST);
                        PortSipService.startServiceCompatibility(context, offLineIntent);
                        break;
                    case INCOMING:
                        break;
                    case TRYING:
                        updateVideo(Engine.Instance().getEngine());
                        break;
                    case CONNECTED:
                        // Nếu nhấc máy thì cancel countdown
                        if (countDownTimer != null) {
                            countDownTimer.cancel();
                        }
                        llWaitingView.setVisibility(View.GONE);
                        updateVideo(Engine.Instance().getEngine());
                        break;
                    case FAILED:
                        // Tắt cuộc gọi nếu người dùng cúp máy không nghe
                        portSipLib.hangUp(currentLine.sessionID);
                        currentLine.Reset();
                        // Logout
                        Intent logoutIntent = new Intent(context, PortSipService.class);
                        logoutIntent.setAction(PortSipService.ACTION_SIP_UNREGIEST);
                        PortSipService.startServiceCompatibility(context, logoutIntent);
                        break;
                }
            }
        } else if (PortSipService.REGISTER_CHANGE_ACTION.equals(action)) {
            // Xử lý sự kiện đăng ký thay đổi
        } else if (PortSipService.ACTION_SIP_AUDIODEVICE.equals(action)) {
            // Xử lý sự kiện thiết bị âm thanh thay đổi
            updateAudioDeviceUI();
        }
    }

    private void updateAudioDeviceUI() {
        PortSipEnumDefine.AudioDevice currentDevice = CallManager.Instance().getCurrentAudioDevice();
        if (currentDevice == PortSipEnumDefine.AudioDevice.EARPIECE) {
            imgMute.setImageResource(R.drawable.headphones);
        } else {
            imgMute.setImageResource(R.drawable.volume_on);
        }
    }

    private void requestPermissions() {
        if (PackageManager.PERMISSION_GRANTED != ActivityCompat.checkSelfPermission(context, Manifest.permission.CAMERA)
                || PackageManager.PERMISSION_GRANTED != ActivityCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO)) {
            ActivityCompat.requestPermissions((Activity) context,
                    new String[]{Manifest.permission.CAMERA, Manifest.permission.RECORD_AUDIO},
                    REQ_DANGERS_PERMISSION);
        }
    }

    private void startPowerSavePermissions() {
        String packageName = context.getPackageName();
        PowerManager pm = (PowerManager) context.getSystemService(Context.POWER_SERVICE);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !pm.isIgnoringBatteryOptimizations(packageName)) {
            Intent intent = new Intent();
            intent.setAction(android.provider.Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS);
            intent.setData(Uri.parse("package:" + packageName));
            context.startActivity(intent);
        }
    }

    private void startCallTimer() {
        PortSipSdk portSipLib = Engine.Instance().getEngine();
        Session currentLine = CallManager.Instance().getCurrentSession();
        
        countDownTimer = new CountDownTimer(30000, 1000) {
            public void onTick(long millisUntilFinished) {
                // Có thể thêm logic hiển thị thời gian còn lại
            }

            public void onFinish() {
                try {
                    Toast.makeText(context, "Người dùng không nghe máy", Toast.LENGTH_LONG).show();
                    // Tắt cuộc gọi nếu người dùng không nghe
                    portSipLib.hangUp(currentLine.sessionID);
                    currentLine.Reset();
                    // Logout
                    Intent logoutIntent = new Intent(context, PortSipService.class);
                    logoutIntent.setAction(PortSipService.ACTION_SIP_UNREGIEST);
                    PortSipService.startServiceCompatibility(context, logoutIntent);
                } catch (Exception e) {
                    e.printStackTrace();
                }
            }
        }.start();
    }

    @Override
    public View getView() {
        return view;
    }

    @Override
    public void dispose() {
        // Hủy đăng ký receiver
        if (receiver != null) {
            try {
                context.unregisterReceiver(receiver);
            } catch (Exception e) {
                e.printStackTrace();
            }
            receiver = null;
        }
        
        // Hủy timer
        if (countDownTimer != null) {
            countDownTimer.cancel();
            countDownTimer = null;
        }
        
        // Giải phóng tài nguyên video
        PortSipSdk portSipLib = Engine.Instance().getEngine();
        if (portSipLib != null) {
            portSipLib.displayLocalVideo(false, false, null);
        }
        
        if (localRenderScreen != null) {
            localRenderScreen.release();
            localRenderScreen = null;
        }
        
        CallManager.Instance().setRemoteVideoWindow(Engine.Instance().getEngine(), -1, null);
        if (remoteRenderScreen != null) {
            remoteRenderScreen.release();
            remoteRenderScreen = null;
        }
        
        CallManager.Instance().setShareVideoWindow(Engine.Instance().getEngine(), -1, null);
        if (remoteRenderSmallScreen != null) {
            remoteRenderSmallScreen.release();
            remoteRenderSmallScreen = null;
        }
    }

    public void onRequestPermissionsResult(int requestCode, String permissions[], int[] grantResults) {
        switch (requestCode) {
            case REQ_DANGERS_PERMISSION:
                int i = 0;
                for (int result : grantResults) {
                    if (result != PackageManager.PERMISSION_GRANTED) {
                        Toast.makeText(context, "you must grant the permission " + permissions[i], Toast.LENGTH_SHORT).show();
                        i++;
                        context.stopService(new Intent(context, PortSipService.class));
                        System.exit(0);
                    }
                }
                break;
        }
    }
}
