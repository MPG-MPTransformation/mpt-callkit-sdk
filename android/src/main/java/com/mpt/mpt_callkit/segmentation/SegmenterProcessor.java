/*
 * Copyright 2020 Google LLC. All rights reserved.
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

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.Bitmap.Config;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Matrix;
import android.graphics.Paint;
import android.graphics.PorterDuff;
import android.graphics.PorterDuffXfermode;
import android.graphics.Rect;
import android.graphics.Typeface;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.google.android.gms.tasks.Task;
import com.google.android.gms.tasks.Tasks;
import com.google.mlkit.vision.common.InputImage;
import com.google.mlkit.vision.segmentation.Segmentation;
import com.google.mlkit.vision.segmentation.SegmentationMask;
import com.google.mlkit.vision.segmentation.Segmenter;
import com.google.mlkit.vision.segmentation.selfie.SelfieSegmenterOptions;

import java.nio.ByteBuffer;

/**
 * A processor to run ML Kit's Selfie Segmentation for background blur effects.
 * This class handles image segmentation, text overlay, and bitmap transformations.
 */
public class SegmenterProcessor extends VisionProcessorBase<SegmentationMask> {

    private static final String TAG = "SegmenterProcessor";
    
    // Constants for background masking
    private static final float BACKGROUND_THRESHOLD_HIGH = 0.9f;
    private static final float BACKGROUND_THRESHOLD_LOW = 0.5f;
    private static final int BACKGROUND_ALPHA = 230;
    private static final int BACKGROUND_RGB = 211; // Light gray color
    
    // Constants for text overlay
    private static final float TEXT_SIZE_RATIO = 0.05f; // 5% of screen width
    private static final float TEXT_MARGIN_RATIO = 0.04f; // 4% of screen height
    private static final float ALPHA_INTERPOLATION_SLOPE = 328.57f;
    private static final float ALPHA_INTERPOLATION_OFFSET = -65.71f;

    private Segmenter segmenter;
    private final VisionImageProcessorCallback callback;
    private final boolean isStreamMode;
    
    // Overlay and background settings
    private String text;
    private boolean enableBlurBackground;
    private String bgPath;
    private Bitmap bgBitmap;
    
    // Background image loading
    private final ExecutorService imageLoadExecutor;
    private final Handler mainHandler;
    private Future<?> imageLoadTask;

    /**
     * Creates a SegmenterProcessor with default stream mode enabled.
     *
     * @param context The Android context
     * @param callback Callback for processing results
     * @param text Text to overlay on the image
     * @param enableBlurBackground Whether to enable background blur
     */
    public SegmenterProcessor(@NonNull Context context, 
                            @NonNull VisionImageProcessorCallback callback, 
                            @Nullable String text, 
                            boolean enableBlurBackground) {
        this(context, true, callback, text, enableBlurBackground, null);
    }

    /**
     * Creates a SegmenterProcessor with default stream mode enabled.
     *
     * @param context The Android context
     * @param callback Callback for processing results
     * @param text Text to overlay on the image
     * @param enableBlurBackground Whether to enable background blur
     * @param bgPath Path to background image file
     */
    public SegmenterProcessor(@NonNull Context context, 
                            @NonNull VisionImageProcessorCallback callback, 
                            @Nullable String text, 
                            boolean enableBlurBackground,
                            @Nullable String bgPath) {
        this(context, true, callback, text, enableBlurBackground, bgPath);
    }

    /**
     * Creates a SegmenterProcessor with configurable stream mode.
     *
     * @param context The Android context
     * @param isStreamMode Whether to use stream mode for processing
     * @param callback Callback for processing results
     * @param text Text to overlay on the image
     * @param enableBlurBackground Whether to enable background blur
     * @param bgPath Path to background image file
     */
    public SegmenterProcessor(@NonNull Context context, 
                            boolean isStreamMode,
                            @NonNull VisionImageProcessorCallback callback, 
                            @Nullable String text, 
                            boolean enableBlurBackground,
                            @Nullable String bgPath) {
        super(context);
        this.callback = callback;
        this.text = text;
        this.enableBlurBackground = enableBlurBackground;
        this.isStreamMode = isStreamMode;
        this.bgPath = bgPath;
        this.bgBitmap = null;
        
        // Initialize background image loading infrastructure
        this.imageLoadExecutor = Executors.newSingleThreadExecutor();
        this.mainHandler = new Handler(Looper.getMainLooper());
        
        if (bgPath != null) {
            loadBackgroundImage();
        }
    }

