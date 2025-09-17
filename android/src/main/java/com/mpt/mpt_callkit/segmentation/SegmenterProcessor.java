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
import android.util.Log;
import androidx.annotation.NonNull;
import android.graphics.Bitmap;
import android.graphics.Bitmap.Config;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Matrix;
import android.graphics.Paint;
import android.graphics.Rect;
import android.graphics.Typeface;
import java.nio.ByteBuffer;
import com.google.android.gms.tasks.Task;
import com.google.mlkit.vision.common.InputImage;
import com.mpt.mpt_callkit.segmentation.VisionProcessorBase;
import com.mpt.mpt_callkit.segmentation.PreferenceUtils;
import com.google.mlkit.vision.segmentation.Segmentation;
import com.google.mlkit.vision.segmentation.SegmentationMask;
import com.google.mlkit.vision.segmentation.Segmenter;
import com.google.mlkit.vision.segmentation.selfie.SelfieSegmenterOptions;
import com.mpt.mpt_callkit.segmentation.VisionImageProcessorCallback;

/** A processor to run Segmenter. */
public class SegmenterProcessor extends VisionProcessorBase<SegmentationMask> {

  private static final String TAG = "SegmenterProcessor";

  private final Segmenter segmenter;
  private final VisionImageProcessorCallback callback;
  private String text;

  public SegmenterProcessor(Context context, VisionImageProcessorCallback callback, String text) {
      this(context, /* isStreamMode= */ true, callback, text);
  }

  public SegmenterProcessor(Context context, boolean isStreamMode, VisionImageProcessorCallback callback, String text) {
    super(context);
    SelfieSegmenterOptions.Builder optionsBuilder = new SelfieSegmenterOptions.Builder();
    optionsBuilder.setDetectorMode(
      isStreamMode ? SelfieSegmenterOptions.STREAM_MODE : SelfieSegmenterOptions.SINGLE_IMAGE_MODE);
    this.callback = callback;
    this.text = text;


    SelfieSegmenterOptions options = optionsBuilder.build();
    segmenter = Segmentation.getClient(options);
    Log.d(TAG, "SegmenterProcessor created with option: " + options);
  }

  @Override
  protected Task<SegmentationMask> detectInImage(InputImage image) {
    return segmenter.process(image);
  }

  @Override
  protected void onSuccess(
      @NonNull SegmentationMask segmentationMask, @NonNull Bitmap originalCameraImage, long frameStartMs) {
        // System.out.println("SDK-Android: SegmenterProcessor onSuccess, frameStartMs: " + frameStartMs);
        callback.onDetectionSuccess(maskToBitmap(segmentationMask, originalCameraImage), frameStartMs);
  }

  @Override
  protected void onFailure(@NonNull Exception e) {
    Log.e(TAG, "Segmentation failed: " + e);
    // System.out.println("SDK-Android: SegmenterProcessor onFailure: " + e.getMessage());
    callback.onDetectionFailure(e);
  }

  public String getText() {
    return text;
  }

  public void setText(String text) {
    this.text = text;
  }

  private Bitmap maskToBitmap(SegmentationMask segmentationMask, Bitmap originalCameraImage) {
    ByteBuffer mask = segmentationMask.getBuffer();
    int maskWidth = segmentationMask.getWidth();
    int maskHeight = segmentationMask.getHeight();
    
    // Create a mutable copy of the original camera image
    Bitmap resultBitmap = originalCameraImage.copy(originalCameraImage.getConfig(), true);
    
    // Create the mask bitmap
    Bitmap maskBitmap = Bitmap.createBitmap(maskColorsFromByteBuffer(mask, maskWidth, maskHeight), maskWidth, maskHeight, Config.ARGB_8888);
    
    // Scale the mask bitmap to match the original image dimensions if needed
    if (maskWidth != originalCameraImage.getWidth() || maskHeight != originalCameraImage.getHeight()) {
      maskBitmap = Bitmap.createScaledBitmap(maskBitmap, originalCameraImage.getWidth(), originalCameraImage.getHeight(), true);
    }
    
    // Draw the mask onto the original image
    Canvas canvas = new Canvas(resultBitmap);
    Paint paint = new Paint();
    paint.setAntiAlias(true);
    canvas.drawBitmap(maskBitmap, 0, 0, paint);
    
    // Draw black text at top center
    String text = this.text;
    Paint textPaint = new Paint();
    textPaint.setColor(Color.BLACK);
    textPaint.setTextSize(48); // Adjust size as needed
    textPaint.setTypeface(Typeface.DEFAULT_BOLD);
    textPaint.setAntiAlias(true);
    textPaint.setTextAlign(Paint.Align.CENTER);
    
    // Calculate text position (top center)
    Rect textBounds = new Rect();
    textPaint.getTextBounds(text, 0, text.length(), textBounds);
    float x = resultBitmap.getWidth() / 2f; // Center horizontally
    float y = textBounds.height() + 40; // Top with some margin
    
    canvas.drawText(text, x, y, textPaint);
    
    // Clean up the temporary mask bitmap
    if (maskBitmap != null && !maskBitmap.isRecycled()) {
      maskBitmap.recycle();
    }
    
    return resultBitmap;
  }

  private int[] maskColorsFromByteBuffer(ByteBuffer byteBuffer, int maskWidth, int maskHeight) {
    int[] colors = new int[maskWidth * maskHeight];
    for (int i = 0; i < maskWidth * maskHeight; i++) {
      float backgroundLikelihood = 1 - byteBuffer.getFloat();
      if (backgroundLikelihood > 0.9) {
        // Background area: light gray with 0.9 opacity (alpha = 230)
        colors[i] = Color.argb(230, 211, 211, 211); // Light gray (RGB: 211, 211, 211)
      } else if (backgroundLikelihood > 0.2) {
        // Transition area: interpolate between transparent and light gray
        // Linear interpolation for alpha from 0 to 230
        int alpha = (int) (328.57 * backgroundLikelihood - 65.71 + 0.5);
        colors[i] = Color.argb(alpha, 211, 211, 211);
      }
      // Areas with backgroundLikelihood <= 0.2 remain transparent (person area)
    }
    return colors;
  }
}
