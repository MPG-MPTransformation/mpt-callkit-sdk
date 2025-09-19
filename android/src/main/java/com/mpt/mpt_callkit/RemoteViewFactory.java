package com.mpt.mpt_callkit;

import android.content.Context;
import io.flutter.plugin.common.StandardMessageCodec;
import io.flutter.plugin.platform.PlatformView;
import io.flutter.plugin.platform.PlatformViewFactory;

public class RemoteViewFactory extends PlatformViewFactory {
//    private final Context context;
    public static RemoteView remoteView;

    public RemoteViewFactory() {
        super(StandardMessageCodec.INSTANCE);
//        if (context == null) {
//            throw new IllegalArgumentException("Context cannot be null");
//        }
//        this.context = context;
    }

    @Override
    public PlatformView create(Context context, int viewId, Object args) {
        if (context == null) {
            throw new IllegalArgumentException("Context cannot be null");
        }
        RemoteViewFactory.remoteView = new RemoteView(context, viewId); // only keep one instance
        return RemoteViewFactory.remoteView;
    }
}