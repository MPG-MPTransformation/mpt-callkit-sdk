package com.mpt.mpt_callkit.util;

public class Session
{
	public static int INVALID_SESSION_ID = -1;
	public long sessionID;
	public String remote;
	public String displayName;

	public boolean bScreenShare;
	public boolean hasVideo;
	public boolean bHold;
	public boolean bMute;
	public boolean bEarlyMedia;
	public String lineName;
	public CALL_STATE_FLAG state;
	public boolean bMuteAudioInComing = false;
	public boolean bMuteAudioOutGoing = false;
	public boolean bMuteVideo = false;

	public String sipMessage;

	public boolean IsIdle()
	{
		return state == CALL_STATE_FLAG.FAILED || state == CALL_STATE_FLAG.CLOSED;
	}
	public Session()
	{
		remote = null;
		displayName = null;
		hasVideo = false;
		sessionID = INVALID_SESSION_ID;
		state = CALL_STATE_FLAG.CLOSED;
	}

	public void Reset()
	{
		remote = null;
		displayName = null;
		hasVideo = false;
		bScreenShare = false;
		sessionID = INVALID_SESSION_ID;
		state = CALL_STATE_FLAG.CLOSED;
		bEarlyMedia = false;
	}

	public enum CALL_STATE_FLAG
	{
		INCOMING,
		TRYING ,
		CONNECTED,
		FAILED,
		CLOSED,
	}

	public void setSipMessage(String message) {
		this.sipMessage = message;
	}
}


