package com.mpt.mpt_callkit;

import android.content.Context;
import io.flutter.plugin.common.StandardMessageCodec;
import io.flutter.plugin.platform.PlatformView;
import io.flutter.plugin.platform.PlatformViewFactory;
import android.graphics.Bitmap;

public class LocalViewFactory extends PlatformViewFactory {
    private final Context context;
    private LocalView localView;

    public void setImage(Bitmap bitmap) {
        if (localView != null) {
            System.out.println("SDK-Android: LocalViewFactory - setImage called with bitmap: " + bitmap);
            localView.setImage(bitmap);
        }
    }

    public LocalViewFactory(Context context) {
        super(StandardMessageCodec.INSTANCE);
        if (context == null) {
            throw new IllegalArgumentException("Context cannot be null");
        }
        this.context = context;
    }

    @Override
    public PlatformView create(Context context, int viewId, Object args) {
        if (context == null) {
            throw new IllegalArgumentException("Context cannot be null");
        }
        localView = new LocalView(this.context, viewId);
        return localView;
    }
}