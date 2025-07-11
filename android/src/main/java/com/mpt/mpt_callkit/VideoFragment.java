package com.mpt.mpt_callkit;

import android.Manifest;
import android.app.AlertDialog;
import android.bluetooth.BluetoothAdapter;
import android.content.DialogInterface;
import android.content.pm.PackageManager;
import android.opengl.Visibility;
import android.os.Build;
import android.os.CountDownTimer;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.Toast;

import com.mpt.mpt_callkit.adapter.AudioDeviceAdapter;
import com.mpt.mpt_callkit.util.Engine;
import com.portsip.PortSipEnumDefine;
import com.portsip.PortSipErrorcode;
import com.portsip.PortSipSdk;

import android.content.Intent;
import android.os.Bundle;

import androidx.annotation.Nullable;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageButton;
import com.mpt.mpt_callkit.R;

import com.portsip.PortSIPVideoRenderer;
import com.mpt.mpt_callkit.receiver.PortMessageReceiver;
import com.mpt.mpt_callkit.PortSipService;
import com.mpt.mpt_callkit.util.CallManager;
import com.mpt.mpt_callkit.util.Session;
import com.mpt.mpt_callkit.util.Engine;

import static com.mpt.mpt_callkit.PortSipService.EXTRA_REGISTER_STATE;
import androidx.core.app.ActivityCompat;

import java.util.Set;

public class VideoFragment extends BaseFragment implements View.OnClickListener, PortMessageReceiver.BroadcastListener {
    MainActivity activity;

    private PortSIPVideoRenderer remoteRenderScreen = null;
    private PortSIPVideoRenderer localRenderScreen = null;
    private PortSIPVideoRenderer remoteRenderSmallScreen = null;
    private PortSIPVideoRenderer.ScalingType scalingType = PortSIPVideoRenderer.ScalingType.SCALE_ASPECT_BALANCED;// SCALE_ASPECT_FIT
                                                                                                                  // or
                                                                                                                  // SCALE_ASPECT_FILL;
    private ImageButton imgSwitchCamera = null;
    private ImageButton imgScaleType = null;
    private ImageButton imgMicOn = null;
    private ImageButton imgHangOut = null;
    private ImageButton imgMute = null;
    private ImageButton imgVideo = null;
    private ImageButton imgClose = null;
    private ImageButton imgBack = null;
    private LinearLayout llWaitingView = null;
    private LinearLayout llEndedView = null;
    private LinearLayout llLocalView = null;
    private boolean shareInSmall = true;
    private boolean isMicOn = true;
    private boolean isVolumeOn = true;
    private boolean isVideoOn = true;
    private boolean isInPIPMode = false;
    AudioDeviceAdapter audioDeviceAdapter;
    final PortSipEnumDefine.AudioDevice[] audioDevices = new PortSipEnumDefine.AudioDevice[] {
            PortSipEnumDefine.AudioDevice.EARPIECE,
            PortSipEnumDefine.AudioDevice.SPEAKER_PHONE,
            PortSipEnumDefine.AudioDevice.BLUETOOTH,
    };

    private CountDownTimer countDownTimer;