    /**
     * Creates and initializes the ML Kit segmenter with appropriate options.
     */
    private void createSegmenter() {
        SelfieSegmenterOptions.Builder optionsBuilder = new SelfieSegmenterOptions.Builder();
        optionsBuilder.setDetectorMode(
                isStreamMode ? SelfieSegmenterOptions.STREAM_MODE : SelfieSegmenterOptions.SINGLE_IMAGE_MODE);
        SelfieSegmenterOptions options = optionsBuilder.build();
        segmenter = Segmentation.getClient(options);
        Log.d(TAG, "SegmenterProcessor created - text: " + text + ", enableBlurBackground: " + enableBlurBackground);
    }

    @Override
    protected Task<SegmentationMask> detectInImage(InputImage image) {
        if (!enableBlurBackground) {
            return Tasks.forResult(null);
        }
        if (segmenter == null) {
            createSegmenter();
        }
        if (bgPath != null && bgBitmap == null) {
            loadBackgroundImage();
        }
        return segmenter.process(image);
    }

    @Override
    protected void onSuccess(@Nullable SegmentationMask segmentationMask, 
                           @NonNull Bitmap originalCameraImage, 
                           long frameStartMs) {
        try {
            Bitmap processedImage = segmentationMask == null 
                    ? createImageWithTextOverlay(originalCameraImage)
                    : applySegmentationMask(segmentationMask, originalCameraImage);
            
            callback.onDetectionSuccess(processedImage, frameStartMs);
        } catch (Exception e) {
            Log.e(TAG, "Error processing segmentation result", e);
            callback.onDetectionFailure(e);
        }
    }

    @Override
    protected void onFailure(@NonNull Exception e) {
        Log.e(TAG, "Segmentation detection failed", e);
        callback.onDetectionFailure(e);
    }

    /**
     * Gets the current overlay text.
     *
     * @return The current text string, may be null
     */
    @Nullable
    public String getText() {
        return text;
    }

    /**
     * Sets the text to overlay on processed images.
     *
     * @param text The text to display, may be null
     */
    public void setText(@Nullable String text) {
        Log.d(TAG, "Setting overlay text: " + text);
        this.text = text;
    }

    /**
     * Enables or disables background blur processing.
     *
     * @param enableBlurBackground True to enable background blur, false otherwise
     */
    public void setEnableBlurBackground(boolean enableBlurBackground) {
        Log.d(TAG, "Setting background blur enabled: " + enableBlurBackground);
        this.enableBlurBackground = enableBlurBackground;
    }

    /**
     * Sets the background image path and loads the image.
     *
     * @param bgPath Path to the background image file or URL
     */
    public void setBgPath(@Nullable String bgPath) {
        Log.d(TAG, "Setting background path: " + bgPath);
        this.bgPath = bgPath;
        if (bgPath != null) {
            loadBackgroundImage();
        } else {
            // Clear background if path is null
            safeRecycleBitmap(bgBitmap);
            bgBitmap = null;
        }
    }

