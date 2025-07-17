package com.mpt.mpt_callkit;

import com.mpt.mpt_callkit.receiver.PortMessageReceiver;
import com.mpt.mpt_callkit.PortSipService;
import com.mpt.mpt_callkit.util.CallManager;

import android.annotation.SuppressLint;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Build;
import android.os.Bundle;
import android.preference.PreferenceManager;
import androidx.annotation.Nullable;
import android.text.TextUtils;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.AdapterView;
import android.widget.ArrayAdapter;
import android.widget.EditText;
import android.widget.Spinner;
import android.widget.TextView;
import android.widget.Toast;
import com.mpt.mpt_callkit.util.Engine;
import com.mpt.mpt_callkit.util.Session;
import com.portsip.PortSipSdk;

import static com.mpt.mpt_callkit.PortSipService.EXTRA_REGISTER_STATE;

public class LoginFragment extends BaseFragment
        implements AdapterView.OnItemSelectedListener, View.OnClickListener, PortMessageReceiver.BroadcastListener {
    MainActivity activity;
    private EditText etUsername = null;
    private EditText etPassword = null;
    private EditText etSipServer = null;
    private EditText etSipServerPort = null;

    private EditText etDisplayName = null;

    private EditText etUserDomain = null;
    private EditText etAuthName = null;
    private EditText etStunServer = null;
    private EditText etStunPort = null;
    private Spinner spTransport;
    private Spinner spSRTP;
    private TextView tvStatus;
    private SharedPreferences sharedPreferences;

    @Nullable
    @Override
    public View onCreateView(LayoutInflater inflater, @Nullable ViewGroup container,
            @Nullable Bundle savedInstanceState) {
        activity = (MainActivity) getActivity();
        sharedPreferences = PreferenceManager.getDefaultSharedPreferences(getActivity());
        View view = inflater.inflate(R.layout.login, container, false);
        return view;
    }

    @SuppressLint("SetTextI18n")
    @Override
    public void onViewCreated(View view, Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);

        tvStatus = (TextView) view.findViewById(R.id.txtips);

        etUsername = (EditText) view.findViewById(R.id.etusername);
        etPassword = (EditText) view.findViewById(R.id.etpwd);
        etSipServer = (EditText) view.findViewById(R.id.etsipsrv);
        etSipServerPort = (EditText) view.findViewById(R.id.etsipport);

        etDisplayName = (EditText) view.findViewById(R.id.etdisplayname);
        etUserDomain = (EditText) view.findViewById(R.id.etuserdomain);
        etAuthName = (EditText) view.findViewById(R.id.etauthName);
        etStunServer = (EditText) view.findViewById(R.id.etStunServer);
        etStunPort = (EditText) view.findViewById(R.id.etStunPort);

        spTransport = (Spinner) view.findViewById(R.id.spTransport);
        spSRTP = (Spinner) view.findViewById(R.id.spSRTP);

        spSRTP.setOnItemSelectedListener(this);
        spTransport.setOnItemSelectedListener(this);

        spTransport.setAdapter(ArrayAdapter.createFromResource(getActivity(), R.array.transports,
                android.R.layout.simple_list_item_1));
        spSRTP.setAdapter(
                ArrayAdapter.createFromResource(getActivity(), R.array.srtp, android.R.layout.simple_list_item_1));

        LoadUserInfo();
        setOnlineStatus(null);

        activity.receiver.broadcastReceiver = this;
        System.out.println("SDK-Android: broadcastReceiver - login_fragment - set: "
                + activity.receiver.broadcastReceiver.toString());
        view.findViewById(R.id.btonline).setOnClickListener(this);
        view.findViewById(R.id.btoffline).setOnClickListener(this);

        register();
    }

    @Override
    public void onHiddenChanged(boolean hidden) {
        super.onHiddenChanged(hidden);
        if (!hidden) {
            activity.receiver.broadcastReceiver = this;
            System.out.println("SDK-Android: broadcastReceiver - login_fragment - onHiddenChanged - set: "
                    + activity.receiver.broadcastReceiver.toString());
            setOnlineStatus(null);
        }
    }

    @Override
    public void onDestroyView() {
        super.onDestroyView();
        activity.receiver.broadcastReceiver = null;
        System.out.println("SDK-Android: broadcastReceiver - login_fragment - set null");
    }

    private void LoadUserInfo() {

        etUsername.setText(sharedPreferences.getString(PortSipService.USER_NAME, null));
        etPassword.setText(sharedPreferences.getString(PortSipService.USER_PWD, null));
        etSipServer.setText(sharedPreferences.getString(PortSipService.SVR_HOST, null));
        etSipServerPort.setText(sharedPreferences.getString(PortSipService.SVR_PORT, "5063"));

        etDisplayName.setText(sharedPreferences.getString(PortSipService.USER_DISPALYNAME, null));
        etUserDomain.setText(sharedPreferences.getString(PortSipService.USER_DOMAIN, null));
        etAuthName.setText(sharedPreferences.getString(PortSipService.USER_AUTHNAME, null));
        etStunServer.setText(sharedPreferences.getString(PortSipService.STUN_HOST, null));
        etStunPort.setText(sharedPreferences.getString(PortSipService.STUN_PORT, "3478"));

        spTransport.setSelection(sharedPreferences.getInt(PortSipService.TRANS, 0));
        spSRTP.setSelection(sharedPreferences.getInt(PortSipService.SRTP, 0));
    }

    private void SaveUserInfo() {
        SharedPreferences.Editor editor = sharedPreferences.edit();
        editor.putString(PortSipService.USER_NAME, etUsername.getText().toString());
        editor.putString(PortSipService.USER_PWD, etPassword.getText().toString());
        editor.putString(PortSipService.SVR_HOST, etSipServer.getText().toString());
        editor.putString(PortSipService.SVR_PORT, etSipServerPort.getText().toString());

        editor.putString(PortSipService.USER_DISPALYNAME, etDisplayName.getText().toString());
        editor.putString(PortSipService.USER_DOMAIN, etUserDomain.getText().toString());
        editor.putString(PortSipService.USER_AUTHNAME, etAuthName.getText().toString());
        editor.putString(PortSipService.STUN_HOST, etStunServer.getText().toString());
        editor.putString(PortSipService.STUN_PORT, etStunPort.getText().toString());

        editor.commit();
    }

    public void onBroadcastReceiver(Intent intent) {
        String action = intent == null ? "" : intent.getAction();
        if (PortSipService.REGISTER_CHANGE_ACTION.equals(action)) {
            System.out.println("SDK-Android: REGISTER_CHANGE_ACTION - login");
            String tips = intent.getStringExtra(EXTRA_REGISTER_STATE);
            setOnlineStatus(tips);
            // makeCall();
        } else if (PortSipService.CALL_CHANGE_ACTION.equals(action)) {
            // long sessionId = intent.GetLongExtra(PortSipService.EXTRA_CALL_SEESIONID,
            // Session.INVALID_SESSION_ID);
            // callStatusChanged(sessionId);
        }
    }

    public void makeCall() {
        PortSipSdk portSipSdk = Engine.Instance().getEngine();
        Session currentLine = CallManager.Instance().getCurrentSession();
        String callTo = "200010";
        if (!currentLine.IsIdle()) {
            Toast.makeText(getActivity(), "Current line is busy now, please switch a line.", Toast.LENGTH_SHORT).show();
            return;
        }

        // Ensure that we have been added one audio codec at least
        if (portSipSdk.isAudioCodecEmpty()) {
            Toast.makeText(getActivity(), "Audio Codec Empty,add audio codec at first", Toast.LENGTH_SHORT).show();
            return;
        }

        // Usually for 3PCC need to make call without SDP
        long sessionId = portSipSdk.call(callTo, true, true);
        if (sessionId <= 0) {
            Toast.makeText(getActivity(), "Call failure", Toast.LENGTH_SHORT).show();
            return;
        }
        // default send video
        portSipSdk.sendVideo(sessionId, true);

        currentLine.remote = callTo;

        currentLine.sessionID = sessionId;
        currentLine.state = Session.CALL_STATE_FLAG.TRYING;
        currentLine.hasVideo = true;
        Toast.makeText(getActivity(), currentLine.lineName + ": Calling...", Toast.LENGTH_SHORT).show();
    }

    private void setOnlineStatus(String tips) {
        if (CallManager.Instance().isRegistered) {
            tvStatus.setText(TextUtils.isEmpty(tips) ? getString(R.string.online) : tips);
        } else {
            tvStatus.setText(TextUtils.isEmpty(tips) ? getString(R.string.offline) : tips);
        }
    }

    @Override
    public void onClick(View view) {
        if (view.getId() == R.id.btonline) {
            if (CallManager.Instance().online) {
                Toast.makeText(getActivity(), "Please OffLine First", Toast.LENGTH_SHORT).show();
            } else {
                SaveUserInfo();
                Intent onLineIntent = new Intent(getActivity(), PortSipService.class);
                onLineIntent.setAction(PortSipService.ACTION_SIP_REGIEST);
                PortSipService.startServiceCompatibility(getActivity(), onLineIntent);
                tvStatus.setText("RegisterServer..");
            }
        } else if (view.getId() == R.id.btoffline) {
            Intent offLineIntent = new Intent(getActivity(), PortSipService.class);
            offLineIntent.setAction(PortSipService.ACTION_SIP_UNREGIEST);
            PortSipService.startServiceCompatibility(getActivity(), offLineIntent);
            tvStatus.setText("unRegisterServer");
        }
    }

    @Override
    public void onItemSelected(AdapterView<?> adapterView, View view, int position, long l) {
        if (adapterView == null)
            return;
        SharedPreferences.Editor editor = sharedPreferences.edit();
        if (adapterView.getId() == R.id.spSRTP) {
            editor.putInt(PortSipService.SRTP, position).commit();
        } else if (adapterView.getId() == R.id.spTransport) {
            editor.putInt(PortSipService.TRANS, position).commit();
        }
    }

    @Override
    public void onNothingSelected(AdapterView<?> adapterView) {

    }

    public void register() {
        if (CallManager.Instance().online) {
            Toast.makeText(getActivity(), "Please OffLine First", Toast.LENGTH_SHORT).show();
        } else {
            Intent onLineIntent = new Intent(getActivity(), PortSipService.class);
            onLineIntent.setAction(PortSipService.ACTION_SIP_REGIEST);
            PortSipService.startServiceCompatibility(getActivity(), onLineIntent);
        }
    }
}
