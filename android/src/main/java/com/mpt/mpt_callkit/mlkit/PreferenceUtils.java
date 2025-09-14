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

package com.mpt.mpt_callkit.mlkit;

import android.content.Context;
import android.content.SharedPreferences;
import androidx.preference.PreferenceManager;

/** Utility class for handling shared preferences. */
public class PreferenceUtils {

    private static final String PREF_KEY_SEGMENTATION_RAW_SIZE_MASK = "srsm";

    private PreferenceUtils() {
        // Private constructor to prevent instantiation
    }

    /**
     * Returns whether the raw size mask should be enabled for segmentation.
     * For now, we default to true for better performance.
     */
    public static boolean shouldSegmentationEnableRawSizeMask(Context context) {
        SharedPreferences sharedPreferences = PreferenceManager.getDefaultSharedPreferences(context);
        return sharedPreferences.getBoolean(PREF_KEY_SEGMENTATION_RAW_SIZE_MASK, true);
    }

    /**
     * Sets whether the raw size mask should be enabled for segmentation.
     */
    public static void setSegmentationRawSizeMaskEnabled(Context context, boolean enabled) {
        SharedPreferences sharedPreferences = PreferenceManager.getDefaultSharedPreferences(context);
        sharedPreferences.edit().putBoolean(PREF_KEY_SEGMENTATION_RAW_SIZE_MASK, enabled).apply();
    }
}