    /**
     * Validates if the given string is a valid URL.
     *
     * @param urlString The string to validate
     * @return True if it's a valid URL, false otherwise
     */
    private boolean isValidUrl(String urlString) {
        try {
            new URL(urlString);
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    /**
     * Loads the background image from the specified path into bgBitmap.
     * Supports both local file paths and internet URLs.
     */
    private void loadBackgroundImage() {
        if (bgPath == null || bgPath.trim().isEmpty()) {
            Log.d(TAG, "No background path specified, clearing bgBitmap");
            safeRecycleBitmap(bgBitmap);
            bgBitmap = null;
            return;
        }

        // Cancel any existing image loading task
        cancelImageLoadTask();

        // Check if it's a valid URL
        if (isValidUrl(bgPath)) {
            loadBackgroundImageFromUrl(bgPath);
        } else {
            loadBackgroundImageFromFile(bgPath);
        }
    }

    /**
     * Loads background image from a local file path.
     *
     * @param filePath Local file path
     */
    private void loadBackgroundImageFromFile(@NonNull String filePath) {
        try {
            // Recycle existing bitmap if any
            safeRecycleBitmap(bgBitmap);
            
            // Load the background image from local file
            bgBitmap = BitmapFactory.decodeFile(filePath);
            if (bgBitmap == null) {
                Log.e(TAG, "Failed to load background image from path: " + filePath);
            } else {
                Log.d(TAG, "Successfully loaded background image: " + filePath + 
                      " (size: " + bgBitmap.getWidth() + "x" + bgBitmap.getHeight() + ")");
            }
        } catch (Exception e) {
            Log.e(TAG, "Error loading background image from path: " + filePath, e);
            safeRecycleBitmap(bgBitmap);
            bgBitmap = null;
        }
    }

    /**
     * Loads background image from a URL in background thread.
     *
     * @param urlString URL to load from
     */
    private void loadBackgroundImageFromUrl(@NonNull String urlString) {
        Log.d(TAG, "Loading background image from URL: " + urlString);
        
        imageLoadTask = imageLoadExecutor.submit(() -> {
            Bitmap loadedBitmap = downloadImageFromUrl(urlString);
            
            // Update UI on main thread
            mainHandler.post(() -> {
                // Recycle existing bitmap if any
                safeRecycleBitmap(bgBitmap);
                
                if (loadedBitmap != null) {
                    bgBitmap = loadedBitmap;
                    Log.d(TAG, "Successfully loaded background image from URL: " + urlString + 
                          " (size: " + bgBitmap.getWidth() + "x" + bgBitmap.getHeight() + ")");
                } else {
                    Log.e(TAG, "Failed to load background image from URL: " + urlString);
                    bgBitmap = null;
                }
            });
        });
    }

    /**
     * Downloads an image from a URL (runs on background thread).
     *
     * @param urlString URL to download from
     * @return Downloaded bitmap or null if failed
     */
    @Nullable
    private Bitmap downloadImageFromUrl(@NonNull String urlString) {
        HttpURLConnection connection = null;
        InputStream inputStream = null;
        
        try {
            URL url = new URL(urlString);
            connection = (HttpURLConnection) url.openConnection();
            connection.setDoInput(true);
            connection.setConnectTimeout(10000); // 10 seconds timeout
            connection.setReadTimeout(10000); // 10 seconds timeout
            connection.connect();
            
            int responseCode = connection.getResponseCode();
            if (responseCode == HttpURLConnection.HTTP_OK) {
                inputStream = connection.getInputStream();
                return BitmapFactory.decodeStream(inputStream);
            } else {
                Log.e(TAG, "HTTP error loading image: " + responseCode);
                return null;
            }
        } catch (Exception e) {
            Log.e(TAG, "Error downloading image from URL: " + urlString, e);
            return null;
        } finally {
            try {
                if (inputStream != null) {
                    inputStream.close();
                }
                if (connection != null) {
                    connection.disconnect();
                }
            } catch (Exception e) {
                Log.e(TAG, "Error closing connection", e);
            }
        }
    }

    /**
     * Cancels any ongoing image loading task.
     */
    private void cancelImageLoadTask() {
        if (imageLoadTask != null && !imageLoadTask.isDone()) {
            imageLoadTask.cancel(true);
            imageLoadTask = null;
        }
    }

    @Override
    public void stop() {
        Log.d(TAG, "Stopping SegmenterProcessor and releasing resources");
        
        // Cancel any running image loading task
        cancelImageLoadTask();
        
        // Shutdown image loading executor
        if (imageLoadExecutor != null && !imageLoadExecutor.isShutdown()) {
            imageLoadExecutor.shutdown();
        }
        
        // Close the ML Kit Segmenter to release its resources and stop background threads
        if (segmenter != null) {
            segmenter.close();
            segmenter = null;
        }
        
        // Recycle background bitmap
        safeRecycleBitmap(bgBitmap);
        bgBitmap = null;
        
        // Call parent stop method to handle executor shutdown and other cleanup
        super.stop();
    }

    /**
     * Applies segmentation mask to the original image with background image effect.
     *
     * @param segmentationMask The ML Kit segmentation mask
     * @param originalCameraImage The original camera image
     * @return Processed bitmap with background image and text overlay
     */
    private Bitmap applySegmentationMask(@NonNull SegmentationMask segmentationMask, 
                                       @NonNull Bitmap originalCameraImage) {
        int originalWidth = originalCameraImage.getWidth();
        int originalHeight = originalCameraImage.getHeight();
        
        // Prepare mask and camera image
        Bitmap maskBitmap = prepareScaledMask(segmentationMask, originalWidth, originalHeight);
        Bitmap flippedCameraImage = flipBitmapHorizontally(originalCameraImage);
        
        // Create result based on background availability
        Bitmap resultBitmap = (bgBitmap != null) 
            ? compositePersonOnBackground(flippedCameraImage, maskBitmap, originalWidth, originalHeight)
            : applyMaskToCamera(flippedCameraImage, maskBitmap);
        
        // Add text overlay if needed
        if (this.text != null && !this.text.trim().isEmpty()) {
            Canvas canvas = new Canvas(resultBitmap);
            drawTextOverlay(canvas, resultBitmap.getWidth(), resultBitmap.getHeight());
        }
        
        // Clean up resources
        safeRecycleBitmap(maskBitmap);
        safeRecycleBitmap(flippedCameraImage);
        
        return resultBitmap;
    }

    /**
     * Prepares and scales the segmentation mask to match camera dimensions.
     *
     * @param segmentationMask The ML Kit segmentation mask
     * @param targetWidth Target width
     * @param targetHeight Target height
     * @return Scaled and flipped mask bitmap
     */
    private Bitmap prepareScaledMask(@NonNull SegmentationMask segmentationMask, 
                                     int targetWidth, int targetHeight) {
        ByteBuffer mask = segmentationMask.getBuffer();
        int maskWidth = segmentationMask.getWidth();
        int maskHeight = segmentationMask.getHeight();
        
        // Create mask bitmap
        Bitmap maskBitmap = createMaskBitmap(mask, maskWidth, maskHeight);
        
        // Scale if dimensions don't match
        if (maskWidth != targetWidth || maskHeight != targetHeight) {
            Bitmap scaledMask = Bitmap.createScaledBitmap(maskBitmap, targetWidth, targetHeight, true);
            safeRecycleBitmap(maskBitmap);
            maskBitmap = scaledMask;
        }
        
        // Flip mask to match camera orientation
        Bitmap flippedMask = flipBitmapHorizontally(maskBitmap);
        safeRecycleBitmap(maskBitmap);
        
        return flippedMask;
    }

    /**
     * Composites person from camera image onto background image using mask.
     *
     * @param flippedCameraImage Camera image (already flipped)
     * @param maskBitmap Mask bitmap (person = white, background = transparent)
     * @param width Image width
     * @param height Image height
     * @return Composited result bitmap
     */
    private Bitmap compositePersonOnBackground(@NonNull Bitmap flippedCameraImage, 
                                               @NonNull Bitmap maskBitmap,
                                               int width, int height) {
        // Scale background to match camera dimensions (DO NOT flip)
        Bitmap scaledBackground = Bitmap.createScaledBitmap(bgBitmap, width, height, true);
        Bitmap resultBitmap = scaledBackground.copy(scaledBackground.getConfig(), true);
        safeRecycleBitmap(scaledBackground);
        
        // Create masked person bitmap
        Bitmap maskedPerson = createMaskedPerson(flippedCameraImage, maskBitmap, width, height);
        
        // Draw masked person onto background
        Canvas canvas = new Canvas(resultBitmap);
        Paint paint = new Paint();
        paint.setAntiAlias(true);
        canvas.drawBitmap(maskedPerson, 0, 0, paint);
        
        safeRecycleBitmap(maskedPerson);
        
        return resultBitmap;
    }

    /**
     * Creates a bitmap containing only the person (masked from camera image).
     *
     * @param cameraImage Camera image
     * @param maskBitmap Mask bitmap
     * @param width Image width
     * @param height Image height
     * @return Masked person bitmap
     */
    private Bitmap createMaskedPerson(@NonNull Bitmap cameraImage, 
                                      @NonNull Bitmap maskBitmap,
                                      int width, int height) {
        Bitmap maskedPerson = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888);
        Canvas canvas = new Canvas(maskedPerson);
        
        Paint paint = new Paint();
        paint.setAntiAlias(true);
        canvas.drawBitmap(cameraImage, 0, 0, paint);
        
        // Apply mask using DST_IN mode (keep only where mask is opaque)
        Paint maskPaint = new Paint();
        maskPaint.setAntiAlias(true);
        maskPaint.setXfermode(new PorterDuffXfermode(PorterDuff.Mode.DST_IN));
        canvas.drawBitmap(maskBitmap, 0, 0, maskPaint);
        
        return maskedPerson;
    }

    /**
     * Applies mask to camera image with light gray background (used when no background image is available).
     * Returns the masked person composited onto a light gray background.
     *
     * @param cameraImage Camera image
     * @param maskBitmap Mask bitmap
     * @return Masked camera image on light gray background
     */
    private Bitmap applyMaskToCamera(@NonNull Bitmap cameraImage, @NonNull Bitmap maskBitmap) {
        int width = cameraImage.getWidth();
        int height = cameraImage.getHeight();
        
        // Create light gray background (matching constant BACKGROUND_RGB = 211)
        Bitmap resultBitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888);
        Canvas canvas = new Canvas(resultBitmap);
        
        // Fill with light gray color
        Paint bgPaint = new Paint();
        bgPaint.setColor(Color.rgb(BACKGROUND_RGB, BACKGROUND_RGB, BACKGROUND_RGB));
        canvas.drawRect(0, 0, width, height, bgPaint);
        
        // Create masked person bitmap
        Bitmap maskedPerson = createMaskedPerson(cameraImage, maskBitmap, width, height);
        
        // Draw masked person onto gray background
        Paint paint = new Paint();
        paint.setAntiAlias(true);
        canvas.drawBitmap(maskedPerson, 0, 0, paint);
        
        safeRecycleBitmap(maskedPerson);
        
        return resultBitmap;
    }

