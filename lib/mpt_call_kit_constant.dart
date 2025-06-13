class MptCallKitConstants {
  static const String login = 'Login';
  static const String offline = 'Offline';
  static const String hangOut = 'onHangOut';
}

class CallStateConstants {
  static const String INCOMING = "INCOMING";
  static const String TRYING = "TRYING  ";
  static const String CONNECTED = "CONNECTED";
  static const String ANSWERED = "ANSWERED";
  static const String FAILED = "FAILED";
  static const String CLOSED = "CLOSED";
}

class AgentStatusConstants {
  static const String READY = "READY";
  static const String NOT_READY = "NOT_READY";
  static const String AGENT_LOGOUT = "AGENT_LOGOUT";
  static const String OFFLINE = "OFFLINE";
  static const String IN_CALL = "IN_CALL";
}

class AppEventConstants {
  static const String READY = "READY";
  static const String LOGGED_IN = "LOGGED_IN";
  static const String LOGGED_OUT = "LOGGED_OUT";
  static const String TOKEN_EXPIRED = "TOKEN_EXPIRED";
  static const String ERROR = "ERROR";
}

class CallType {
  static const String VIDEO = "VIDEO";
  static const String VOICE = "VOICE";
}

class MessageSocket {
  static const String INBOUND_CALL = "INIT";
  static const String OFFER_CALL = "OFFER";
  static const String ANSWER_CALL = "ANSWER";
  static const String REJECT_CALL = "REJECT";
  static const String END_CALL = "HANGUP";
  static const String CLOSE = "CLOSE_CONVERSATION";
  static const String EXTEND_TIME_CLOSE = "EXTEND_CLOSE_TIME_CONVERSATION";
  static const String READ_CONVERSATION = "READ_CONVERSATION";
  static const String MESSAGE_TRANSFERED = "MESSAGE_TRANSFERED";
  static const String ASSIGN_CONVERSATION = "ASSIGN_CONVERSATION";
  static const String NEW_CONVERSATION = "NEW_CONVERSATION";
  static const String TRANSFER_CONVERSATION = "TRANSFER_CONVERSATION";
  static const String PICK_CONVERSATION = "PICK_CONVERSATION";
  static const String UNASSIGN_CONVERSATION = "UNASSIGN_CONVERSATION";
  static const String START_CONVERSATION = "START_CONVERSATION";
  static const String AGENT_STATUS_CHANGED = "AGENT_STATUS_CHANGED";
  static const String SAVE_BUSINESS_RESULT = "SAVE_BUSINESS_RESULT";
  static const String EDIT_NOTE_MESSAGE = "EDIT_NOTE_MESSAGE";
  static const String ATTACH_TAGS = "ATTACH_TAGS";
  static const String TRANSFER_FAILED = "TRANSFER_FAIL";
  static const String TRANSFER_RINGING = "TRANSFER_RINGING";
  static const String TRANSFER_ANSWER = "TRANSFER_ANSWER";
  static const String TRANSFER_ACCEPTED = "TRANSFER_ACCEPTED";
}

class CallTypeConstants {
  static const String INCOMING_CALL = "INCOMING_CALL";
  static const String OUTGOING_CALL = "OUTGOING_CALL";
  static const String ENDED = "ENDED";
}

class ChannelConstants {
  static const String FB_MESSAGE = "FB_MESSAGE";
  static const String ZL_MESSAGE = "ZL_MESSAGE";
  static const String VB_MESSAGE = "VB_MESSAGE";
  static const String TL_MESSAGE = "TL_MESSAGE";
  static const String WA_MESSAGE = "WA_MESSAGE";
  static const String VOICE = "VOICE";
  static const String GMAIL = "GMAIL";
  static const String CALL = "CALL";
  static const String LIVE_CONNECT = "LIVE_CONNECT";
}

class SpeakerStatusConstants {
  static const String SPEAKER_PHONE = "SPEAKER_PHONE";
  static const String EARPIECE = "EARPIECE";
  static const String BLUETOOTH = "BLUETOOTH";
  static const String WIRED_HEADSET = "WIRED_HEADSET";
}

class AgentStateConstants {
  static const String IDLE = "IDLE";
  static const String TALKING = "TALKING";
}
