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

public class VideoFragment extends BaseFragment implements View.OnClickListener, PortMessageReceiver.BroadcastListener {
    MainActivity activity;

    private PortSIPVideoRenderer remoteRenderScreen = null;
    private PortSIPVideoRenderer localRenderScreen = null;
    private PortSIPVideoRenderer remoteRenderSmallScreen = null;
    private PortSIPVideoRenderer.ScalingType scalingType = PortSIPVideoRenderer.ScalingType.SCALE_ASPECT_BALANCED;// SCALE_ASPECT_FIT or SCALE_ASPECT_FILL;
    private ImageButton imgSwitchCamera = null;
    private ImageButton imgScaleType = null;
    private ImageButton imgMicOn = null;
    private ImageButton imgHangOut = null;
    private ImageButton imgMute = null;
    private ImageButton imgVideo = null;
    private ImageButton imgBack = null;
    private LinearLayout llWaitingView = null;
    private LinearLayout llLocalView = null;
    private boolean shareInSmall = true;
    private boolean isMicOn = true;
    private boolean isVolumeOn = true;
    private boolean isVideoOn = true;
    AudioDeviceAdapter audioDeviceAdapter;
    final PortSipEnumDefine.AudioDevice[] audioDevices = new PortSipEnumDefine.AudioDevice[]
    {
        PortSipEnumDefine.AudioDevice.EARPIECE,
        PortSipEnumDefine.AudioDevice.SPEAKER_PHONE,
        PortSipEnumDefine.AudioDevice.BLUETOOTH,
//        PortSipEnumDefine.AudioDevice.WIRED_HEADSET
    };
    private PortSipEnumDefine.AudioDevice currentAudioDevice = PortSipEnumDefine.AudioDevice.SPEAKER_PHONE;

