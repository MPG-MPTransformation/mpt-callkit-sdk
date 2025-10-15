/*
 * Copyright 2024 MPT. All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package com.mpt.mpt_callkit.segmentation;

import android.Manifest;
import android.annotation.SuppressLint;
import android.app.Activity;
import android.content.Context;
import android.graphics.ImageFormat;
import android.graphics.Point;
import android.graphics.SurfaceTexture;
import android.hardware.camera2.CameraAccessException;
import android.hardware.camera2.CameraCaptureSession;
import android.hardware.camera2.CameraCharacteristics;
import android.hardware.camera2.CameraDevice;
import android.hardware.camera2.CameraManager;
import android.hardware.camera2.CaptureRequest;
import android.hardware.camera2.CaptureResult;
import android.hardware.camera2.TotalCaptureResult;
import android.hardware.camera2.params.StreamConfigurationMap;
import android.media.Image;
import android.media.ImageReader;
import android.os.Build;
import android.os.Handler;
import android.os.HandlerThread;
import android.util.Log;
import android.util.Size;
import android.view.Surface;
import android.view.WindowManager;
import androidx.annotation.NonNull;
import androidx.annotation.RequiresApi;
import androidx.annotation.RequiresPermission;
import com.mpt.mpt_callkit.segmentation.FrameMetadata;
import com.mpt.mpt_callkit.segmentation.VisionImageProcessor;
import java.nio.ByteBuffer;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.Comparator;
import java.util.List;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.Semaphore;

/**
 * Camera2-based camera source with improved resource management and concurrent access support.
 * 
 * Features:
 * - Better resource management than Camera1
 * - Support for concurrent camera access
 * - Automatic resolution selection based on device capabilities
 * - Proper error handling and recovery
 * - Frame processing optimization
 */
@RequiresApi(api = Build.VERSION_CODES.LOLLIPOP)
public class Camera2Source {
    private static final String TAG = "MptCallkit:Camera2Source";
    
    // Camera facing constants
    public static final int CAMERA_FACING_BACK = CameraCharacteristics.LENS_FACING_BACK;
    public static final int CAMERA_FACING_FRONT = CameraCharacteristics.LENS_FACING_FRONT;
    
    // Image format constants - use Camera2 compatible format
    public static final int IMAGE_FORMAT = ImageFormat.NV21; // Output format (matches CameraSource)
    private static final int CAPTURE_FORMAT = ImageFormat.YUV_420_888; // Camera2 native format
    
    // Resolution presets
    public static final int RESOLUTION_LOW = 0;      // 480x640
    public static final int RESOLUTION_MEDIUM = 1;   // 720x1280  
    public static final int RESOLUTION_HIGH = 2;     // 1080x1920
    public static final int RESOLUTION_AUTO = 3;     // Automatic based on device
    
    // Default resolution constants
    public static final int DEFAULT_REQUESTED_CAMERA_PREVIEW_WIDTH = 720;
    public static final int DEFAULT_REQUESTED_CAMERA_PREVIEW_HEIGHT = 1280;
    
    // Camera2 specific constants
    private static final int MAX_PREVIEW_WIDTH = 1280;
    private static final int MAX_PREVIEW_HEIGHT = 720;
    private static final int FRAME_PROCESSING_SKIP_RATE = 1;
    private static final float REQUESTED_FPS = 20.0f;
    
    // Camera state management
    private CameraDevice cameraDevice;
    private CameraCaptureSession captureSession;
    private CaptureRequest.Builder captureRequestBuilder;
    private ImageReader imageReader;
    private String cameraId;
    private int facing = CAMERA_FACING_FRONT;
    
    // Resolution configuration
    private int resolutionMode = RESOLUTION_AUTO;
    private int requestedWidth = DEFAULT_REQUESTED_CAMERA_PREVIEW_WIDTH;
    private int requestedHeight = DEFAULT_REQUESTED_CAMERA_PREVIEW_HEIGHT;
    private Size previewSize;
    private int rotationDegrees;
    
    // Threading
    private HandlerThread backgroundThread;
    private Handler backgroundHandler;
    private ExecutorService videoProcessingExecutor;
    
