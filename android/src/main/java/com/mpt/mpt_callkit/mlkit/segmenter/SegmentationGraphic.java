package com.mpt.mpt_callkit.mlkit.segmenter;

import android.graphics.Bitmap;
import android.graphics.Bitmap.Config;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Matrix;
import android.graphics.Paint;
import android.graphics.PorterDuff;
import android.graphics.PorterDuffXfermode;
import android.renderscript.Allocation;
import android.renderscript.Element;
import android.renderscript.RenderScript;
import android.renderscript.ScriptIntrinsicBlur;
import androidx.annotation.ColorInt;
import com.mpt.mpt_callkit.mlkit.GraphicOverlay;
import com.mpt.mpt_callkit.mlkit.GraphicOverlay.Graphic;
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

    /**
     * Draws the segmented background with simplified effect on the supplied canvas.
     */
    @Override
    public void draw(Canvas canvas) {
        try {
            // Create mask bitmap
            Bitmap maskBitmap = Bitmap.createBitmap(
                    maskColorsFromByteBuffer(mask), maskWidth, maskHeight, Config.ARGB_8888);

            // Apply simplified background effect (instead of heavy blur)
            applySimplifiedBackground(canvas, maskBitmap);

            // Clean up
            maskBitmap.recycle();

        } catch (Exception e) {
            // Fallback: just draw a simple dark overlay
            drawFallbackOverlay(canvas);
        } finally {
            // Reset byteBuffer pointer to beginning, so that the mask can be redrawn if
            // screen is refreshed
            mask.rewind();
        }
    }

    private Bitmap createBlurredBackground(Bitmap original) {
        try {
            // Create RenderScript
            RenderScript rs = RenderScript.create(getApplicationContext());

            // Create a blurred version of the original
            Bitmap blurred = original.copy(Config.ARGB_8888, true);

            // Create allocations
            Allocation input = Allocation.createFromBitmap(rs, blurred);
            Allocation output = Allocation.createFromBitmap(rs, blurred);

            // Create blur script
            ScriptIntrinsicBlur script = ScriptIntrinsicBlur.create(rs, Element.U8_4(rs));
            script.setRadius(25f); // Blur radius (max 25)
            script.setInput(input);
            script.forEach(output);

            // Copy output to blurred bitmap
            output.copyTo(blurred);

            // Clean up
            script.destroy();
            input.destroy();
            output.destroy();
            rs.destroy();

            return blurred;
        } catch (Exception e) {
            // Fallback: return original bitmap if blur fails
            return original.copy(Config.ARGB_8888, true);
        }
    }

    private void applySimplifiedBackground(Canvas canvas, Bitmap maskBitmap) {
        Paint paint = new Paint();
        paint.setAntiAlias(true);

        // Draw a simple dark/colored overlay for background
        paint.setColor(Color.argb(150, 0, 0, 0)); // Semi-transparent dark overlay
        canvas.drawRect(0, 0, canvas.getWidth(), canvas.getHeight(), paint);

        // Apply mask to preserve person (foreground) - remove overlay where person is
        paint.setXfermode(new PorterDuffXfermode(PorterDuff.Mode.DST_OUT));
        if (isRawSizeMaskEnabled) {
            Matrix matrix = new Matrix(getTransformationMatrix());
            matrix.preScale(scaleX, scaleY);
            canvas.drawBitmap(maskBitmap, matrix, paint);
        } else {
            canvas.drawBitmap(maskBitmap, getTransformationMatrix(), paint);
        }
    }

    private void drawFallbackOverlay(Canvas canvas) {
        // Simple fallback - just draw a light overlay
        Paint paint = new Paint();
        paint.setColor(Color.argb(80, 0, 0, 0));
        canvas.drawRect(0, 0, canvas.getWidth(), canvas.getHeight(), paint);
    }

    /** Converts byteBuffer floats to ColorInt array that can be used as a mask. */
    @ColorInt
    private int[] maskColorsFromByteBuffer(ByteBuffer byteBuffer) {
        @ColorInt
        int[] colors = new int[maskWidth * maskHeight];

        // Process with reduced precision for better performance
        int stride = Math.max(1, maskWidth * maskHeight / 10000); // Sample every nth pixel for large masks

        for (int i = 0; i < maskWidth * maskHeight; i += stride) {
            float backgroundLikelihood = 1 - byteBuffer.getFloat();

            @ColorInt
            int color;
            if (backgroundLikelihood > 0.7) {
                // High confidence background - full mask
                color = Color.argb(255, 255, 255, 255);
            } else {
                color = Color.argb(128, 255, 255, 255);
            }

            // Fill stride pixels with same color for performance
            for (int j = i; j < Math.min(i + stride, colors.length); j++) {
                colors[j] = color;
            }
        }

        // Skip remaining bytes if stride was used
        if (stride > 1) {
            byteBuffer.position(byteBuffer.position() + (maskWidth * maskHeight - byteBuffer.position() / 4) * 4);
        }

        return colors;
    }
}
