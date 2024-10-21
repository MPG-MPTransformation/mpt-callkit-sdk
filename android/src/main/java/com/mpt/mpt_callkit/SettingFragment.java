package com.mpt.mpt_callkit;

import com.mpt.mpt_callkit.util.Engine;
import com.portsip.PortSipSdk;
import com.mpt.mpt_callkit.PortSipService;

import android.content.SharedPreferences;
import android.os.Bundle;
import android.preference.PreferenceFragment;
import android.preference.PreferenceManager;
import androidx.annotation.Nullable;
import android.view.View;

public class SettingFragment extends PreferenceFragment {
	MainActivity activity;
	@Override
	public void onCreate(Bundle savedInstanceState)
	{
		super.onCreate(savedInstanceState);
		activity = (MainActivity) getActivity();
		addPreferencesFromResource(R.xml.setting);
	}

	@Override
	public void onViewCreated(View view, @Nullable Bundle savedInstanceState) {
		super.onViewCreated(view, savedInstanceState);
		view.setBackgroundColor(getResources().getColor(R.color.white));
	}

	@Override
	public void onHiddenChanged(boolean hidden) {
		super.onHiddenChanged(hidden);
		if (hidden) {
			SharedPreferences preferences = PreferenceManager.getDefaultSharedPreferences(getActivity());
			PortSipService.ConfigPreferences(getActivity(), Engine.Instance().getEngine());
		}else{
			activity.receiver.broadcastReceiver =null;
		}
	}
}