    // Synchronization
    private final Semaphore cameraOpenCloseLock = new Semaphore(1);
    private final Object processorLock = new Object();
    
    // Frame processing
    private VisionImageProcessor frameProcessor;
    private volatile boolean isProcessingFrame = false;
    private int frameCounter = 0;
    
    // Frame processing thread (like CameraSource)
    private Thread processingThread;
    private final FrameProcessingRunnable processingRunnable;
    
    // Activity reference
    private Activity activity;
    private CameraManager cameraManager;
    
    public Camera2Source(Activity activity, boolean useFrontCamera) {
        this.activity = activity;
        this.facing = useFrontCamera ? CAMERA_FACING_FRONT : CAMERA_FACING_BACK;
        this.cameraManager = (CameraManager) activity.getSystemService(Context.CAMERA_SERVICE);
        this.processingRunnable = new FrameProcessingRunnable();
        videoProcessingExecutor = Executors.newSingleThreadExecutor();
    }
    
    /**
     * Starts the camera and begins capturing frames
     */
    @RequiresPermission(Manifest.permission.CAMERA)
    public synchronized void start() throws CameraAccessException {
        if (cameraDevice != null) {
            return;
        }
        
        startBackgroundThread();
        openCamera();
        
        // Start processing thread (like CameraSource)
        processingThread = new Thread(processingRunnable);
        processingRunnable.setActive(true);
        processingThread.start();
        
        // Start the frame processor if it exists
        synchronized (processorLock) {
            if (frameProcessor != null) {
                frameProcessor.start();
            }
        }
        
        System.out.println("SDK-Android: Camera2Source start");
    }
    
    /**
     * Stops the camera and releases resources
     */
    public synchronized void stop() {
        // Stop processing thread (like CameraSource)
        if (processingThread != null) {
            try {
                System.out.println("SDK-Android: Camera2Source stop");
                processingRunnable.setActive(false);
                processingThread.join();
            } catch (InterruptedException e) {
                Log.d(TAG, "Frame processing thread interrupted on stop.");
            }
            processingThread = null;
        }
        
        stopBackgroundThread();
        closeCamera();
        
        if (frameProcessor != null) {
            frameProcessor.stop();
        }
    }
    
    /**
     * Releases all resources
     */
    public void release() {
        synchronized (processorLock) {
            stop();
            
            if (frameProcessor != null) {
                frameProcessor.stop();
                frameProcessor = null;
            }
            
            // Shutdown video processing executor
            if (videoProcessingExecutor != null) {
                videoProcessingExecutor.shutdown();
                try {
                    if (!videoProcessingExecutor.awaitTermination(1, TimeUnit.SECONDS)) {
                        videoProcessingExecutor.shutdownNow();
                        if (!videoProcessingExecutor.awaitTermination(1, TimeUnit.SECONDS)) {
                            Log.w(TAG, "Video processing executor did not terminate gracefully");
                        }
                    }
                } catch (InterruptedException e) {
                    videoProcessingExecutor.shutdownNow();
                    Thread.currentThread().interrupt();
                }
                videoProcessingExecutor = null;
            }
        }
    }
    
    /**
     * Sets the camera facing direction
     */
    public synchronized void setFacing(int facing) {
        if ((facing != CAMERA_FACING_BACK) && (facing != CAMERA_FACING_FRONT)) {
            throw new IllegalArgumentException("Invalid camera facing: " + facing);
        }
        this.facing = facing;
    }
    
    /**
     * Sets the camera resolution mode
     */
    public synchronized void setResolutionMode(int resolutionMode) {
        if (resolutionMode < RESOLUTION_LOW || resolutionMode > RESOLUTION_AUTO) {
            throw new IllegalArgumentException("Invalid resolution mode: " + resolutionMode);
        }
        this.resolutionMode = resolutionMode;
        updateRequestedResolution();
    }
    
    /**
     * Gets the current resolution mode
     */
    public int getResolutionMode() {
        return resolutionMode;
    }
    
    /**
     * Sets custom resolution
     */
    public synchronized void setCustomResolution(int width, int height) {
        this.requestedWidth = width;
        this.requestedHeight = height;
        this.resolutionMode = -1; // Custom mode
    }
    
