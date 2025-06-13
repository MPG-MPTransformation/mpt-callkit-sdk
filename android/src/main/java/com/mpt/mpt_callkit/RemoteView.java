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
        try {
            // Đặt cửa sổ video về null trước
            if (Engine.Instance() != null && Engine.Instance().getEngine() != null) {
                CallManager.Instance().setRemoteVideoWindow(Engine.Instance().getEngine(), -1, null);
            }
            
            // Giải phóng renderer
            if (remoteRenderVideoView != null) {
                remoteRenderVideoView.release();
                remoteRenderVideoView = null;
            }
            
            // Giải phóng receiver nếu cần
            if (receiver != null && receiver.broadcastReceiver != null) {
                receiver.broadcastReceiver = null;
                System.out.println("quanth: broadcastReceiver - remote_view - set null");
            }
        } catch (Exception e) {
            System.out.println("Error disposing RemoteView: " + e.getMessage());
        }
    }

    private void setupReceiver() {
        // Thêm xử lý sự kiện broadcast
        if (receiver != null) {
            receiver.broadcastReceiver = new PortMessageReceiver.BroadcastListener() {
                @Override
                public void onBroadcastReceiver(Intent intent) {
                    handleBroadcastReceiver(intent);
                }
            };
            System.out.println("quanth: broadcastReceiver - remote_view - set: " + receiver.broadcastReceiver.toString());
        } else {
            System.out.println("quanth: broadcastReceiver - remote_view - set null ");
        }
    }

    private void handleBroadcastReceiver(Intent intent) {
        try {
            if (intent == null) return;
            
            PortSipSdk portSipLib = Engine.Instance().getEngine();
            if (portSipLib == null) return;
            
            Session currentLine = CallManager.Instance().getCurrentSession();
            String action = intent.getAction();
            if (action == null) return;

            if (PortSipService.CALL_CHANGE_ACTION.equals(action)) {
                long sessionId = intent.getLongExtra(PortSipService.EXTRA_CALL_SEESIONID, Session.INVALID_SESSION_ID);
                String status = intent.getStringExtra(PortSipService.EXTRA_CALL_DESCRIPTION);
                Session session = CallManager.Instance().findSessionBySessionID(sessionId);

                if (session != null) {
                    switch (session.state) {
                        case INCOMING:
                            // Xử lý cuộc gọi đến nếu cần
                            break;
                        case TRYING:
                        case CONNECTED:
                            // Cập nhật trạng thái video khi kết nối
                            if (remoteRenderVideoView != null) {
                                updateVideo(Engine.Instance().getEngine());
                            }
                            break;
                        case FAILED:
                            // Tắt cuộc gọi nếu người dùng cúp máy không nghe
                            if (currentLine != null && currentLine.sessionID > 0) {
                                MptCallkitPlugin.hangup();
                                currentLine.Reset();
                            }
                            break;
                    }
                }
            }
        } catch (Exception e) {
            System.out.println("Error in handleBroadcastReceiver: " + e.getMessage());
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
                    System.out.println("quanth: application.mConference = false - cur.hasVideo = true");
                    if (remoteRenderVideoView != null) {
                        remoteRenderVideoView.setVisibility(View.VISIBLE);
                    }
                    callManager.setRemoteVideoWindow(portSipLib, cur.sessionID, remoteRenderVideoView);
                    portSipLib.sendVideo(cur.sessionID, true);
                } else {
                    System.out.println("quanth: application.mConference = false - cur.hasVideo = false");
                    if (remoteRenderVideoView != null) {
                        remoteRenderVideoView.setVisibility(View.VISIBLE);
                    }
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