    /**
     * Creates an image with text overlay only (no segmentation).
     *
     * @param originalCameraImage The original camera image
     * @return Bitmap with text overlay and horizontal flip applied
     */
    private Bitmap createImageWithTextOverlay(@NonNull Bitmap originalCameraImage) {
        // Create a mutable copy of the original camera image
        Bitmap resultBitmap = flipBitmapHorizontally(originalCameraImage.copy(originalCameraImage.getConfig(), true));
        if (this.text != null && !this.text.trim().isEmpty()) {
            // Draw text overlay
            Canvas canvas = new Canvas(resultBitmap);
            drawTextOverlay(canvas, resultBitmap.getWidth(), resultBitmap.getHeight());
        }
        return resultBitmap;
    }

    /**
     * Flips a bitmap horizontally (mirror effect).
     *
     * @param bitmap The bitmap to flip
     * @return A new horizontally flipped bitmap
     */
    private Bitmap flipBitmapHorizontally(@NonNull Bitmap bitmap) {
        Matrix matrix = new Matrix();
        matrix.preScale(-1.0f, 1.0f);
        return Bitmap.createBitmap(bitmap, 0, 0, bitmap.getWidth(), bitmap.getHeight(), matrix, false);
    }

    /**
     * Draws text overlay on the canvas at the top center position.
     *
     * @param canvas The canvas to draw on
     * @param bitmapWidth Width of the bitmap
     * @param bitmapHeight Height of the bitmap
     */
    private void drawTextOverlay(@NonNull Canvas canvas, int bitmapWidth, int bitmapHeight) {
        Paint textPaint = createTextPaint(bitmapWidth);
        // Calculate text position (top center)
        Rect textBounds = new Rect();
        textPaint.getTextBounds(text, 0, text.length(), textBounds);
        float x = bitmapWidth / 2f; // Center horizontally
        float y = textBounds.height() + bitmapHeight * TEXT_MARGIN_RATIO; // Top with margin
        
        canvas.drawText(text, x, y, textPaint);
    }