    private CountDownTimer countDownTimer;
    private void startTimer(PortSipSdk portSipLib, Session currentLine){
        countDownTimer = new CountDownTimer(30000, 1000)
        {

            public void onTick(long millisUntilFinished)
            {
                System.out.println("quanth: seconds remaining: " + millisUntilFinished / 1000);
            }

            public void onFinish()
            {
                try {
                    Toast.makeText(activity, "Người dùng không nghe máy",
                            Toast.LENGTH_LONG).show();
                    /// tắt cuộc gọi nếu người dùng cúp máy không nghe
                    portSipLib.hangUp(currentLine.sessionID);
                    currentLine.Reset();
                    /// logout
                    Intent logoutIntent = new Intent(getActivity(), PortSipService.class);
                    logoutIntent.setAction(PortSipService.ACTION_SIP_UNREGIEST);
                    PortSipService.startServiceCompatibility(getActivity(), logoutIntent);
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
        System.out.println("quanth: video onCreateView");
        super.onCreateView(inflater, container, savedInstanceState);
        activity = (MainActivity) getActivity();
        Engine.Instance().getReceiver().broadcastReceiver = this;

        return inflater.inflate(R.layout.video, container, false);
    }

    @Override
    public void onViewCreated(View view, @Nullable Bundle savedInstanceState) {
        System.out.println("quanth: video onViewCreated");
        super.onViewCreated(view, savedInstanceState);
        imgSwitchCamera = (ImageButton) view.findViewById(R.id.ibcamera);
        imgScaleType = (ImageButton) view.findViewById(R.id.ibscale);
        imgMicOn = (ImageButton) view.findViewById(R.id.ibmicon);
        imgHangOut = (ImageButton) view.findViewById(R.id.ibhangout);
        imgMute = (ImageButton) view.findViewById(R.id.mute);
        imgVideo = (ImageButton) view.findViewById(R.id.ibvideo);
        imgBack = (ImageButton) view.findViewById(R.id.ibback);
        llWaitingView = (LinearLayout) view.findViewById(R.id.llWaitingView);
        llLocalView = (LinearLayout) view.findViewById(R.id.llLocalView);

        imgScaleType.setOnClickListener(this);
        imgSwitchCamera.setOnClickListener(this);
        imgMicOn.setOnClickListener(this);
        imgHangOut.setOnClickListener(this);
        imgMute.setOnClickListener(this);
        imgVideo.setOnClickListener(this);
        imgBack.setOnClickListener(this);

        imgSwitchCamera.setVisibility(View.GONE);
        imgMicOn.setVisibility(View.GONE);
        imgHangOut.setVisibility(View.GONE);
        imgMute.setVisibility(View.GONE);
        imgVideo.setVisibility(View.GONE);

        audioDeviceAdapter = new AudioDeviceAdapter(audioDevices);

        localRenderScreen = (PortSIPVideoRenderer) view.findViewById(R.id.local_video_view);
        remoteRenderScreen = (PortSIPVideoRenderer) view.findViewById(R.id.remote_video_view);
        remoteRenderSmallScreen = (PortSIPVideoRenderer) view.findViewById(R.id.share_video_view);
        localRenderScreen.setVisibility(View.GONE);
        remoteRenderScreen.setVisibility(View.GONE);
        remoteRenderSmallScreen.setVisibility(View.GONE);
        remoteRenderSmallScreen.setOnClickListener(this);
        scalingType = PortSIPVideoRenderer.ScalingType.SCALE_ASPECT_FIT;//
        remoteRenderScreen.setScalingType(scalingType);
        PortSipSdk portSipLib = Engine.Instance().getEngine();
        Session currentLine = CallManager.Instance().getCurrentSession();
        System.out.println("quanth: video updateVideo onViewCreated");
        updateVideo(portSipLib);
        startTimer(portSipLib, currentLine);
    }

    @Override
    public void onDestroyView() {
        System.out.println("quanth: video onDestroyView");
        super.onDestroyView();

        PortSipSdk portSipLib = Engine.Instance().getEngine();
        if (localRenderScreen != null) {
            if (portSipLib != null) {
                portSipLib.displayLocalVideo(false, false, null);
            }
            localRenderScreen.release();
        }

        CallManager.Instance().setRemoteVideoWindow(Engine.Instance().getEngine(), -1, null);//set
        if (remoteRenderScreen != null) {
            remoteRenderScreen.release();
        }

        CallManager.Instance().setShareVideoWindow(Engine.Instance().getEngine(), -1, null);//set
        if (remoteRenderSmallScreen != null) {
            remoteRenderSmallScreen.release();
        }
        countDownTimer.cancel();
    }

    @Override
    public void onHiddenChanged(boolean hidden) {
        System.out.println("quanth: video onHiddenChanged");
        System.out.println("quanth: onHiddenChanged");
        super.onHiddenChanged(hidden);

        if (hidden) {
            localRenderScreen.setVisibility(View.INVISIBLE);
            remoteRenderSmallScreen.setVisibility(View.INVISIBLE);
            stopVideo(Engine.Instance().getEngine());
        } else {
            System.out.println("quanth: video updateVideo onHiddenChanged");
            updateVideo(Engine.Instance().getEngine());
            Engine.Instance().getReceiver().broadcastReceiver = this;
            localRenderScreen.setVisibility(View.VISIBLE);

        }
    }

    @Override
    public void onClick(View v) {
        System.out.println("quanth: video onClick");
        PortSipSdk portSipLib = Engine.Instance().getEngine();
        Session currentLine = CallManager.Instance().getCurrentSession();
        if (v.getId() == R.id.ibcamera) {
            if (Engine.Instance().mUseFrontCamera) {
                imgSwitchCamera.setImageResource(R.drawable.flip_camera);
            } else {
                imgSwitchCamera.setImageResource(R.drawable.flip_camera_behind);
            }
            boolean value = !Engine.Instance().mUseFrontCamera;
            SetCamera(portSipLib, value);
            Engine.Instance().mUseFrontCamera = value;
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
            System.out.println("quanth: mute ================================");
            System.out.println("quanth: mute currentLine.bMuteAudioInComing = " + currentLine.bMuteAudioInComing);
            System.out.println("quanth: mute currentLine.bMuteAudioOutGoing = " + currentLine.bMuteAudioOutGoing);
            System.out.println("quanth: mute currentLine.bMuteVideo = " + currentLine.bMuteVideo);
            // long sessionId, boolean muteIncomingAudio, boolean muteOutgoingAudio, boolean muteIncomingVideo, boolean muteOutgoingVideo
            portSipLib.muteSession(
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
        } else if (v.getId() == R.id.ibhangout) {
            countDownTimer.cancel();
            /// Tat cuoc goi
            portSipLib.hangUp(currentLine.sessionID);
            currentLine.Reset();
            /// logout
            Intent offLineIntent = new Intent(getActivity(), PortSipService.class);
            offLineIntent.setAction(PortSipService.ACTION_SIP_UNREGIEST);
            PortSipService.startServiceCompatibility(getActivity(), offLineIntent);
            /// ve man hinh chinh
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                activity.finishAndRemoveTask();
            }
        } else if (v.getId() == R.id.mute) {
            if ( CallManager.Instance().getCurrentAudioDevice() == PortSipEnumDefine.AudioDevice.EARPIECE) {
                CallManager.Instance().setAudioDevice(portSipLib, PortSipEnumDefine.AudioDevice.SPEAKER_PHONE);
                imgMute.setImageResource(R.drawable.volume_on);
            }else {
                CallManager.Instance().setAudioDevice(portSipLib,  PortSipEnumDefine.AudioDevice.EARPIECE);
                imgMute.setImageResource(R.drawable.headphones);
            }
        } else if(v.getId() == R.id.ibvideo){
            if (isVideoOn){
                currentLine.bMuteVideo = !currentLine.bMuteVideo;
                System.out.println("quanth: mute ================================");
                System.out.println("quanth: mute currentLine.bMuteAudioInComing = " + currentLine.bMuteAudioInComing);
                System.out.println("quanth: mute currentLine.bMuteAudioOutGoing = " + currentLine.bMuteAudioOutGoing);
                System.out.println("quanth: mute currentLine.bMuteVideo = " + currentLine.bMuteVideo);
                // long sessionId, boolean muteIncomingAudio, boolean muteOutgoingAudio, boolean muteIncomingVideo, boolean muteOutgoingVideo
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
                Toast.makeText(activity, "Switch to video call",
                        Toast.LENGTH_SHORT).show();
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
        } else if(v.getId() == R.id.ibback) {
            AlertDialog dialog = getAlertDialog();
            dialog.show();
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
                        portSipLib.hangUp(currentLine.sessionID);
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

    private void SetCamera(PortSipSdk portSipLib, boolean userFront) {
        System.out.println("quanth: video SetCamera");
        if (userFront) {
            portSipLib.setVideoDeviceId(0);
        } else {
            portSipLib.setVideoDeviceId(1);
        }
    }

    private void stopVideo(PortSipSdk portSipLib) {
        System.out.println("quanth: video stopVideo");
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
            System.out.println("quanth: application.mConference = true && setConferenceVideoWindow");
            callManager.setConferenceVideoWindow(portSipLib, remoteRenderScreen);
        } else {
            System.out.println("quanth: application.mConference = false");
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
                            //callManager.se(portSipLib,cur.sessionID, remoteRenderScreen);
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
                    portSipLib.displayLocalVideo(true, true, localRenderScreen); // display Local video
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

    public void onBroadcastReceiver(Intent intent) {
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
                        System.out.println("quanth: video onBroadcastReceiver CLOSED");
                        /// Tat cuoc goi
                        portSipLib.hangUp(currentLine.sessionID);
                        currentLine.Reset();
                        /// logout
                        Intent offLineIntent = new Intent(getActivity(), PortSipService.class);
                        offLineIntent.setAction(PortSipService.ACTION_SIP_UNREGIEST);
                        PortSipService.startServiceCompatibility(getActivity(), offLineIntent);
                        /// ve man hinh chinh
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                            activity.finishAndRemoveTask();
                        }
                        break;
                    case INCOMING:
                        break;
                    case TRYING:
                        System.out.println("quanth: video updateVideo TRYING");
                        updateVideo(Engine.Instance().getEngine());
                        break;
                    case CONNECTED:
                        /// Nếu nhấc máy thì cancel countdown
                        countDownTimer.cancel();
                        llWaitingView.setVisibility(View.GONE);
                        System.out.println("quanth: video updateVideo CONNECTED");
                        updateVideo(Engine.Instance().getEngine());
                        break;
                    case FAILED:
                        System.out.println("quanth: video updateVideo FAILED");
                        /// tắt cuộc gọi nếu người dùng cúp máy không nghe
                        portSipLib.hangUp(currentLine.sessionID);
                        currentLine.Reset();
                        /// logout
                        Intent logoutIntent = new Intent(getActivity(), PortSipService.class);
                        logoutIntent.setAction(PortSipService.ACTION_SIP_UNREGIEST);
                        PortSipService.startServiceCompatibility(getActivity(), logoutIntent);
                        /// ve man hinh chinh
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                            activity.finishAndRemoveTask();
                        }
                        break;
                }
            }
        } else if (PortSipService.REGISTER_CHANGE_ACTION.equals(action)) {
            System.out.println("quanth: REGISTER_CHANGE_ACTION - login");
        }
    }

}
