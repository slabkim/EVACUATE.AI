import { getMessaging } from "firebase-admin/messaging";

import { db } from "./firestore";

export interface PushMessageInput {
  token: string;
  title: string;
  body: string;
  data: Record<string, string>;
}

export async function sendPushToToken(
  input: PushMessageInput,
): Promise<string> {
  db();
  return getMessaging().send({
    token: input.token,
    notification: {
      title: input.title,
      body: input.body,
    },
    data: {
      ...input.data,
      title: input.title,
      body: input.body,
    },
    android: {
      priority: "high",
      notification: {
        sound: "sirene",
        channelId: "evacuate_alert_channel_v4",
      },
    },
    apns: {
      headers: {
        "apns-priority": "10",
        "apns-push-type": "alert",
      },
      payload: {
        aps: {
          alert: {
            title: input.title,
            body: input.body,
          },
          sound: "sirene.mp3",
        },
      },
    },
  });
}