    /**
     * Creates a configured Paint object for text rendering.
     *
     * @param bitmapWidth Width of the bitmap for responsive text sizing
     * @return Configured Paint object
     */
    private Paint createTextPaint(int bitmapWidth) {
        Paint textPaint = new Paint();
        textPaint.setColor(Color.BLACK);
        textPaint.setTextSize(bitmapWidth * TEXT_SIZE_RATIO);
        textPaint.setTypeface(Typeface.DEFAULT_BOLD);
        textPaint.setAntiAlias(true);
        textPaint.setTextAlign(Paint.Align.CENTER);
        return textPaint;
    }

    /**
     * Creates a mask bitmap from the segmentation buffer.
     *
     * @param mask The segmentation mask buffer
     * @param maskWidth Width of the mask
     * @param maskHeight Height of the mask
     * @return Bitmap representation of the mask
     */
    private Bitmap createMaskBitmap(@NonNull ByteBuffer mask, int maskWidth, int maskHeight) {
        int[] colors = maskColorsFromByteBuffer(mask, maskWidth, maskHeight);
        return Bitmap.createBitmap(colors, maskWidth, maskHeight, Config.ARGB_8888);
    }

    /**
     * Converts segmentation mask buffer to color array for bitmap creation.
     * Creates a mask where person areas are opaque (white) and background areas are transparent.
     *
     * @param byteBuffer The segmentation mask buffer
     * @param maskWidth Width of the mask
     * @param maskHeight Height of the mask
     * @return Array of ARGB color values
     */
    private int[] maskColorsFromByteBuffer(@NonNull ByteBuffer byteBuffer, int maskWidth, int maskHeight) {
        int[] colors = new int[maskWidth * maskHeight];
        for (int i = 0; i < maskWidth * maskHeight; i++) {
            float backgroundLikelihood = 1 - byteBuffer.getFloat();
            
            if (backgroundLikelihood > BACKGROUND_THRESHOLD_HIGH) {
                // Background area: transparent (will show background image)
                colors[i] = Color.TRANSPARENT;
            } else if (backgroundLikelihood > BACKGROUND_THRESHOLD_LOW) {
                // Transition area: interpolate between transparent and opaque
                int alpha = calculateInterpolatedAlpha(backgroundLikelihood);
                colors[i] = Color.argb(255 - alpha, 255, 255, 255); // Invert alpha for person mask
            } else {
                // Person area: opaque white (will show camera image)
                colors[i] = Color.WHITE;
            }
        }
        return colors;
    }

    /**
     * Calculates interpolated alpha value for transition areas in the mask.
     *
     * @param backgroundLikelihood The background likelihood value
     * @return Interpolated alpha value
     */
    private int calculateInterpolatedAlpha(float backgroundLikelihood) {
        return (int) (ALPHA_INTERPOLATION_SLOPE * backgroundLikelihood + ALPHA_INTERPOLATION_OFFSET + 0.5);
    }

    /**
     * Safely recycles a bitmap if it's not null and not already recycled.
     *
     * @param bitmap The bitmap to recycle
     */
    private void safeRecycleBitmap(@Nullable Bitmap bitmap) {
        if (bitmap != null && !bitmap.isRecycled()) {
            bitmap.recycle();
        }
    }
}
