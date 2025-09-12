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

package com.mpt.mpt_callkit.segmenter;

import android.content.Context;
import android.util.Log;
import androidx.annotation.NonNull;
import com.google.android.gms.tasks.Task;
import com.google.mlkit.vision.common.InputImage;

/** Abstract base class for ML Kit Vision API processors. */
public abstract class VisionProcessorBase<T> {

    private final Context context;

    protected VisionProcessorBase(Context context) {
        this.context = context;
    }

    public Context getContext() {
        return context;
    }

    public void processImageProxy(InputImage image, GraphicOverlay graphicOverlay) {
        detectInImage(image)
                .addOnSuccessListener(results -> onSuccess(results, graphicOverlay))
                .addOnFailureListener(this::onFailure);
    }

    /** Detects feature from given InputImage. */
    public abstract Task<T> detectInImage(InputImage image);

    /** Callback when detection succeeded. */
    protected abstract void onSuccess(@NonNull T results, @NonNull GraphicOverlay graphicOverlay);

    /** Callback when detection failed. */
    protected abstract void onFailure(@NonNull Exception e);
}
