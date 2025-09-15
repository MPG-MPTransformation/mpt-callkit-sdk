package com.mpt.mpt_callkit.mlkit.segmenter;

import android.graphics.Bitmap;
import android.graphics.Bitmap.Config;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Matrix;
import androidx.annotation.ColorInt;
import com.mpt.mpt_callkit.mlkit.base.GraphicOverlay;
import com.mpt.mpt_callkit.mlkit.base.GraphicOverlay.Graphic;
import com.google.mlkit.vision.segmentation.SegmentationMask;
import java.nio.ByteBuffer;

/** Draw the mask from SegmentationResult in preview. */
public class SegmentationGraphic extends Graphic {

    private final ByteBuffer mask;
    private final int maskWidth;
    private final int maskHeight;
    private final boolean isRawSizeMaskEnabled;
    private final float scaleX;
    private final float scaleY;

    public SegmentationGraphic(
            GraphicOverlay overlay,
            SegmentationMask segmentationMask) {
        super(overlay);
        mask = segmentationMask.getBuffer();
        maskWidth = segmentationMask.getWidth();
        maskHeight = segmentationMask.getHeight();

        isRawSizeMaskEnabled = maskWidth != overlay.getImageWidth()
                || maskHeight != overlay.getImageHeight();
        scaleX = overlay.getImageWidth() * 1f / maskWidth;
        scaleY = overlay.getImageHeight() * 1f / maskHeight;
    }

    /** Draws the segmented background on the supplied canvas. */
    @Override
    public void draw(Canvas canvas) {
        Bitmap bitmap = Bitmap.createBitmap(
                maskColorsFromByteBuffer(mask), maskWidth, maskHeight, Config.ARGB_8888);
        if (isRawSizeMaskEnabled) {
            Matrix matrix = new Matrix(getTransformationMatrix());
            matrix.preScale(scaleX, scaleY);
            canvas.drawBitmap(bitmap, matrix, null);
        } else {
            canvas.drawBitmap(bitmap, getTransformationMatrix(), null);
        }
        bitmap.recycle();
        // Reset byteBuffer pointer to beginning, so that the mask can be redrawn if
        // screen is refreshed
        mask.rewind();
    }

    /** Converts byteBuffer floats to ColorInt array that can be used as a mask. */
    @ColorInt
    private int[] maskColorsFromByteBuffer(ByteBuffer byteBuffer) {
        @ColorInt
        int[] colors = new int[maskWidth * maskHeight];
        for (int i = 0; i < maskWidth * maskHeight; i++) {
            float backgroundLikelihood = 1 - byteBuffer.getFloat();
            if (backgroundLikelihood > 0.9) {
                colors[i] = Color.argb(190, 0, 0, 0);
            } else if (backgroundLikelihood > 0.2) {
                // Linear interpolation to make sure when backgroundLikelihood is 0.2, the alpha
                // is 0 and
                // when backgroundLikelihood is 0.9, the alpha is 128.
                // +0.5 to round the float value to the nearest int.
                int alpha = (int) (182.9 * backgroundLikelihood - 36.6 + 0.5);
                colors[i] = Color.argb(190, 0, 0, 0);
            }
        }
        return colors;
    }
}
