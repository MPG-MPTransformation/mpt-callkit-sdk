package com.mpt.mpt_callkit;

import android.app.AlertDialog;
import android.content.DialogInterface;
import android.widget.Button;
import android.widget.Toast;
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
    private boolean shareInSmall = true;
    private boolean isMicOn = true;
    private boolean isVolumeOn = true;
    private boolean isVideoOn = true;

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

        imgScaleType.setOnClickListener(this);
        imgSwitchCamera.setOnClickListener(this);
        imgMicOn.setOnClickListener(this);
        imgHangOut.setOnClickListener(this);
        imgMute.setOnClickListener(this);
        imgVideo.setOnClickListener(this);
        imgBack.setOnClickListener(this);

        localRenderScreen = (PortSIPVideoRenderer) view.findViewById(R.id.local_video_view);
        remoteRenderScreen = (PortSIPVideoRenderer) view.findViewById(R.id.remote_video_view);
        remoteRenderSmallScreen = (PortSIPVideoRenderer) view.findViewById(R.id.share_video_view);
        remoteRenderSmallScreen.setOnClickListener(this);
        scalingType = PortSIPVideoRenderer.ScalingType.SCALE_ASPECT_FIT;//
        remoteRenderScreen.setScalingType(scalingType);
        PortSipSdk portSipLib = Engine.Instance().getEngine();
        updateVideo(portSipLib);
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
            Engine.Instance().mUseFrontCamera = !Engine.Instance().mUseFrontCamera;
            SetCamera(portSipLib, Engine.Instance().mUseFrontCamera);
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
            System.out.println("quanth: isMicOn before: "+isMicOn);
            isMicOn = !isMicOn;
            System.out.println("quanth: isMicOn after: "+isMicOn);
            if(isMicOn) {
                imgMicOn.setImageResource(R.drawable.mic_on);
            } else {
                imgMicOn.setImageResource(R.drawable.mic_off);
            }
        } else if (v.getId() == R.id.ibhangout) {
            /// Tat cuoc goi
            portSipLib.hangUp(currentLine.sessionID);
            /// logout
            Intent offLineIntent = new Intent(getActivity(), PortSipService.class);
            offLineIntent.setAction(PortSipService.ACTION_SIP_UNREGIEST);
            PortSipService.startServiceCompatibility(getActivity(), offLineIntent);
            /// ve man hinh chinh
            activity.finishAndRemoveTask();
        } else if (v.getId() == R.id.mute) {
            if (currentLine.bMute) {
                portSipLib.muteSession(currentLine.sessionID, false,
                        false, false, false);
                currentLine.bMute = false;
                imgMute.setImageResource(R.drawable.volume_off);
            } else {
                portSipLib.muteSession(currentLine.sessionID, true,
                        true, true, true);
                currentLine.bMute = true;
                imgMute.setImageResource(R.drawable.volume_on);
            }
        } else if(v.getId() == R.id.ibvideo){
            System.out.println("quanth: isVideoOn before: "+isVideoOn);
            isVideoOn = !isVideoOn;
            System.out.println("quanth: isVideoOn after: "+isVideoOn);
            if(isVideoOn) {
                imgVideo.setImageResource(R.drawable.camera_on);
            } else {
                imgVideo.setImageResource(R.drawable.camera_off);
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
                        /// logout
                        Intent offLineIntent = new Intent(getActivity(), PortSipService.class);
                        offLineIntent.setAction(PortSipService.ACTION_SIP_UNREGIEST);
                        PortSipService.startServiceCompatibility(getActivity(), offLineIntent);
                        /// ve man hinh chinh
                        activity.finishAndRemoveTask();
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
            portSipLib.setVideoDeviceId(1);
        } else {
            portSipLib.setVideoDeviceId(0);
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
        System.out.println("quanth: video updateVideo");
        CallManager callManager = CallManager.Instance();
        Session cur = CallManager.Instance().getCurrentSession();
        if (Engine.Instance().mConference) {
            System.out.println("quanth: application.mConference = true && setConferenceVideoWindow");
            callManager.setConferenceVideoWindow(portSipLib, remoteRenderScreen);
        } else {
            System.out.println("quanth: application.mConference = false");
            if (cur != null && !cur.IsIdle()
                    && cur.sessionID != PortSipErrorcode.INVALID_SESSION_ID) {

                if (cur.hasVideo) {
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
                    portSipLib.displayLocalVideo(true, true, localRenderScreen); // display Local video
                    portSipLib.sendVideo(cur.sessionID, true);
                } else {
                    remoteRenderSmallScreen.setVisibility(View.GONE);
                    localRenderScreen.setVisibility(View.GONE);
                    remoteRenderScreen.setVisibility(View.VISIBLE);

                    portSipLib.displayLocalVideo(false, false, null);
                    callManager.setRemoteVideoWindow(portSipLib, cur.sessionID, null);
                    if (cur.bScreenShare) {
                        callManager.setShareVideoWindow(portSipLib, cur.sessionID, remoteRenderScreen);
                    }
                }
            } else {
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
                        /// logout
                        Intent offLineIntent = new Intent(getActivity(), PortSipService.class);
                        offLineIntent.setAction(PortSipService.ACTION_SIP_UNREGIEST);
                        PortSipService.startServiceCompatibility(getActivity(), offLineIntent);
                        /// ve man hinh chinh
                        activity.finishAndRemoveTask();
                        break;
                    case INCOMING:
                        break;
                    case TRYING:
                        break;
                    case CONNECTED:
                    case FAILED:
                        updateVideo(Engine.Instance().getEngine());
                        break;
                }
            }
        } else if (PortSipService.REGISTER_CHANGE_ACTION.equals(action)) {
            System.out.println("quanth: REGISTER_CHANGE_ACTION - login");
        }
    }

}
