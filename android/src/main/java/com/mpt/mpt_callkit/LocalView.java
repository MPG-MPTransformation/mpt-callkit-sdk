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
    private PortMessageReceiver.BroadcastListener localViewListener;

    public LocalView(Context context, int viewId) {
        Session currentLine = CallManager.Instance().getCurrentSession();
        PortSipSdk portSipLib = Engine.Instance().getEngine();
        receiver = Engine.Instance().getReceiver();

        // If receiver is null, create a new one (FCM might have reset it)
        if (receiver == null) {
            System.out.println("SDK-Android: LocalView - Receiver is null, creating new one");
            receiver = new PortMessageReceiver();
            Engine.Instance().setReceiver(receiver);
        }

        containerView = (FrameLayout) LayoutInflater.from(context).inflate(R.layout.local_layout, null);

        containerView.setLayoutParams(new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT));

        localRenderVideoView = containerView.findViewById(R.id.local_video_view);

        portSipLib.displayLocalVideo(true, Engine.Instance().mUseFrontCamera, localRenderVideoView);

        updateVideo(Engine.Instance().getEngine());

        setupReceiver();
    }

    @Override
    public View getView() {
        return containerView;
    }

    public void setCameraMirror() {
        try {
            // Ensure camera is properly initialized before displaying
            if (Engine.Instance().getEngine() != null) {
                PortSipSdk portSipLib = Engine.Instance().getEngine();
                portSipLib.displayLocalVideo(true, Engine.Instance().mUseFrontCamera, localRenderVideoView);
                System.out.println("SDK-Android: LocalView - Camera mirror set successfully");
            } else {
                System.out.println("SDK-Android: LocalView - Engine not initialized, cannot set camera mirror");
            }
        } catch (Exception e) {
            System.out.println("SDK-Android: LocalView - Error setting camera mirror: " + e.getMessage());
        }
    }

    @Override
    public void dispose() {
        try {
            // Giải phóng tài nguyên video
            PortSipSdk portSipLib = Engine.Instance().getEngine();
            if (portSipLib != null) {
                Engine.Instance().mUseFrontCamera = true;
                portSipLib.displayLocalVideo(false, Engine.Instance().mUseFrontCamera, null);
            }

            if (localRenderVideoView != null) {
                localRenderVideoView.release();
                localRenderVideoView = null;
            }

            // Giải phóng receiver nếu cần
            if (receiver != null) {
                receiver.removePersistentListenerByTag("LocalView");
                System.out.println("SDK-Android: broadcastReceiver - local_view - removed persistent listener");
            }
        } catch (Exception e) {
            System.out.println("Error disposing LocalView: " + e.getMessage());
        }
    }

    private void updateVideo(PortSipSdk portSipLib) {
        CallManager callManager = CallManager.Instance();
        Session cur = CallManager.Instance().getCurrentSession();

        // Debug logging
        System.out.println("SDK-Android: LocalView updateVideo - Engine initialized: " + (portSipLib != null));
        System.out.println("SDK-Android: LocalView updateVideo - Current session: " + (cur != null));
        if (cur != null) {
            System.out.println("SDK-Android: LocalView updateVideo - Session state: " + cur.state);
            System.out.println("SDK-Android: LocalView updateVideo - Session ID: " + cur.sessionID);
            System.out.println("SDK-Android: LocalView updateVideo - Video muted: " + cur.bMuteVideo);
            System.out.println("SDK-Android: LocalView updateVideo - Has video: " + cur.hasVideo);
        }

        if (Engine.Instance().mConference) {
            System.out.println("SDK-Android: application.mConference = true && setConferenceVideoWindow");
        } else {
            System.out.println("SDK-Android: application.mConference = false");

            if (cur != null && !cur.IsIdle() && cur.sessionID != -1) {
                // Kiểm tra xem video có bị mute không
                if (cur.bMuteVideo) {
                    // Nếu video bị mute, ẩn local view
                    System.out.println("SDK-Android: Video is muted, hiding local view");
                    if (localRenderVideoView != null) {
                        localRenderVideoView.setVisibility(View.GONE);
                    }
                    // Vẫn có thể tiếp tục gửi video nếu cần, nhưng không hiển thị
                    portSipLib.displayLocalVideo(false, Engine.Instance().mUseFrontCamera, null);
                } else {
                    // Nếu video không bị mute, hiển thị local view
                    System.out.println("SDK-Android: Video is not muted, showing local view");
                    if (localRenderVideoView != null) {
                        localRenderVideoView.setVisibility(View.VISIBLE);
                    }
                    
                    // Check if camera is properly initialized
                    if (Engine.Instance().mUseFrontCamera != null) {
                        portSipLib.displayLocalVideo(true, Engine.Instance().mUseFrontCamera, localRenderVideoView);
                        int sendResult = portSipLib.sendVideo(cur.sessionID, true);
                        System.out.println("SDK-Android: sendVideo result: " + sendResult);
                    } else {
                        System.out.println("SDK-Android: Camera not initialized, cannot display local video");
                    }
                }
            } else {
                // Không có cuộc gọi đang diễn ra, tắt video
                System.out.println("SDK-Android: No active call, hide local view");
                if (localRenderVideoView != null) {
                    localRenderVideoView.setVisibility(View.GONE);
                }
                portSipLib.displayLocalVideo(false, Engine.Instance().mUseFrontCamera, null);
            }
        }
    }

    private void setupReceiver() {
        // Thêm xử lý sự kiện broadcast
        if (receiver != null) {
            localViewListener = new PortMessageReceiver.BroadcastListener() {
                @Override
                public void onBroadcastReceiver(Intent intent) {
                    handleBroadcastReceiver(intent);
                }
            };

            // Sử dụng persistent listener thay vì gán trực tiếp
            receiver.addPersistentListener(localViewListener, "LocalView");
            System.out.println("SDK-Android: broadcastReceiver - local_view - added persistent listener");
        } else {
            System.out.println("SDK-Android: broadcastReceiver - local_view - receiver is null");
        }
    }

    /**
     * Re-register listener if receiver was reset (e.g., after FCM background
     * processing)
     */
    public void ensureListenerRegistered() {
        if (receiver != null && localViewListener != null) {
            // Check if our listener is still registered
            if (receiver.getListenersCount() == 0) {
                System.out.println("SDK-Android: LocalView - Receiver appears to be reset, re-registering listener");
                receiver.addPersistentListener(localViewListener, "LocalView");
            }
        }
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
                    case TRYING:
                    case CONNECTED:
                        updateVideo(Engine.Instance().getEngine());
                        break;
                    case FAILED:
                        // Tắt cuộc gọi nếu người dùng cúp máy không nghe
                        MptCallkitPlugin.hangup();
                        currentLine.Reset();
                        break;
                }
            }
        } else if (action != null && action.equals("VIDEO_MUTE_STATE_CHANGED")) {
            // Thêm phần xử lý khi trạng thái mute video thay đổi
            updateVideo(Engine.Instance().getEngine());
        } else if (action != null && action.equals("CAMERA_SWITCH_ACTION")) {
            // Xử lý khi camera được switch
            boolean useFrontCamera = intent.getBooleanExtra("useFrontCamera", true);
            System.out.println(
                    "SDK-Android: LocalView received camera switch broadcast - useFrontCamera: " + useFrontCamera);
            setCameraMirror();
        }
    }
}
