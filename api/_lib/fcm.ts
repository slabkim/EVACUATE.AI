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
    data: {
      ...input.data,
      title: input.title,
      body: input.body,
    },
    android: {
      priority: "high",
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
