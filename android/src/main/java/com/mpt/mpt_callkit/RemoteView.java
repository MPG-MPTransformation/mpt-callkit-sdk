package com.mpt.mpt_callkit;

import android.content.Context;
import android.view.LayoutInflater;
import android.view.View;
import android.widget.FrameLayout;

import io.flutter.plugin.platform.PlatformView;

import com.portsip.PortSIPVideoRenderer;

public class RemoteView implements PlatformView {
    private final FrameLayout containerView;
    private PortSIPVideoRenderer remoteVideoView;

    public RemoteView(Context context, int viewId) {
        // Inflate layout từ XML
        containerView = (FrameLayout) LayoutInflater.from(context).inflate(R.layout.remote_layout, null);

        containerView.setLayoutParams(new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
        ));

        remoteVideoView = containerView.findViewById(R.id.remote_video_view);
    }

    @Override
    public View getView() {
        return containerView;
    }

    @Override
    public void dispose() {
        // Giải phóng tài nguyên nếu cần
        if (remoteVideoView != null) {
            // Thêm mã giải phóng tài nguyên nếu PortSIPVideoRenderer cần
        }
    }
}