    private void startTimer(PortSipSdk portSipLib, Session currentLine) {
        countDownTimer = new CountDownTimer(30000, 1000) {

            public void onTick(long millisUntilFinished) {
                System.out.println("SDK-Android: seconds remaining: " + millisUntilFinished / 1000);
            }

            public void onFinish() {
                try {
                    Toast.makeText(activity, "Người dùng không nghe máy",
                            Toast.LENGTH_LONG).show();
                    /// tắt cuộc gọi nếu người dùng cúp máy không nghe
                    MptCallkitPlugin.hangup();
                    currentLine.Reset();
                    // /// logout
                    // Intent logoutIntent = new Intent(getActivity(), PortSipService.class);
                    // logoutIntent.setAction(PortSipService.ACTION_SIP_UNREGIEST);
                    // PortSipService.startServiceCompatibility(getActivity(), logoutIntent);
                    /// ve man hinh chinh
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                        activity.finishAndRemoveTask();
                    }
                } catch (Exception e) {
                    e.printStackTrace();
                }
            }
        }.start();
    }

    @Nullable
    @Override
    public View onCreateView(LayoutInflater inflater, @Nullable ViewGroup container, Bundle savedInstanceState) {
        System.out.println("SDK-Android: video onCreateView");
        super.onCreateView(inflater, container, savedInstanceState);
        activity = (MainActivity) getActivity();

        // Use the new setPrimaryReceiver method for better management
        Engine.Instance().getReceiver().setPrimaryReceiver(this);
        System.out.println("SDK-Android: broadcastReceiver - VideoFragment onCreateView - set: " + this.toString());

        return inflater.inflate(R.layout.video, container, false);
    }

    @Override
    public void onViewCreated(View view, @Nullable Bundle savedInstanceState) {
        System.out.println("SDK-Android: video onViewCreated");
        super.onViewCreated(view, savedInstanceState);
        imgSwitchCamera = (ImageButton) view.findViewById(R.id.ibcamera);
        imgScaleType = (ImageButton) view.findViewById(R.id.ibscale);
        imgMicOn = (ImageButton) view.findViewById(R.id.ibmicon);
        imgHangOut = (ImageButton) view.findViewById(R.id.ibhangout);
        imgMute = (ImageButton) view.findViewById(R.id.mute);
        imgVideo = (ImageButton) view.findViewById(R.id.ibvideo);
        imgBack = (ImageButton) view.findViewById(R.id.ibback);
        imgClose = (ImageButton) view.findViewById(R.id.ibclose);
        llWaitingView = (LinearLayout) view.findViewById(R.id.llWaitingView);
        llEndedView = (LinearLayout) view.findViewById(R.id.llEndedView);
        llLocalView = (LinearLayout) view.findViewById(R.id.llLocalView);

        imgScaleType.setOnClickListener(this);
        imgSwitchCamera.setOnClickListener(this);
        imgMicOn.setOnClickListener(this);
        imgHangOut.setOnClickListener(this);
        imgMute.setOnClickListener(this);
        imgVideo.setOnClickListener(this);
        imgBack.setOnClickListener(this);
        imgClose.setOnClickListener(this);

        // llWaitingView.setVisibility(View.GONE);
        llEndedView.setVisibility(View.GONE);
        imgClose.setVisibility(View.GONE);

        // imgSwitchCamera.setVisibility(View.GONE);
        // imgMicOn.setVisibility(View.GONE);
        // imgHangOut.setVisibility(View.GONE);
        // imgMute.setVisibility(View.GONE);
        // imgVideo.setVisibility(View.GONE);

        audioDeviceAdapter = new AudioDeviceAdapter(audioDevices);

        localRenderScreen = (PortSIPVideoRenderer) view.findViewById(R.id.local_video_view);
        remoteRenderScreen = (PortSIPVideoRenderer) view.findViewById(R.id.remote_video_view);
        remoteRenderSmallScreen = (PortSIPVideoRenderer) view.findViewById(R.id.share_video_view);
        // localRenderScreen.setVisibility(View.GONE);
        // remoteRenderScreen.setVisibility(View.GONE);
        // remoteRenderSmallScreen.setVisibility(View.GONE);
        remoteRenderSmallScreen.setOnClickListener(this);

        scalingType = PortSIPVideoRenderer.ScalingType.SCALE_ASPECT_FILL;//
        remoteRenderScreen.setScalingType(scalingType);
        PortSipSdk portSipLib = Engine.Instance().getEngine();
        Session currentLine = CallManager.Instance().getCurrentSession();
        System.out.println("SDK-Android: video updateVideo onViewCreated");
        updateVideo(portSipLib);
        // startTimer(portSipLib, currentLine);

        if (CallManager.Instance().getCurrentSession().state == Session.CALL_STATE_FLAG.CONNECTED) {
            countDownTimer.cancel();
            llWaitingView.setVisibility(View.GONE);
        }

        if (currentLine.hasVideo) {
            updateCameraView(currentLine.bMuteVideo);
        } else {
            imgVideo.setImageResource(R.drawable.switch_video_call);
        }

        updateMicView(currentLine.bMuteAudioOutGoing);

        // Initialize audio device based on available devices
        initializeAudioDevice();
    }

    @Override
    public void onDestroyView() {
        System.out.println("SDK-Android: video onDestroyView");

        // Cancel timer first to prevent any callbacks
        if (countDownTimer != null) {
            countDownTimer.cancel();
            countDownTimer = null;
        }

        // Remove this fragment as a listener when being destroyed
        if (Engine.Instance().getReceiver() != null) {
            Engine.Instance().getReceiver().removeListener(this);
            // Clear primary receiver if it's this fragment
            if (Engine.Instance().getReceiver().broadcastReceiver == this) {
                Engine.Instance().getReceiver().broadcastReceiver = null;
            }
        }
        System.out.println("SDK-Android: broadcastReceiver - VideoFragment onDestroyView - removed listener");

        // Clean up video renderers safely
        PortSipSdk portSipLib = Engine.Instance().getEngine();
        try {
            if (localRenderScreen != null) {
                if (portSipLib != null) {
                    portSipLib.displayLocalVideo(false, false, null);
                }
                localRenderScreen.release();
                localRenderScreen = null;
            }

            if (portSipLib != null) {
                CallManager.Instance().setRemoteVideoWindow(portSipLib, -1, null);
                CallManager.Instance().setShareVideoWindow(portSipLib, -1, null);
            }

            if (remoteRenderScreen != null) {
                remoteRenderScreen.release();
                remoteRenderScreen = null;
            }

            if (remoteRenderSmallScreen != null) {
                remoteRenderSmallScreen.release();
                remoteRenderSmallScreen = null;
            }
        } catch (Exception e) {
            System.out.println("SDK-Android: VideoFragment - Error during cleanup: " + e.getMessage());
        }

        super.onDestroyView();
    }

    @Override
    public void onHiddenChanged(boolean hidden) {
        System.out.println("SDK-Android: video onHiddenChanged");
        super.onHiddenChanged(hidden);

        if (hidden) {
            localRenderScreen.setVisibility(View.INVISIBLE);
            remoteRenderSmallScreen.setVisibility(View.INVISIBLE);
            stopVideo(Engine.Instance().getEngine());

            // Remove from primary but keep as backup when hidden
            if (Engine.Instance().getReceiver().broadcastReceiver == this) {
                Engine.Instance().getReceiver().broadcastReceiver = null;
            }
            System.out.println("SDK-Android: broadcastReceiver - VideoFragment hidden - removed from primary");
        } else {
            System.out.println("SDK-Android: video updateVideo onHiddenChanged");
            updateVideo(Engine.Instance().getEngine());

            // Set as primary receiver when shown
            Engine.Instance().getReceiver().setPrimaryReceiver(this);
            localRenderScreen.setVisibility(View.VISIBLE);

            // Reinitialize audio device when fragment becomes visible
            initializeAudioDevice();

            System.out.println(
                    "SDK-Android: broadcastReceiver - VideoFragment onHiddenChanged - set as primary: "
                            + this.toString());
        }
    }

    @Override
    public void onClick(View v) {
        System.out.println("SDK-Android: video onClick");
        PortSipSdk portSipLib = Engine.Instance().getEngine();
        Session currentLine = CallManager.Instance().getCurrentSession();
        if (v.getId() == R.id.ibcamera) {
            System.out.println("SDK-Android: cameraState: " + Engine.Instance().mUseFrontCamera);
            if (Engine.Instance().mUseFrontCamera) {
                imgSwitchCamera.setImageResource(R.drawable.flip_camera_behind);
            } else {
                imgSwitchCamera.setImageResource(R.drawable.flip_camera);
            }
            Engine.Instance().mUseFrontCamera = !Engine.Instance().mUseFrontCamera;
            setCamera(portSipLib, Engine.Instance().mUseFrontCamera);
            System.out.println("SDK-Android: cameraState: " + Engine.Instance().mUseFrontCamera);
        } else if (v.getId() == R.id.share_video_view) {
            shareInSmall = !shareInSmall;
            updateVideo(portSipLib);
        } else if (v.getId() == R.id.ibscale) {
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
            updateVideo(portSipLib);
        } else if (v.getId() == R.id.ibmicon) {
            currentLine.bMuteAudioOutGoing = !currentLine.bMuteAudioOutGoing;
            MptCallkitPlugin.muteMicrophone(currentLine.bMuteAudioOutGoing);

            updateMicView(currentLine.bMuteAudioOutGoing);
        } else if (v.getId() == R.id.ibhangout) {
            // Cancel timer when user manually hangs up
            if (countDownTimer != null) {
                countDownTimer.cancel();
                countDownTimer = null;
            }
            MptCallkitPlugin.hangup();
            /// ve man hinh chinh
//            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
//                activity.finishAndRemoveTask();
//            }
            hideBtnWhenCallEnded();
        } else if (v.getId() == R.id.mute) {
            PortSipEnumDefine.AudioDevice nextDevice = getNextAudioDevice();
            CallManager.Instance().setAudioDevice(portSipLib, nextDevice);
            updateMuteIcon(nextDevice);
        } else if (v.getId() == R.id.ibclose) {
            /// ve man hinh chinh
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                activity.finishAndRemoveTask();
                System.out.println("SDK-Android: video closed!");
            } else {
                System.out.println("SDK-Android: video close failed!");
            }
        } else if (v.getId() == R.id.ibvideo) {
            if (!currentLine.hasVideo) {
                // Gửi video từ camera
                int sendVideoRes = Engine.Instance().getEngine().sendVideo(currentLine.sessionID, true);
                System.out.println("SDK-Android: sendVideo: " + sendVideoRes);

                // Cập nhật cuộc gọi để thêm video stream
                int updateRes = Engine.Instance().getEngine().updateCall(currentLine.sessionID, true, true);
                System.out.println("SDK-Android: updateCall(): " + updateRes);
            }
            MptCallkitPlugin.toggleCameraOn(currentLine.bMuteVideo);
            updateCameraView(currentLine.bMuteVideo);
        } else if (v.getId() == R.id.ibback) {
            // Enter PIP mode instead of showing confirmation dialog
            activity.enterPictureInPictureMode();
        }
    }

    private AlertDialog getAlertDialog() {
        PortSipSdk portSipLib = Engine.Instance().getEngine();
        Session currentLine = CallManager.Instance().getCurrentSession();
        AlertDialog.Builder builder = new AlertDialog.Builder(activity);
        builder.setMessage("Bạn có muốn dừng cuộc gọi?");
        builder.setCancelable(true);

        builder.setPositiveButton(
                "Có",
                new DialogInterface.OnClickListener() {
                    public void onClick(DialogInterface dialog, int id) {
                        activity.setAllowBack(true);
                        /// Tat cuoc goi
                        MptCallkitPlugin.hangup();
                        currentLine.Reset();
                        /// logout
                        Intent offLineIntent = new Intent(getActivity(), PortSipService.class);
                        offLineIntent.setAction(PortSipService.ACTION_SIP_UNREGIEST);
                        PortSipService.startServiceCompatibility(getActivity(), offLineIntent);
                        /// ve man hinh chinh
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                            activity.finishAndRemoveTask();
                        }
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

        return builder.create();
    }

    private void setCamera(PortSipSdk portSipLib, boolean userFront) {
        System.out.println("SDK-Android: video SetCamera - userFront: " + userFront);
        int deviceId = userFront ? 1 : 0;
        portSipLib.setVideoDeviceId(deviceId);
        portSipLib.displayLocalVideo(true, userFront, localRenderScreen);
    }

    private void stopVideo(PortSipSdk portSipLib) {
        System.out.println("SDK-Android: video stopVideo");
        Session cur = CallManager.Instance().getCurrentSession();
        if (portSipLib != null) {
            portSipLib.displayLocalVideo(false, false, null);
            CallManager.Instance().setRemoteVideoWindow(portSipLib, cur.sessionID, null);
            CallManager.Instance().setConferenceVideoWindow(portSipLib, null);
        }
    }

    public void updateVideo(PortSipSdk portSipLib) {
        CallManager callManager = CallManager.Instance();
        Session cur = CallManager.Instance().getCurrentSession();
        if (Engine.Instance().mConference) {
            System.out.println("SDK-Android: application.mConference = true && setConferenceVideoWindow");
            callManager.setConferenceVideoWindow(portSipLib, remoteRenderScreen);
        } else {
            System.out.println("SDK-Android: application.mConference = false");
            if (cur != null && !cur.IsIdle()
                    && cur.sessionID != PortSipErrorcode.INVALID_SESSION_ID) {
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
                            // callManager.se(portSipLib,cur.sessionID, remoteRenderScreen);
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
                    portSipLib.displayLocalVideo(true, Engine.Instance().mUseFrontCamera, localRenderScreen); // display
                                                                                                              // Local
                                                                                                              // video
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
            } else {
                imgSwitchCamera.setVisibility(View.GONE);
                imgMicOn.setVisibility(View.GONE);
                imgHangOut.setVisibility(View.GONE);
                imgMute.setVisibility(View.GONE);
                imgVideo.setVisibility(View.GONE);
                remoteRenderSmallScreen.setVisibility(View.GONE);
                portSipLib.displayLocalVideo(false, false, null);
                callManager.setRemoteVideoWindow(portSipLib, cur.sessionID, null);
            }
        }
    }

    @Override
    public void onBroadcastReceiver(Intent intent) {
        System.out.println("SDK-Android: video onBroadcastReceiver activated");
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
                        System.out.println("SDK-Android: video onBroadcastReceiver CLOSED");
                        MptCallkitPlugin.hangup();
                        escPIPMode();
                        hideBtnWhenCallEnded();
                        break;
                    case INCOMING:
                        break;
                    case TRYING:
                        System.out.println("SDK-Android: video updateVideo TRYING");
                        updateVideo(Engine.Instance().getEngine());
                        break;
                    case CONNECTED:
                        /// Nếu nhấc máy thì cancel countdown
                        if (countDownTimer != null) {
                            countDownTimer.cancel();
                            countDownTimer = null;
                        }

                        llWaitingView.setVisibility(View.GONE);

                        if (session.hasVideo) {
                            llLocalView.setVisibility(View.VISIBLE);
                        } else {
                            llLocalView.setVisibility(View.GONE);
                        }
                        System.out.println("SDK-Android: video updateVideo CONNECTED");
                        updateVideo(Engine.Instance().getEngine());
                        break;
                    case FAILED:
                        System.out.println("SDK-Android: video updateVideo FAILED");
                        MptCallkitPlugin.hangup();
                        escPIPMode();
                        hideBtnWhenCallEnded();
                        break;
                }
            }
        } else if (PortSipService.REGISTER_CHANGE_ACTION.equals(action)) {
            System.out.println("SDK-Android: REGISTER_CHANGE_ACTION - login");
        }
    }

    private void hideBtnWhenCallEnded() {
        imgSwitchCamera.setVisibility(View.GONE);
        imgScaleType.setVisibility(View.GONE);
        imgMicOn.setVisibility(View.GONE);
        imgHangOut.setVisibility(View.GONE);
        imgMute.setVisibility(View.GONE);
        imgVideo.setVisibility(View.GONE);
        imgBack.setVisibility(View.GONE);
        localRenderScreen.setVisibility(View.GONE);
        remoteRenderScreen.setVisibility(View.GONE);
        remoteRenderSmallScreen.setVisibility(View.GONE);

        llEndedView.setVisibility(View.VISIBLE);
        imgClose.setVisibility(View.VISIBLE);
    }

    private void escPIPMode(){
        if (isInPIPMode && activity != null){
            Intent activityIntent = new Intent(activity, MainActivity.class);
            activityIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            activity.startActivity(activityIntent);
        }
    }

    public void onHangUpCall(){
        escPIPMode();
        hideBtnWhenCallEnded();
    }

    // Add method to check if there's an active call
    public boolean hasActiveCall() {
        Session currentLine = CallManager.Instance().getCurrentSession();
        return currentLine != null && !currentLine.IsIdle() &&
                currentLine.sessionID != PortSipErrorcode.INVALID_SESSION_ID;
    }

    // Add method to handle PIP mode changes
    public void onPipModeChanged(boolean isInPictureInPictureMode) {
        System.out.println("SDK-Android: VideoFragment - PIP mode changed: " + isInPictureInPictureMode);

        if (isInPictureInPictureMode) {
            // Hide UI controls when entering PIP mode
            hideControlsForPip();
            isInPIPMode = true;
            // Show instruction toast only if activity is not null
            if (activity != null && !activity.isFinishing()) {
                Toast.makeText(activity, "Entering PIP mode", Toast.LENGTH_LONG).show();
            }
        } else {
            // Show UI controls when exiting PIP mode
            isInPIPMode = false;
            showControlsFromPip();
        }
    }

    private void hideControlsForPip() {
        // Hide all control buttons in PIP mode
        imgSwitchCamera.setVisibility(View.GONE);
        imgScaleType.setVisibility(View.GONE);
        imgMicOn.setVisibility(View.GONE);
        imgHangOut.setVisibility(View.GONE);
        imgMute.setVisibility(View.GONE);
        imgVideo.setVisibility(View.GONE);
        imgBack.setVisibility(View.GONE);

        // Keep only the video views visible
        localRenderScreen.setVisibility(View.GONE); // Hide local video in PIP
        remoteRenderScreen.setVisibility(View.VISIBLE); // Keep remote video
        remoteRenderSmallScreen.setVisibility(View.GONE);
    }

    private void showControlsFromPip() {
        // Restore controls when exiting PIP mode
        Session currentLine = CallManager.Instance().getCurrentSession();
        if (currentLine != null && !currentLine.IsIdle()) {
            imgSwitchCamera.setVisibility(View.VISIBLE);
            imgScaleType.setVisibility(View.VISIBLE);
            imgMicOn.setVisibility(View.VISIBLE);
            imgHangOut.setVisibility(View.VISIBLE);
            imgMute.setVisibility(View.VISIBLE);
            imgVideo.setVisibility(View.VISIBLE);
            imgBack.setVisibility(View.VISIBLE);

            // Restore video views based on current state
            if (currentLine.hasVideo && isVideoOn) {
                localRenderScreen.setVisibility(View.VISIBLE);
            }

            // Update video display and audio device
            updateVideo(Engine.Instance().getEngine());

            // Update mute icon based on current audio device
            PortSipEnumDefine.AudioDevice currentDevice = CallManager.Instance().getCurrentAudioDevice();
            updateMuteIcon(currentDevice);
        }
    }

    public void updateCameraView(boolean state) {
        if (state) {
            imgVideo.setImageResource(R.drawable.camera_off);
            llLocalView.setVisibility(View.GONE);
        } else {
            imgVideo.setImageResource(R.drawable.camera_on);
            llLocalView.setVisibility(View.VISIBLE);
        }
    }

    public void updateMicView(boolean isMute) {
        if (isMute) {
            imgMicOn.setImageResource(R.drawable.mic_off);
        } else {
            imgMicOn.setImageResource(R.drawable.mic_on);
        }
    }

    /**
     * Initialize audio device when VideoFragment is opened
     */
    private void initializeAudioDevice() {
        PortSipSdk portSipLib = Engine.Instance().getEngine();
        Set<PortSipEnumDefine.AudioDevice> availableDevices = portSipLib.getAudioDevices();

        if (availableDevices.contains(PortSipEnumDefine.AudioDevice.BLUETOOTH)) {
            // If bluetooth is available, set it as default
            CallManager.Instance().setAudioDevice(portSipLib, PortSipEnumDefine.AudioDevice.BLUETOOTH);
            updateMuteIcon(PortSipEnumDefine.AudioDevice.BLUETOOTH);
            System.out.println("SDK-Android: VideoFragment - Initialized with BLUETOOTH audio device");
        } else {
            // If no bluetooth, set earpiece as default
            CallManager.Instance().setAudioDevice(portSipLib, PortSipEnumDefine.AudioDevice.EARPIECE);
            updateMuteIcon(PortSipEnumDefine.AudioDevice.EARPIECE);
            System.out.println("SDK-Android: VideoFragment - Initialized with EARPIECE audio device");
        }
    }

    /**
     * Get the next audio device in the cycle based on current device and available
     * devices
     */
    private PortSipEnumDefine.AudioDevice getNextAudioDevice() {
        PortSipSdk portSipLib = Engine.Instance().getEngine();
        Set<PortSipEnumDefine.AudioDevice> availableDevices = portSipLib.getAudioDevices();
        PortSipEnumDefine.AudioDevice currentDevice = CallManager.Instance().getCurrentAudioDevice();

        boolean hasBluetooth = availableDevices.contains(PortSipEnumDefine.AudioDevice.BLUETOOTH);

        if (hasBluetooth) {
            // Cycle: BLUETOOTH -> SPEAKER_PHONE -> EARPIECE -> BLUETOOTH
            switch (currentDevice) {
                case BLUETOOTH:
                    return PortSipEnumDefine.AudioDevice.SPEAKER_PHONE;
                case SPEAKER_PHONE:
                    return PortSipEnumDefine.AudioDevice.EARPIECE;
                case EARPIECE:
                    return PortSipEnumDefine.AudioDevice.BLUETOOTH;
                default:
                    return PortSipEnumDefine.AudioDevice.BLUETOOTH; // Default to bluetooth if unknown state
            }
        } else {
            // Cycle: EARPIECE -> SPEAKER_PHONE -> EARPIECE
            switch (currentDevice) {
                case SPEAKER_PHONE:
                    return PortSipEnumDefine.AudioDevice.EARPIECE;
                case EARPIECE:
                    return PortSipEnumDefine.AudioDevice.SPEAKER_PHONE;
                default:
                    return PortSipEnumDefine.AudioDevice.EARPIECE; // Default to speaker phone if unknown state
            }
        }
    }

    /**
     * Update the mute button icon based on current audio device
     */
    private void updateMuteIcon(PortSipEnumDefine.AudioDevice audioDevice) {
        switch (audioDevice) {
            case BLUETOOTH:
                imgMute.setImageResource(R.drawable.bluetooth);
                break;
            case SPEAKER_PHONE:
                imgMute.setImageResource(R.drawable.volume_on);
                break;
            case EARPIECE:
                imgMute.setImageResource(R.drawable.headphones);
                break;
            default:
                imgMute.setImageResource(R.drawable.volume_on); // Default icon
                break;
        }
        System.out.println("SDK-Android: VideoFragment - Updated mute icon for audio device: " + audioDevice);
    }

}
