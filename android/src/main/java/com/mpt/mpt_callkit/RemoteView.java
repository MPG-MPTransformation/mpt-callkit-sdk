package com.mpt.mpt_callkit;

import android.content.Context;
import android.content.Intent;
import android.view.LayoutInflater;
import android.view.View;
import android.widget.FrameLayout;
import androidx.annotation.NonNull;
import android.os.Handler;
import android.os.Looper;

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
    private PortMessageReceiver.BroadcastListener remoteViewListener;
    private Handler scalingHandler;
    private Runnable scalingRunnable;

    public RemoteView(@NonNull Context context, int viewId) {

        PortSipSdk portSipLib = Engine.Instance().getEngine();
        Session cur = callManager.getCurrentSession();
        receiver = Engine.Instance().getReceiver();

        // If receiver is null, create a new one (FCM might have reset it)
        if (receiver == null) {
            System.out.println("SDK-Android: RemoteView - Receiver is null, creating new one");
            receiver = new PortMessageReceiver();
            Engine.Instance().setReceiver(receiver);
        }

        // Inflate layout từ XML
        containerView = (FrameLayout) LayoutInflater.from(context).inflate(R.layout.remote_layout, null);

        containerView.setLayoutParams(new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT));

        remoteRenderVideoView = containerView.findViewById(R.id.remote_video_view);
        remoteRenderVideoView.setScalingType(PortSIPVideoRenderer.ScalingType.SCALE_ASPECT_FILL);

        callManager.setRemoteVideoWindow(portSipLib, cur.sessionID, remoteRenderVideoView);

        updateVideo(portSipLib);

        setupReceiver();
        
        // 🔥 FIX: Start timer to continuously force scaling type
        startScalingTimer();
    }
    
    private void startScalingTimer() {
        scalingHandler = new Handler(Looper.getMainLooper());
        scalingRunnable = new Runnable() {
            @Override
            public void run() {
                if (remoteRenderVideoView != null) {
                    remoteRenderVideoView.setScalingType(PortSIPVideoRenderer.ScalingType.SCALE_ASPECT_FILL);
                }
                scalingHandler.postDelayed(this, 500);
            }
        };
        scalingHandler.postDelayed(scalingRunnable, 500);
    }
    
    private void stopScalingTimer() {
        if (scalingHandler != null && scalingRunnable != null) {
            scalingHandler.removeCallbacks(scalingRunnable);
            System.out.println("SDK-Android: RemoteView - Stopped scaling timer");
        }
    }

    @Override
    public View getView() {
        return containerView;
    }

    @Override
    public void dispose() {
        // Giải phóng tài nguyên nếu cần
        try {
            // 🔥 FIX: Stop scaling timer
            stopScalingTimer();
            
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
            if (receiver != null) {
                receiver.removePersistentListenerByTag("RemoteView");
                System.out.println("SDK-Android: broadcastReceiver - remote_view - removed persistent listener");
            }
        } catch (Exception e) {
            System.out.println("Error disposing RemoteView: " + e.getMessage());
        }
    }

    private void setupReceiver() {
        // Thêm xử lý sự kiện broadcast
        if (receiver != null) {
            remoteViewListener = new PortMessageReceiver.BroadcastListener() {
                @Override
                public void onBroadcastReceiver(Intent intent) {
                    System.out.println("SDK-Android: broadcastReceiver - onBroadcastReceiver - " + intent.toString());
                    handleBroadcastReceiver(intent);
                }
            };

            // Sử dụng persistent listener thay vì gán trực tiếp
            receiver.addPersistentListener(remoteViewListener, "RemoteView");
            System.out.println("SDK-Android: broadcastReceiver - remote_view - added persistent listener");
        } else {
            System.out.println("SDK-Android: broadcastReceiver - remote_view - receiver is null");
        }
    }

    /**
     * Re-register listener if receiver was reset (e.g., after FCM background
     * processing)
     */
    public void ensureListenerRegistered() {
        if (receiver != null && remoteViewListener != null) {
            // Check if our listener is still registered
            if (receiver.getListenersCount() == 0) {
                System.out.println("SDK-Android: RemoteView - Receiver appears to be reset, re-registering listener");
                receiver.addPersistentListener(remoteViewListener, "RemoteView");
            }
        }
    }

    private void handleBroadcastReceiver(Intent intent) {
        System.out.println("SDK-Android: handleBroadcastReceiver");
        try {
            if (intent == null) {
                System.out.println("SDK-Android: handleBroadcastReceiver - intent null");
                return;
            }

            PortSipSdk portSipLib = Engine.Instance().getEngine();
            if (portSipLib == null) {
                System.out.println("SDK-Android: handleBroadcastReceiver - portSipLib null");
                return;
            }

            Session currentLine = CallManager.Instance().getCurrentSession();
            String action = intent.getAction();
            if (action == null) {
                System.out.println("SDK-Android: handleBroadcastReceiver - action null");
                return;
            }

            if (PortSipService.CALL_CHANGE_ACTION.equals(action)) {
                long sessionId = intent.getLongExtra(PortSipService.EXTRA_CALL_SEESIONID, Session.INVALID_SESSION_ID);
                String status = intent.getStringExtra(PortSipService.EXTRA_CALL_DESCRIPTION);
                Session session = CallManager.Instance().findSessionBySessionID(sessionId);

                if (session != null) {
                    System.out.println("SDK-Android: handleBroadcastReceiver - state " + session.state);
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
                } else {
                    System.out.println("SDK-Android: handleBroadcastReceiver - session null");
                }
            } else if (PortSipService.CONFERENCE_STATE_CHANGE_ACTION.equals(action)) {
                // Xử lý khi conference state thay đổi
                boolean isConference = intent.getBooleanExtra(PortSipService.EXTRA_CONFERENCE_STATE, false);
                System.out.println("SDK-Android: RemoteView - Conference state changed to: " + isConference);
                
                if (remoteRenderVideoView != null) {
                    updateVideo(Engine.Instance().getEngine());
                }
            } else {
                System.out.println("SDK-Android: handleBroadcastReceiver - action not match");
                System.out.println("SDK-Android: handleBroadcastReceiver - action: " + action);
            }
        } catch (Exception e) {
            System.out.println("Error in handleBroadcastReceiver: " + e.getMessage());
        }
    }

    private void updateVideo(PortSipSdk portSipLib) {
        CallManager callManager = CallManager.Instance();
        Session cur = CallManager.Instance().getCurrentSession();

        if (Engine.Instance().mConference) {
            System.out.println("SDK-Android: application.mConference = true && setConferenceVideoWindow");
            callManager.setConferenceVideoWindow(portSipLib, remoteRenderVideoView);
        } else {
            System.out.println("SDK-Android: application.mConference = false");
            if (cur != null && !cur.IsIdle() && cur.sessionID != -1) {
                if (cur.hasVideo) {
                    System.out.println("SDK-Android: application.mConference = false - cur.hasVideo = true");
                    if (remoteRenderVideoView != null) {
                        // 🔥 FIX: Force set scaling type to prevent cropping
                        remoteRenderVideoView.setScalingType(PortSIPVideoRenderer.ScalingType.SCALE_ASPECT_FILL);
                        System.out.println("SDK-Android: RemoteView - Force set SCALE_ASPECT_FILL in updateVideo");
                        remoteRenderVideoView.setVisibility(View.VISIBLE);
                        
                        // 🔥 FIX: Post a delayed runnable to force set scaling after video starts
                        remoteRenderVideoView.postDelayed(new Runnable() {
                            @Override
                            public void run() {
                                remoteRenderVideoView.setScalingType(PortSIPVideoRenderer.ScalingType.SCALE_ASPECT_FILL);
                                System.out.println("SDK-Android: RemoteView - Delayed force set SCALE_ASPECT_FILL");
                            }
                        }, 500);
                    }
                    callManager.setRemoteVideoWindow(portSipLib, cur.sessionID, remoteRenderVideoView);
                    portSipLib.sendVideo(cur.sessionID, true);
                } else {
                    System.out.println("SDK-Android: application.mConference = false - cur.hasVideo = false");
                    if (remoteRenderVideoView != null) {
                        // 🔥 FIX: Force set scaling type to prevent cropping
                        remoteRenderVideoView.setScalingType(PortSIPVideoRenderer.ScalingType.SCALE_ASPECT_FILL);
                        System.out.println("SDK-Android: RemoteView - Force set SCALE_ASPECT_FILL in updateVideo (no video)");
                        remoteRenderVideoView.setVisibility(View.VISIBLE);
                    }
                    callManager.setRemoteVideoWindow(portSipLib, cur.sessionID, null);
                    portSipLib.sendVideo(cur.sessionID, true);
                    // if (cur.bScreenShare) {
                    //     callManager.setShareVideoWindow(portSipLib, cur.sessionID, remoteRenderVideoView);
                    // }
                }

            } else {
                callManager.setRemoteVideoWindow(portSipLib, -1, null);
            }
        }
    }
}
