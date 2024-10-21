package com.mpt.mpt_callkit.util;

public class Contact
{
    public String subRequestDescription;
    public enum SUBSCRIBE_STATE_FLAG
    {
        UNSETTLLED,
        ACCEPTED ,
        REJECTED,
        UNSUBSCRIBE,
    }
    public String sipAddr;
    public String subDescription;
    public boolean subScribeRemote;

    public long subId;//if SubId >0 means received remote subscribe
    public SUBSCRIBE_STATE_FLAG state; // weigher accept remote subscribe

    public String currentStatusToString()
    {
        String status = "";

        status += "Subscribe："+ subScribeRemote;
        status += "  Remote presence is：" + subDescription;


        status += " Subscription received:("+ subRequestDescription+")";
        switch (state)
        {
            case ACCEPTED:
                status += "Accepted";
                break;
            case REJECTED:
                status += "Rejected";
                break;
            case UNSETTLLED:
                status += "Pending";
                break;
            case UNSUBSCRIBE:
                status += "Not subscripted";
                break;
        }

        return status;
    }
    public Contact()
    {
        state = SUBSCRIBE_STATE_FLAG.UNSUBSCRIBE;//Not being subscripted
        subScribeRemote = false;//Not subscripted
        subId = 0;
    }

}


