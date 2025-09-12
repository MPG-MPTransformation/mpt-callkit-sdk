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

import androidx.annotation.NonNull;
import androidx.camera.core.CameraSelector;
import androidx.camera.core.ImageAnalysis;
import androidx.camera.core.ImageProxy;
import androidx.camera.core.Preview;
import androidx.camera.lifecycle.ProcessCameraProvider;
import androidx.camera.view.PreviewView;
import androidx.core.content.ContextCompat;
import androidx.lifecycle.LifecycleOwner;
import androidx.lifecycle.ProcessLifecycleOwner;
import android.util.Log;
import android.util.Size;

import com.google.common.util.concurrent.ListenableFuture;
import com.google.mlkit.vision.common.InputImage;
import com.mpt.mpt_callkit.segmenter.GraphicOverlay;
import com.mpt.mpt_callkit.segmenter.SegmenterProcessor;

import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class LocalView implements PlatformView {
    private final FrameLayout containerView;
    private PortSIPVideoRenderer localRenderVideoView;
    private PortMessageReceiver receiver;
    private PortMessageReceiver.BroadcastListener localViewListener;

    private PreviewView previewView;
    private GraphicOverlay graphicOverlay;
    private final ExecutorService cameraExecutor;
    private SegmenterProcessor segmenterProcessor;

    // Throttling for ML Kit processing
    private volatile boolean isProcessing = false;
    private long lastProcessTime = 0;
    private static final long PROCESSING_INTERVAL_MS = 200; // Process at most every 200ms (reduced frequency)
    private volatile boolean isViewActive = true;

    public LocalView(Context context, int viewId) {
        // Inflate layout with both PreviewView and GraphicOverlay
        containerView = (FrameLayout) LayoutInflater.from(context).inflate(R.layout.local_layout, null);

        containerView.setLayoutParams(new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT));

        // Get references to views
        previewView = containerView.findViewById(R.id.preview_view);
        graphicOverlay = containerView.findViewById(R.id.graphic_overlay);

        cameraExecutor = Executors.newSingleThreadExecutor();

        // Initialize ML Kit Selfie Segmenter Processor
        segmenterProcessor = new SegmenterProcessor(context);

        startCamera(context);
    }

    private void startCamera(Context context) {
        ListenableFuture<ProcessCameraProvider> cameraProviderFuture = ProcessCameraProvider.getInstance(context);

        cameraProviderFuture.addListener(() -> {
            try {
                ProcessCameraProvider cameraProvider = cameraProviderFuture.get();

                Preview preview = new Preview.Builder().build();
                preview.setSurfaceProvider(previewView.getSurfaceProvider());

                ImageAnalysis imageAnalysis = new ImageAnalysis.Builder()
                        .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                        .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_YUV_420_888)
                        .setTargetResolution(new Size(480, 360)) // Even lower resolution for better performance
                        .build();

                imageAnalysis.setAnalyzer(cameraExecutor, imageProxy -> {
                    try {
                        processImageProxy(imageProxy);
                    } catch (Exception e) {
                        Log.e("LocalView", "Error in analyzer: " + e.getMessage());
                        imageProxy.close();
                    }
                });

                CameraSelector cameraSelector = CameraSelector.DEFAULT_FRONT_CAMERA;

                cameraProvider.unbindAll();
                cameraProvider.bindToLifecycle(
                        ProcessLifecycleOwner.get(), cameraSelector, preview, imageAnalysis);

            } catch (Exception e) {
                e.printStackTrace();
            }
        }, ContextCompat.getMainExecutor(context));
    }

    private void processImageProxy(@NonNull ImageProxy imageProxy) {
        // Skip processing if view is not active
        if (!isViewActive) {
            imageProxy.close();
            return;
        }

        // Skip processing if already processing a frame to prevent buffer overflow
        if (isProcessing) {
            imageProxy.close();
            return;
        }

        // Throttle processing to reduce load
        long currentTime = System.currentTimeMillis();
        if (currentTime - lastProcessTime < PROCESSING_INTERVAL_MS) {
            imageProxy.close();
            return;
        }
        lastProcessTime = currentTime;

        if (imageProxy.getImage() == null) {
            imageProxy.close();
            return;
        }

        try {
            isProcessing = true;

            InputImage image = InputImage.fromMediaImage(
                    imageProxy.getImage(),
                    imageProxy.getImageInfo().getRotationDegrees());

            // Set image source info for the overlay
            graphicOverlay.setImageSourceInfo(
                    imageProxy.getWidth(),
                    imageProxy.getHeight(),
                    false); // Set to true if using front camera

            // Clear previous overlays
            graphicOverlay.clear();

            // Process with the segmenter processor with proper callback handling
            processImageWithSegmentation(image, imageProxy);

        } catch (Exception e) {
            Log.e("LocalView", "Error processing image: " + e.getMessage());
            isProcessing = false;
            imageProxy.close();
        }
    }

    private void processImageWithSegmentation(InputImage image, ImageProxy imageProxy) {
        if (segmenterProcessor != null) {
            // Use detectInImage directly with proper callbacks
            segmenterProcessor.detectInImage(image)
                    .addOnSuccessListener(mask -> {
                        try {
                            // Add segmentation graphic to overlay
                            graphicOverlay
                                    .add(new com.mpt.mpt_callkit.segmenter.SegmentationGraphic(graphicOverlay, mask));
                        } catch (Exception e) {
                            Log.e("LocalView", "Error in segmentation success: " + e.getMessage());
                        } finally {
                            isProcessing = false;
                            imageProxy.close();
                        }
                    })
                    .addOnFailureListener(e -> {
                        Log.e("LocalView", "Segmentation failed: " + e.getMessage());
                        isProcessing = false;
                        imageProxy.close();
                    });
        } else {
            isProcessing = false;
            imageProxy.close();
        }
    }

    @Override
    public View getView() {
        return containerView;
    }

    public void setCameraMirror() {
        // TODO: Implement camera mirror functionality
        // PortSipSdk portSipLib = Engine.Instance().getEngine();
        // if (portSipLib != null) {
        // portSipLib.displayLocalVideo(true, Engine.Instance().mUseFrontCamera,
        // localRenderVideoView);
        // }
    }

    /**
     * Pause processing to reduce resource usage when view is not visible
     */
    public void pauseProcessing() {
        Log.d("LocalView", "Pausing ML Kit processing");
        isViewActive = false;
    }

    /**
     * Resume processing when view becomes visible again
     */
    public void resumeProcessing() {
        Log.d("LocalView", "Resuming ML Kit processing");
        isViewActive = true;
    }

    // @Override
    // public void dispose() {
    // try {
    // // Giải phóng tài nguyên video
    // PortSipSdk portSipLib = Engine.Instance().getEngine();
    // if (portSipLib != null) {
    // Engine.Instance().mUseFrontCamera = true;
    // portSipLib.displayLocalVideo(false, Engine.Instance().mUseFrontCamera, null);
    // }
    //
    // if (localRenderVideoView != null) {
    // localRenderVideoView.release();
    // localRenderVideoView = null;
    // }
    //
    // // Giải phóng receiver nếu cần
    // if (receiver != null) {
    // receiver.removePersistentListenerByTag("LocalView");
    // System.out.println("SDK-Android: broadcastReceiver - local_view - removed
    // persistent listener");
    // }
    // } catch (Exception e) {
    // System.out.println("Error disposing LocalView: " + e.getMessage());
    // }
    // }

    @Override
    public void dispose() {
        try {
            Log.d("LocalView", "Disposing LocalView...");
            isViewActive = false; // Stop all processing immediately
            isProcessing = false;

            // Unbind camera to stop frame processing
            try {
                ListenableFuture<ProcessCameraProvider> cameraProviderFuture = ProcessCameraProvider
                        .getInstance(containerView.getContext());
                ProcessCameraProvider cameraProvider = cameraProviderFuture.get();
                cameraProvider.unbindAll();
            } catch (Exception e) {
                Log.w("LocalView", "Error unbinding camera: " + e.getMessage());
            }

            if (cameraExecutor != null && !cameraExecutor.isShutdown()) {
                cameraExecutor.shutdown();
                try {
                    if (!cameraExecutor.awaitTermination(1, java.util.concurrent.TimeUnit.SECONDS)) {
                        cameraExecutor.shutdownNow();
                    }
                } catch (InterruptedException e) {
                    cameraExecutor.shutdownNow();
                }
            }

            if (graphicOverlay != null) {
                graphicOverlay.clear();
            }

            // Clean up segmenter processor
            segmenterProcessor = null;

        } catch (Exception e) {
            Log.e("LocalView", "Error disposing LocalView: " + e.getMessage());
        }
    }

    private void updateVideo(PortSipSdk portSipLib) {
        // TODO: Implement video update functionality
        // CallManager callManager = CallManager.Instance();
        // Session cur = CallManager.Instance().getCurrentSession();
        //
        // if (Engine.Instance().mConference) {
        // System.out.println("SDK-Android: application.mConference = true &&
        // setConferenceVideoWindow");
        // } else {
        // System.out.println("SDK-Android: application.mConference = false");
        //
        // if (cur != null && !cur.IsIdle() && cur.sessionID != -1) {
        // // Kiểm tra xem video có bị mute không
        // if (cur.bMuteVideo) {
        // // Nếu video bị mute, ẩn local view
        // System.out.println("SDK-Android: Video is muted, hiding local view");
        // if (localRenderVideoView != null) {
        // localRenderVideoView.setVisibility(View.GONE);
        // }
        // // Vẫn có thể tiếp tục gửi video nếu cần, nhưng không hiển thị
        // portSipLib.displayLocalVideo(false, Engine.Instance().mUseFrontCamera, null);
        // } else {
        // // Nếu video không bị mute, hiển thị local view
        // System.out.println("SDK-Android: Video is not muted, showing local view");
        // if (localRenderVideoView != null) {
        // localRenderVideoView.setVisibility(View.VISIBLE);
        // }
        // portSipLib.displayLocalVideo(true, Engine.Instance().mUseFrontCamera,
        // localRenderVideoView);
        // portSipLib.sendVideo(cur.sessionID, true);
        // }
        // } else {
        // // Không có cuộc gọi đang diễn ra, tắt video
        // System.out.println("SDK-Android: No active call, hide local view");
        // if (localRenderVideoView != null) {
        // localRenderVideoView.setVisibility(View.GONE);
        // }
        // portSipLib.displayLocalVideo(false, Engine.Instance().mUseFrontCamera, null);
        // }
        // }
    }

    private void setupReceiver() {
        // TODO: Implement receiver setup
        // // Thêm xử lý sự kiện broadcast
        // if (receiver != null) {
        // localViewListener = new PortMessageReceiver.BroadcastListener() {
        // @Override
        // public void onBroadcastReceiver(Intent intent) {
        // handleBroadcastReceiver(intent);
        // }
        // };
        //
        // // Sử dụng persistent listener thay vì gán trực tiếp
        // receiver.addPersistentListener(localViewListener, "LocalView");
        // System.out.println("SDK-Android: broadcastReceiver - local_view - added
        // persistent listener");
        // } else {
        // System.out.println("SDK-Android: broadcastReceiver - local_view - receiver is
        // null");
        // }
    }

    /**
     * Re-register listener if receiver was reset (e.g., after FCM background
     * processing)
     */
    public void ensureListenerRegistered() {
        // TODO: Implement listener registration check
        // if (receiver != null && localViewListener != null) {
        // // Check if our listener is still registered
        // if (receiver.getListenersCount() == 0) {
        // System.out.println("SDK-Android: LocalView - Receiver appears to be reset,
        // re-registering listener");
        // receiver.addPersistentListener(localViewListener, "LocalView");
        // }
        // }
    }

    private void handleBroadcastReceiver(Intent intent) {
        // TODO: Implement broadcast receiver handling
        // PortSipSdk portSipLib = Engine.Instance().getEngine();
        // Session currentLine = CallManager.Instance().getCurrentSession();
        // String action = intent == null ? "" : intent.getAction();
        //
        // if (PortSipService.CALL_CHANGE_ACTION.equals(action)) {
        // long sessionId = intent.getLongExtra(PortSipService.EXTRA_CALL_SEESIONID,
        // Session.INVALID_SESSION_ID);
        // String status = intent.getStringExtra(PortSipService.EXTRA_CALL_DESCRIPTION);
        // Session session = CallManager.Instance().findSessionBySessionID(sessionId);
        //
        // if (session != null) {
        // switch (session.state) {
        // case TRYING:
        // case CONNECTED:
        // updateVideo(Engine.Instance().getEngine());
        // break;
        // case FAILED:
        // // Tắt cuộc gọi nếu người dùng cúp máy không nghe
        // MptCallkitPlugin.hangup();
        // currentLine.Reset();
        // break;
        // }
        // }
        // } else if (action != null && action.equals("VIDEO_MUTE_STATE_CHANGED")) {
        // // Thêm phần xử lý khi trạng thái mute video thay đổi
        // updateVideo(Engine.Instance().getEngine());
        // } else if (action != null && action.equals("CAMERA_SWITCH_ACTION")) {
        // // Xử lý khi camera được switch
        // boolean useFrontCamera = intent.getBooleanExtra("useFrontCamera", true);
        // System.out.println(
        // "SDK-Android: LocalView received camera switch broadcast - useFrontCamera: "
        // + useFrontCamera);
        // setCameraMirror();
        // }
    }
}
