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
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Matrix;
import android.graphics.Paint;
import android.graphics.Rect;
import android.graphics.Typeface;
import android.util.Log;

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
    private static final float BACKGROUND_THRESHOLD_LOW = 0.2f;
    private static final int BACKGROUND_ALPHA = 230;
    private static final int BACKGROUND_RGB = 211; // Light gray color
    
    // Constants for text overlay
    private static final float TEXT_SIZE_RATIO = 0.05f; // 5% of screen width
    private static final float TEXT_MARGIN_RATIO = 0.04f; // 4% of screen height
    private static final float ALPHA_INTERPOLATION_SLOPE = 328.57f;
    private static final float ALPHA_INTERPOLATION_OFFSET = -65.71f;

    private Segmenter segmenter;
    private final VisionImageProcessorCallback callback;
    private String text;
    private boolean enableBlurBackground;
    private final boolean isStreamMode;

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
        this(context, true, callback, text, enableBlurBackground);
    }

    /**
     * Creates a SegmenterProcessor with configurable stream mode.
     *
     * @param context The Android context
     * @param isStreamMode Whether to use stream mode for processing
     * @param callback Callback for processing results
     * @param text Text to overlay on the image
     * @param enableBlurBackground Whether to enable background blur
     */
    public SegmenterProcessor(@NonNull Context context, 
                            boolean isStreamMode,
                            @NonNull VisionImageProcessorCallback callback, 
                            @Nullable String text, 
                            boolean enableBlurBackground) {
        super(context);
        this.callback = callback;
        this.text = text;
        this.enableBlurBackground = enableBlurBackground;
        this.isStreamMode = isStreamMode;
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

    @Override
    public void stop() {
        Log.d(TAG, "Stopping SegmenterProcessor and releasing resources");
        
        // Close the ML Kit Segmenter to release its resources and stop background threads
        if (segmenter != null) {
            segmenter.close();
            segmenter = null;
        }
        
        // Call parent stop method to handle executor shutdown and other cleanup
        super.stop();
    }

    /**
     * Applies segmentation mask to the original image with background blur effect.
     *
     * @param segmentationMask The ML Kit segmentation mask
     * @param originalCameraImage The original camera image
     * @return Processed bitmap with background blur and text overlay
     */
    private Bitmap applySegmentationMask(@NonNull SegmentationMask segmentationMask, 
                                       @NonNull Bitmap originalCameraImage) {
        ByteBuffer mask = segmentationMask.getBuffer();
        int maskWidth = segmentationMask.getWidth();
        int maskHeight = segmentationMask.getHeight();
        int originalWidth = originalCameraImage.getWidth();
        int originalHeight = originalCameraImage.getHeight();
        
        // Create a mutable copy of the original camera image
        Bitmap resultBitmap = originalCameraImage.copy(originalCameraImage.getConfig(), true);
        
        // Create and scale the mask bitmap
        Bitmap maskBitmap = createMaskBitmap(mask, maskWidth, maskHeight);
        if (maskWidth != originalWidth || maskHeight != originalHeight) {
            Bitmap scaledMask = Bitmap.createScaledBitmap(maskBitmap, originalWidth, originalHeight, true);
            maskBitmap.recycle();
            maskBitmap = scaledMask;
        }

        // Apply horizontal flip to both images
        resultBitmap = flipBitmapHorizontally(resultBitmap);
        maskBitmap = flipBitmapHorizontally(maskBitmap);
        
        // Apply the mask and text overlay
        Canvas canvas = new Canvas(resultBitmap);
        Paint paint = new Paint();
        paint.setAntiAlias(true);
        canvas.drawBitmap(maskBitmap, 0, 0, paint);
        drawTextOverlay(canvas, resultBitmap.getWidth(), resultBitmap.getHeight());
        
        // Clean up resources
        safeRecycleBitmap(maskBitmap);
        
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
        
        // Draw text overlay
        Canvas canvas = new Canvas(resultBitmap);
        drawTextOverlay(canvas, resultBitmap.getWidth(), resultBitmap.getHeight());
        
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
        if (text == null || text.trim().isEmpty()) {
            return; // Skip drawing if no text
        }
        
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
                // Background area: light gray with high opacity
                colors[i] = Color.argb(BACKGROUND_ALPHA, BACKGROUND_RGB, BACKGROUND_RGB, BACKGROUND_RGB);
            } else if (backgroundLikelihood > BACKGROUND_THRESHOLD_LOW) {
                // Transition area: interpolate between transparent and light gray
                int alpha = calculateInterpolatedAlpha(backgroundLikelihood);
                colors[i] = Color.argb(alpha, BACKGROUND_RGB, BACKGROUND_RGB, BACKGROUND_RGB);
            }
            // Areas with backgroundLikelihood <= BACKGROUND_THRESHOLD_LOW remain transparent (person area)
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