    /**
     * Returns the preview size currently in use
     */
    public Size getPreviewSize() {
        return previewSize;
    }
    
    /**
     * Returns the selected camera facing
     */
    public int getCameraFacing() {
        return facing;
    }
    
    /**
     * Sets the machine learning frame processor
     */
    public void setMachineLearningFrameProcessor(VisionImageProcessor processor) {
        synchronized (processorLock) {
            if (frameProcessor != null) {
                frameProcessor.stop();
            }
            frameProcessor = processor;
            
            // If camera is already running, start the new processor
            if (cameraDevice != null && frameProcessor != null) {
                Log.d(TAG, "Starting new frame processor");
                frameProcessor.start();
            }
        }
    }
    
    /**
     * Starts background thread for camera operations
     */
    private void startBackgroundThread() {
        backgroundThread = new HandlerThread("CameraBackground");
        backgroundThread.start();
        backgroundHandler = new Handler(backgroundThread.getLooper());
    }
    
    /**
     * Stops background thread
     */
    private void stopBackgroundThread() {
        if (backgroundThread != null) {
            backgroundThread.quitSafely();
            try {
                backgroundThread.join();
                backgroundThread = null;
                backgroundHandler = null;
            } catch (InterruptedException e) {
                Log.e(TAG, "Failed to stop background thread", e);
            }
        }
    }
    
