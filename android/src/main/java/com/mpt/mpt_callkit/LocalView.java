package com.mpt.mpt_callkit;

import android.content.Context;
import android.content.Intent;
import android.view.LayoutInflater;
import android.view.View;
import android.widget.FrameLayout;

import io.flutter.plugin.platform.PlatformView;

import com.mpt.mpt_callkit.receiver.PortMessageReceiver;
import com.mpt.mpt_callkit.util.CallManager;
import com.mpt.mpt_callkit.util.Engine;
import com.mpt.mpt_callkit.util.Session;
import com.portsip.PortSIPVideoRenderer;
import com.portsip.PortSipSdk;

public class LocalView implements PlatformView {
    private final FrameLayout containerView;
    private PortSIPVideoRenderer localRenderVideoView;
    private PortMessageReceiver receiver;

    public LocalView(Context context, int viewId) {
        Session currentLine = CallManager.Instance().getCurrentSession();
        PortSipSdk portSipLib = Engine.Instance().getEngine();
        receiver = Engine.Instance().getReceiver();

        containerView = (FrameLayout) LayoutInflater.from(context).inflate(R.layout.local_layout, null);
        
        containerView.setLayoutParams(new FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT, 
            FrameLayout.LayoutParams.MATCH_PARENT
        ));
        
        localRenderVideoView = containerView.findViewById(R.id.local_video_view);

        portSipLib.displayLocalVideo(true, true, localRenderVideoView);

        updateVideo(Engine.Instance().getEngine());

        setupReceiver();
    }

    @Override
    public View getView() {
        return containerView;
    }

    @Override
    public void dispose() {
        // Giải phóng tài nguyên video
        PortSipSdk portSipLib = Engine.Instance().getEngine();
        if (portSipLib != null) {
            portSipLib.displayLocalVideo(false, false, null);
        }

        if (localRenderVideoView != null) {
            localRenderVideoView.release();
            localRenderVideoView = null;
        }
    }

    private void handleSwitchCamera() {
        boolean value = !Engine.Instance().mUseFrontCamera;
        SetCamera(Engine.Instance().getEngine(), value);
        Engine.Instance().mUseFrontCamera = value;
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

        if (Engine.Instance().mConference) {
            System.out.println("quanth: application.mConference = true && setConferenceVideoWindow");
        } else {
            System.out.println("quanth: application.mConference = false");

            if (cur != null && !cur.IsIdle() && cur.sessionID != -1) {

                /*HAVE TO HANDLE CHANGE VOICE CALL TO VIDEO CALL FIRST THEN REMOVE THIS COMMENT*/
            
                // if (cur.hasVideo) {
                //     portSipLib.displayLocalVideo(true, true, localRenderVideoView);
                //     portSipLib.sendVideo(cur.sessionID, true);
                // } else {
                //     localRenderVideoView.setVisibility(View.GONE);
                //     portSipLib.displayLocalVideo(false, false, null);
                // }

                portSipLib.displayLocalVideo(true, true, localRenderVideoView);
            } else {
                portSipLib.displayLocalVideo(false, false, null);
            }
        }
    }

    private void setupReceiver() {
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
                    case INCOMING:
                        break;
                    case TRYING:
                    case CONNECTED:
                        updateVideo(Engine.Instance().getEngine());
                        break;
                    case FAILED:
                        // Tắt cuộc gọi nếu người dùng cúp máy không nghe
                        portSipLib.hangUp(currentLine.sessionID);
                        currentLine.Reset();
                        break;
                }
            }
        }
    }
}
