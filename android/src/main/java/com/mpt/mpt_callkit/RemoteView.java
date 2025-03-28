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

public class RemoteView implements PlatformView {
    private final FrameLayout containerView;
    private PortSIPVideoRenderer remoteRenderVideoView;
    private PortMessageReceiver receiver;
    CallManager callManager = CallManager.Instance();
    ;

    public RemoteView(Context context, int viewId) {

        PortSipSdk portSipLib = Engine.Instance().getEngine();
        Session cur = callManager.getCurrentSession();
        receiver = Engine.Instance().getReceiver();
        // Inflate layout từ XML
        containerView = (FrameLayout) LayoutInflater.from(context).inflate(R.layout.remote_layout, null);

        containerView.setLayoutParams(new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
        ));

        remoteRenderVideoView = containerView.findViewById(R.id.remote_video_view);

        callManager.setRemoteVideoWindow(portSipLib, cur.sessionID, remoteRenderVideoView);

        updateVideo(portSipLib);

        setupReceiver();
    }

    @Override
    public View getView() {
        return containerView;
    }

    @Override
    public void dispose() {
        // Giải phóng tài nguyên nếu cần
        callManager.setRemoteVideoWindow(Engine.Instance().getEngine(), -1, null);
        if (remoteRenderVideoView != null) {
            remoteRenderVideoView.release();
            remoteRenderVideoView = null;
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

    private void updateVideo(PortSipSdk portSipLib) {
        CallManager callManager = CallManager.Instance();
        Session cur = CallManager.Instance().getCurrentSession();

        if (Engine.Instance().mConference) {
            System.out.println("quanth: application.mConference = true && setConferenceVideoWindow");
            callManager.setConferenceVideoWindow(portSipLib, remoteRenderVideoView);
        } else {
            System.out.println("quanth: application.mConference = false");
            if (cur != null && !cur.IsIdle() && cur.sessionID != -1) {
                if (cur.hasVideo) {
                    remoteRenderVideoView.setVisibility(View.VISIBLE);
                    callManager.setRemoteVideoWindow(portSipLib, cur.sessionID, remoteRenderVideoView);
                    portSipLib.sendVideo(cur.sessionID, true);
                } else {
                    remoteRenderVideoView.setVisibility(View.VISIBLE);
                    callManager.setRemoteVideoWindow(portSipLib, cur.sessionID, null);
                    if (cur.bScreenShare) {
                        callManager.setShareVideoWindow(portSipLib, cur.sessionID, remoteRenderVideoView);
                    }
                }

            } else {
                callManager.setRemoteVideoWindow(portSipLib, -1, null);
            }
        }
    }
}