    /**
     * Opens the camera
     */
    @SuppressLint("MissingPermission")
    private void openCamera() throws CameraAccessException {
        try {
            if (!cameraOpenCloseLock.tryAcquire(2500, TimeUnit.MILLISECONDS)) {
                throw new RuntimeException("Time out waiting to lock camera opening.");
            }
        } catch (InterruptedException e) {
            throw new RuntimeException("Interrupted while trying to lock camera opening.", e);
        }
        
        try {
            // Find the camera ID
            cameraId = getCameraId(facing);
            if (cameraId == null) {
                throw new CameraAccessException(CameraAccessException.CAMERA_ERROR, 
                    "Could not find requested camera");
            }
            
            // Get camera characteristics
            CameraCharacteristics characteristics = cameraManager.getCameraCharacteristics(cameraId);
            StreamConfigurationMap map = characteristics.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP);
            if (map == null) {
                throw new CameraAccessException(CameraAccessException.CAMERA_ERROR,
                    "No stream configuration map found");
            }
            
            // Update resolution based on current mode
            updateRequestedResolution();
            
            // Select preview size
            Size[] sizes = map.getOutputSizes(CAPTURE_FORMAT);
            if (sizes == null || sizes.length == 0) {
                throw new CameraAccessException(CameraAccessException.CAMERA_ERROR,
                    "No output sizes available for format: " + CAPTURE_FORMAT);
            }
            previewSize = chooseOptimalSize(sizes, requestedWidth, requestedHeight);
            
            // Create ImageReader for capturing frames
            imageReader = ImageReader.newInstance(
                previewSize.getWidth(), 
                previewSize.getHeight(), 
                CAPTURE_FORMAT, 
                2 // Max images
            );
            
            // Set up ImageReader listener
            imageReader.setOnImageAvailableListener(new ImageReader.OnImageAvailableListener() {
                @Override
                public void onImageAvailable(ImageReader reader) {
                    processCameraFrame(reader);
                }
            }, backgroundHandler);
            
            // Calculate rotation
            calculateRotation();
            
            // Open camera
            cameraManager.openCamera(cameraId, stateCallback, backgroundHandler);
            
        } catch (CameraAccessException e) {
            cameraOpenCloseLock.release();
            throw e;
        } catch (Exception e) {
            cameraOpenCloseLock.release();
            throw new CameraAccessException(CameraAccessException.CAMERA_ERROR, "Unexpected error: " + e.getMessage());
        }
    }
    
    /**
     * Closes the camera
     */
    private void closeCamera() {
        try {
            cameraOpenCloseLock.acquire();
            
            if (captureSession != null) {
                captureSession.close();
                captureSession = null;
            }
            
            if (cameraDevice != null) {
                cameraDevice.close();
                cameraDevice = null;
            }
            
            if (imageReader != null) {
                imageReader.close();
                imageReader = null;
            }
            
            if (captureRequestBuilder != null) {
                captureRequestBuilder = null;
            }
            
        } catch (InterruptedException e) {
            throw new RuntimeException("Interrupted while trying to lock camera closing.", e);
        } finally {
            cameraOpenCloseLock.release();
        }
    }
    
    /**
     * Camera state callback
     */
    private final CameraDevice.StateCallback stateCallback = new CameraDevice.StateCallback() {
        @Override
        public void onOpened(@NonNull CameraDevice camera) {
            cameraOpenCloseLock.release();
            cameraDevice = camera;
            createCameraPreviewSession();
        }
        
        @Override
        public void onDisconnected(@NonNull CameraDevice camera) {
            cameraOpenCloseLock.release();
            camera.close();
            cameraDevice = null;
        }
        
        @Override
        public void onError(@NonNull CameraDevice camera, int error) {
            cameraOpenCloseLock.release();
            camera.close();
            cameraDevice = null;
            Log.e(TAG, "Camera error: " + error);
        }
    };
    
    /**
     * Creates camera preview session
     */
    private void createCameraPreviewSession() {
        try {
            // Create capture request
            captureRequestBuilder = cameraDevice.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW);
            captureRequestBuilder.addTarget(imageReader.getSurface());
            
            // Set auto-focus and other parameters
            captureRequestBuilder.set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_VIDEO);
            captureRequestBuilder.set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_ON);
            
            // Create capture session
            cameraDevice.createCaptureSession(Arrays.asList(imageReader.getSurface()),
                new CameraCaptureSession.StateCallback() {
                    @Override
                    public void onConfigured(@NonNull CameraCaptureSession session) {
                        if (cameraDevice == null) return;
                        
                        captureSession = session;
                        try {
                            captureRequestBuilder.set(CaptureRequest.CONTROL_AF_TRIGGER, CaptureRequest.CONTROL_AF_TRIGGER_CANCEL);
                            captureSession.setRepeatingRequest(captureRequestBuilder.build(), null, backgroundHandler);
                            
                            // Start frame processor if available
                            synchronized (processorLock) {
                                if (frameProcessor != null) {
                                    frameProcessor.start();
                                }
                            }
                            
                        } catch (CameraAccessException e) {
                            Log.e(TAG, "Failed to start camera preview", e);
                        }
                    }
                    
                    @Override
                    public void onConfigureFailed(@NonNull CameraCaptureSession session) {
                        Log.e(TAG, "Failed to configure camera capture session");
                    }
                }, backgroundHandler);
                
        } catch (CameraAccessException e) {
            Log.e(TAG, "Failed to create camera preview session", e);
        }
    }
    
    /**
     * Processes captured camera frame from ImageReader
     */
    private void processCameraFrame(ImageReader reader) {
        frameCounter++;
        
        // Skip processing if previous frame is still being processed
        if (isProcessingFrame) {
            return;
        }
        
        // Apply frame skip interval for FPS control
        if (FRAME_PROCESSING_SKIP_RATE > 1 && frameCounter % FRAME_PROCESSING_SKIP_RATE != 0) {
            return;
        }
        
        // Queue frame for processing (like CameraSource)
        Image image = reader.acquireLatestImage();
        if (image != null) {
            ByteBuffer yuvData = imageToByteBuffer(image);
            processingRunnable.setNextFrame(yuvData, image);
            image.close();
        }
    }
    
    /**
     * Converts Camera2 Image to ByteBuffer for processing (YUV_420_888 to NV21)
     */
    private ByteBuffer imageToByteBuffer(Image image) {
        // YUV_420_888 format - convert to NV21
        return convertYuv420ToNv21(image);
    }
    
    /**
     * Converts YUV_420_888 to NV21 format
     */
    private ByteBuffer convertYuv420ToNv21(Image image) {
        Image.Plane[] planes = image.getPlanes();
        ByteBuffer yBuffer = planes[0].getBuffer();
        ByteBuffer uBuffer = planes[1].getBuffer();
        ByteBuffer vBuffer = planes[2].getBuffer();
        
        int width = image.getWidth();
        int height = image.getHeight();
        
        // Get strides
        int yRowStride = planes[0].getRowStride();
        int uRowStride = planes[1].getRowStride();
        int vRowStride = planes[2].getRowStride();
        int yPixelStride = planes[0].getPixelStride();
        int uPixelStride = planes[1].getPixelStride();
        int vPixelStride = planes[2].getPixelStride();
        
        // Calculate NV21 data size
        int ySize = width * height;
        int uvSize = ySize / 2;
        byte[] nv21 = new byte[ySize + uvSize];
        
        // Copy Y plane
        copyPlaneToNV21(yBuffer, nv21, 0, ySize, width, height, yRowStride, yPixelStride);
        
        // Get U and V data
        byte[] uData = new byte[uBuffer.remaining()];
        byte[] vData = new byte[vBuffer.remaining()];
        uBuffer.get(uData);
        vBuffer.get(vData);
        
        // Interleave U and V data as VU (NV21 format)
        int uvIndex = ySize;
        int uvWidth = width / 2;
        int uvHeight = height / 2;
        
        for (int row = 0; row < uvHeight; row++) {
            for (int col = 0; col < uvWidth; col++) {
                int uIndex = row * uRowStride + col * uPixelStride;
                int vIndex = row * vRowStride + col * vPixelStride;
                
                nv21[uvIndex++] = vData[vIndex];
                nv21[uvIndex++] = uData[uIndex];
            }
        }
        
        return ByteBuffer.wrap(nv21);
    }
    
    /**
     * Copies plane data to NV21 array with proper stride handling
     */
    private void copyPlaneToNV21(ByteBuffer planeBuffer, byte[] nv21, int offset, int size,
                                 int width, int height, int rowStride, int pixelStride) {
        if (rowStride == width && pixelStride == 1) {
            // Direct copy if no padding
            planeBuffer.get(nv21, offset, size);
        } else {
            // Handle row stride and pixel stride
            int destIndex = offset;
            for (int row = 0; row < height; row++) {
                int srcIndex = row * rowStride;
                for (int col = 0; col < width; col++) {
                    nv21[destIndex++] = planeBuffer.get(srcIndex);
                    srcIndex += pixelStride;
                }
            }
        }
    }
    
    
    /**
     * Gets camera ID for the specified facing direction
     */
    private String getCameraId(int facing) {
        try {
            String[] cameraIds = cameraManager.getCameraIdList();
            for (String id : cameraIds) {
                CameraCharacteristics characteristics = cameraManager.getCameraCharacteristics(id);
                Integer lensFacing = characteristics.get(CameraCharacteristics.LENS_FACING);
                if (lensFacing != null && lensFacing == facing) {
                    return id;
                }
            }
        } catch (CameraAccessException e) {
            Log.e(TAG, "Failed to get camera list", e);
        }
        return null;
    }
    
    /**
     * Chooses optimal size from available sizes
     */
    private Size chooseOptimalSize(Size[] choices, int width, int height) {
        List<Size> bigEnough = new ArrayList<>();
        List<Size> notBigEnough = new ArrayList<>();
        
        int w = height;
        int h = width;
        
        for (Size option : choices) {
            if (option.getWidth() <= MAX_PREVIEW_WIDTH && option.getHeight() <= MAX_PREVIEW_HEIGHT &&
                option.getHeight() == option.getWidth() * h / w) {
                if (option.getWidth() >= w && option.getHeight() >= h) {
                    bigEnough.add(option);
                } else {
                    notBigEnough.add(option);
                }
            }
        }
        
        if (bigEnough.size() > 0) {
            return Collections.min(bigEnough, new CompareSizesByArea());
        } else if (notBigEnough.size() > 0) {
            return Collections.max(notBigEnough, new CompareSizesByArea());
        } else {
            return choices[0];
        }
    }
    
    /**
     * Compares two sizes by area
     */
    private static class CompareSizesByArea implements Comparator<Size> {
        @Override
        public int compare(Size lhs, Size rhs) {
            return Long.signum((long) lhs.getWidth() * lhs.getHeight() - (long) rhs.getWidth() * rhs.getHeight());
        }
    }
    
    /**
     * Calculates rotation based on device orientation
     */
    private void calculateRotation() {
        if (activity == null) return;
        
        WindowManager windowManager = (WindowManager) activity.getSystemService(Context.WINDOW_SERVICE);
        int degrees = 0;
        int rotation = windowManager.getDefaultDisplay().getRotation();
        switch (rotation) {
            case android.view.Surface.ROTATION_0:
                degrees = 0;
                break;
            case android.view.Surface.ROTATION_90:
                degrees = 90;
                break;
            case android.view.Surface.ROTATION_180:
                degrees = 180;
                break;
            case android.view.Surface.ROTATION_270:
                degrees = 270;
                break;
        }
        
        try {
            CameraCharacteristics characteristics = cameraManager.getCameraCharacteristics(cameraId);
            Integer sensorOrientation = characteristics.get(CameraCharacteristics.SENSOR_ORIENTATION);
            if (sensorOrientation != null) {
                if (facing == CAMERA_FACING_FRONT) {
                    rotationDegrees = (sensorOrientation + degrees) % 360;
                } else {
                    rotationDegrees = (sensorOrientation - degrees + 360) % 360;
                }
            }
        } catch (CameraAccessException e) {
            Log.e(TAG, "Failed to get camera characteristics", e);
            rotationDegrees = 0;
        }
    }
    
    /**
     * Updates requested resolution based on current mode
     */
    private void updateRequestedResolution() {
        switch (resolutionMode) {
            case RESOLUTION_LOW:
                requestedWidth = 480;
                requestedHeight = 848;
                break;
            case RESOLUTION_MEDIUM:
                requestedWidth = 720;
                requestedHeight = 1280;
                break;
            case RESOLUTION_HIGH:
                requestedWidth = 720;
                requestedHeight = 1280;
                break;
            case RESOLUTION_AUTO:
                autoSelectResolution();
                break;
            default:
                // Custom resolution - keep current values
                break;
        }
        Log.d(TAG, "Resolution updated: " + requestedWidth + "x" + requestedHeight + " (mode: " + resolutionMode + ")");
    }
    
    /**
     * Automatically selects the best resolution based on device capabilities
     */
    private void autoSelectResolution() {
        try {
            if (activity == null) {
                return;
            }
            
            // Get screen dimensions
            Point screenSize = new Point();
            activity.getWindowManager().getDefaultDisplay().getSize(screenSize);
            int screenWidth = Math.min(screenSize.x, screenSize.y);
            int screenHeight = Math.max(screenSize.x, screenSize.y);
            
            // Get device performance indicators
            long totalMemory = Runtime.getRuntime().maxMemory();
            int cpuCores = Runtime.getRuntime().availableProcessors();
            
            // Auto-select based on device capabilities
            if (isHighEndDevice(totalMemory, cpuCores, screenWidth, screenHeight)) {
                requestedWidth = 720;
                requestedHeight = 1280;
                Log.d(TAG, "Auto-selected HIGH resolution for high-end device");
            }
            // else if (isMidRangeDevice(totalMemory, cpuCores, screenWidth, screenHeight)) {
            //     requestedWidth = 720;
            //     requestedHeight = 1280;
            //     Log.d(TAG, "Auto-selected MEDIUM resolution for mid-range device");
            // } 
            else {
                requestedWidth = 720;
                requestedHeight = 1280;
                Log.d(TAG, "Auto-selected LOW resolution for low-end device");
            }
            
            // Adjust for screen size if needed
            adjustForScreenSize(screenWidth, screenHeight);
            
        } catch (Exception e) {
            Log.w(TAG, "Failed to auto-select resolution, using default", e);
            requestedWidth = DEFAULT_REQUESTED_CAMERA_PREVIEW_WIDTH;
            requestedHeight = DEFAULT_REQUESTED_CAMERA_PREVIEW_HEIGHT;
        }
    }
    
    /**
     * Determines if the device is high-end based on hardware specs
     */
    private boolean isHighEndDevice(long totalMemory, int cpuCores, int screenWidth, int screenHeight) {
        return totalMemory > (3L * 1024 * 1024 * 1024) &&  // > 3GB RAM
               cpuCores >= 8 &&                             // >= 8 CPU cores
               screenWidth >= 1080;                         // >= 1080p screen
    }
    
    /**
     * Determines if the device is mid-range based on hardware specs
     */
    private boolean isMidRangeDevice(long totalMemory, int cpuCores, int screenWidth, int screenHeight) {
        return totalMemory > (1536L * 1024 * 1024) &&      // > 1.5GB RAM
               cpuCores >= 4 &&                             // >= 4 CPU cores
               screenWidth >= 720;                          // >= 720p screen
    }
    
    /**
     * Adjusts resolution based on screen size to avoid unnecessary upscaling
     */
    private void adjustForScreenSize(int screenWidth, int screenHeight) {
        if (requestedWidth > screenWidth) {
            float ratio = (float) screenWidth / requestedWidth;
            requestedWidth = screenWidth;
            requestedHeight = (int) (requestedHeight * ratio);
            Log.d(TAG, "Adjusted resolution for screen size: " + requestedWidth + "x" + requestedHeight);
        }
    }
    
    private void cleanScreen() {
        // No-op for Camera2Source
    }
    
    /**
     * This runnable controls access to the underlying receiver, calling it to process frames when
     * available from the camera. This is designed to run detection on frames as fast as possible
     * (i.e., without unnecessary context switching or waiting on the next frame).
     *
     * <p>This implementation uses a new Thread for detection, so that detection can run continuously
     * regardless of whether or not the main thread is blocked in other operations. This does create
     * some additional computational overhead, so for applications that do not need very frequent
     * updates, this may be overkill.
     *
     * <p>Note that while this approach ensures that the camera will not be blocked, it does not
     * guarantee that frames will be analyzed. For example, if detection is consistently taking
     * longer than the time between frames, then some frames will be dropped. It is important to
     * design your processing pipeline in a way that can handle this scenario.
     *
     * <p>Will call the underlying receiver's {@code receiveFrame} method as fast as possible
     * while frames are being received from the camera.
     */
    private class FrameProcessingRunnable implements Runnable {

        // This lock guards all of the member variables below.
        private final Object lock = new Object();
        private boolean active = true;

        // These pending variables hold the state associated with the most recently received set
        // of pending data to process. These variables are guarded by the lock above.
        private ByteBuffer pendingFrameData;
        private Image pendingImage;

        FrameProcessingRunnable() {}

        // Marks the runnable as active/not active. Signals any blocked threads to continue.
        void setActive(boolean active) {
            synchronized (lock) {
                this.active = active;
                lock.notifyAll();
            }
        }

        /**
         * Releases the camera hold if this runnable is set with a null image.
         *
         * <p>This is a hack to prevent a crash that was occurring on some devices when the Camera
         * preview was rapidly stopped and restarted.
         */
        void setNextFrame(ByteBuffer data, Image image) {
            synchronized (lock) {
                if (pendingFrameData != null) {
                    // Skip this frame
                    return;
                }
                pendingFrameData = data;
                pendingImage = image;
                lock.notifyAll();
            }
        }

        @Override
        public void run() {
            ByteBuffer data;

            while (true) {
                synchronized (lock) {
                    while (active && (pendingFrameData == null)) {
                        try {
                            // Wait for the next frame to be received from the camera, since we
                            // don't have it yet.
                            lock.wait();
                        } catch (InterruptedException e) {
                            Log.d(TAG, "Frame processing interrupted.");
                            return;
                        }
                    }

                    if (!active) {
                        // Exit the loop once this camera source is stopped or released.  We check
                        // this here, immediately after the wait() above, to handle the case where
                        // setActive(false) had been called, causing the termination of this
                        // loop.
                        return;
                    }

                    data = pendingFrameData;
                    pendingFrameData = null;
                }

                try {
                    synchronized (processorLock) {
                        if (frameProcessor != null) {
                            frameProcessor.processByteBuffer(
                                    data,
                                    new FrameMetadata.Builder()
                                            .setWidth(previewSize.getWidth())
                                            .setHeight(previewSize.getHeight())
                                            .setRotation(rotationDegrees)
                                            .build());
                        }
                    }
                } catch (Exception t) {
                    Log.e(TAG, "Exception thrown from receiver.", t);
                } finally {
                    isProcessingFrame = false;
                }
            }
        }
    }
}
