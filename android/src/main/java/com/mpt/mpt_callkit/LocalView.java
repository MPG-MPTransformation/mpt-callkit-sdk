package com.mpt.mpt_callkit;

import android.content.Context;
import android.view.LayoutInflater;
import android.view.View;
import android.widget.FrameLayout;

import io.flutter.plugin.platform.PlatformView;

import com.portsip.PortSIPVideoRenderer;

public class LocalView implements PlatformView {
    private final FrameLayout containerView;
    private PortSIPVideoRenderer localVideoView;

    public LocalView(Context context, int viewId) {
        // Inflate layout từ XML
        containerView = (FrameLayout) LayoutInflater.from(context).inflate(R.layout.local_layout, null);
        
        // Thiết lập kích thước cụ thể thay vì match_parent
        containerView.setLayoutParams(new FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT, 
            FrameLayout.LayoutParams.MATCH_PARENT
        ));
        
        // Lấy tham chiếu đến local video view
        localVideoView = containerView.findViewById(R.id.local_video_view);
    }

    @Override
    public View getView() {
        return containerView;
    }

    @Override
    public void dispose() {
        // Giải phóng tài nguyên nếu cần
        if (localVideoView != null) {
            // Thêm mã giải phóng tài nguyên nếu PortSIPVideoRenderer cần
        }
    }
}
