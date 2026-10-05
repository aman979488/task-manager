const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {logger} = require("firebase-functions");

initializeApp();

const db = getFirestore();
const leaseDurationMs = 5 * 60 * 1000;
const deadlineWindowMs = 3 * 60 * 60 * 1000;

function parseTaskDate(timestampValue, stringValue) {
  if (timestampValue && typeof timestampValue.toDate === "function") {
    return timestampValue.toDate();
  }
  if (timestampValue instanceof Date) return timestampValue;
  if (typeof stringValue === "string") {
    const parsed = new Date(stringValue);
    if (!Number.isNaN(parsed.getTime())) return parsed;
  }
  return null;
}

exports.dispatchScheduledTaskNotifications = onSchedule(
    {schedule: "every 1 minutes", timeZone: "UTC"},
    async () => {
      const snapshot = await db.collection("map").get();
      const now = new Date();

      for (const taskSnapshot of snapshot.docs) {
        try {
          const taskRef = taskSnapshot.ref;
          await db.runTransaction(async (transaction) => {
            const current = await transaction.get(taskRef);
            if (!current.exists) return;

            const task = current.data();
            const assignee = task.assignee?.toString().trim();
            if (!assignee) return;

            const reminderAt = parseTaskDate(task.reminderAt, task.reminder);
            const deadlineAt = parseTaskDate(task.deadlineAt, task.deadline);
            const dueNotifications = [];

            if (!task.reminderSent && reminderAt && reminderAt <= now) {
              dueNotifications.push({
                id: `${taskRef.id}_reminder`,
                sentField: "reminderSent",
                title: "Reminder",
                body: `Reminder for task: "${task.title || ""}"`,
                type: "task_reminder",
              });
            }

            if (!task.deadlineReminderSent &&
                deadlineAt &&
                deadlineAt > now &&
                deadlineAt.getTime() - now.getTime() <= deadlineWindowMs) {
              dueNotifications.push({
                id: `${taskRef.id}_deadline`,
                sentField: "deadlineReminderSent",
                title: "Deadline approaching",
                body: `Your task "${task.title || ""}" is nearing its deadline at ${deadlineAt.toLocaleString()}.`,
                type: "task_deadline",
              });
            }

            if (dueNotifications.length === 0) return;

            const pending = [];
            for (const item of dueNotifications) {
              const notificationRef = db.collection("notifications").doc(item.id);
              const notificationSnapshot = await transaction.get(notificationRef);
              pending.push({item, notificationRef, notificationSnapshot});
            }

            const taskUpdates = {};
            for (const entry of pending) {
              taskUpdates[entry.item.sentField] = true;
              if (entry.notificationSnapshot.exists) continue;
              transaction.create(entry.notificationRef, {
                recipientName: assignee,
                title: entry.item.title,
                body: entry.item.body,
                timestamp: FieldValue.serverTimestamp(),
                isRead: false,
                type: entry.item.type,
              });
            }
            transaction.update(taskRef, taskUpdates);
          });
        } catch (error) {
          logger.error("Failed to schedule task notification", {
            taskId: taskSnapshot.id,
            error,
          });
        }
      }
    },
);

exports.deliverTaskNotification = onDocumentCreated(
    {
      document: "notifications/{notificationId}",
      retry: true,
    },
    async (event) => {
      const notificationRef = event.data.ref;
      const notification = event.data.data();
      const now = Date.now();
      const claimed = await db.runTransaction(async (transaction) => {
        const current = await transaction.get(notificationRef);
        const data = current.data() || {};
        if (data.pushStatus === "sent" || data.pushStatus === "no_token") {
          return false;
        }
        if (data.pushStatus === "sending" &&
            data.pushLeaseUntil?.toMillis() > now) {
          return false;
        }
        transaction.update(notificationRef, {
          pushStatus: "sending",
          pushLeaseUntil: new Date(now + leaseDurationMs),
        });
        return true;
      });
      if (!claimed) return;

      const tokens = new Set();
      const sourceProfiles = [];
      if (typeof notification.recipientFcmToken === "string" &&
          notification.recipientFcmToken.trim()) {
        tokens.add(notification.recipientFcmToken.trim());
      }

      const recipientUid = notification.recipientUid?.toString().trim();
      const recipientNames = notification.recipientName
          ?.toString()
          .split(",")
          .map((name) => name.trim())
          .filter(Boolean) || [];
      let profileQuery;
      if (recipientUid) {
        const usersByUid = await db.collection("users")
            .where("uid", "==", recipientUid)
            .get();
        profileQuery = {
          docs: usersByUid.docs,
        };
      } else if (recipientNames.length > 0) {
        const profilesByName = await Promise.all(recipientNames.map(
            async (name) => Promise.all([
              db.collection("users").where("name", "==", name).get(),
              db.collection("users").where("fullName", "==", name).get(),
              db.collection("users").where("email", "==", name).get(),
              db.collection("cps").where("cpName", "==", name).get(),
            ]),
        ));
        profileQuery = {
          docs: profilesByName.flatMap((snapshots) =>
            snapshots.flatMap((snapshot) => snapshot.docs),
          ),
        };
      }

      for (const profile of profileQuery?.docs || []) {
        sourceProfiles.push(profile);
        const data = profile.data();
        if (typeof data.fcmToken === "string" && data.fcmToken.trim()) {
          tokens.add(data.fcmToken.trim());
        }
        for (const token of data.fcmTokens || []) {
          if (typeof token === "string" && token.trim()) {
            tokens.add(token.trim());
          }
        }
      }

      const tokenList = [...tokens];
      if (tokenList.length === 0) {
        await notificationRef.update({
          pushStatus: "no_token",
          pushLeaseUntil: FieldValue.delete(),
          pushError: "No registered FCM token found for recipient.",
        });
        logger.warn("No FCM token found", {notificationId: event.params.notificationId});
        return;
      }

      try {
        const result = await getMessaging().sendEachForMulticast({
          tokens: tokenList,
          notification: {
            title: notification.title?.toString() || "Task Manager",
            body: notification.body?.toString() || "",
          },
          data: {
            notificationId: event.params.notificationId,
            type: notification.type?.toString() || "task_notification",
          },
          android: {
            priority: "high",
            notification: {channelId: "task_notifications"},
          },
          apns: {
            payload: {aps: {sound: "default"}},
          },
        });

        const invalidTokens = [];
        result.responses.forEach((response, index) => {
          if (!response.success &&
              ["messaging/invalid-registration-token",
                "messaging/registration-token-not-registered"].includes(
                  response.error?.code)) {
            invalidTokens.push(tokenList[index]);
          }
        });

        if (invalidTokens.length > 0) {
          const batch = db.batch();
          for (const profile of sourceProfiles) {
            const data = profile.data();
            const patch = {
              fcmTokens: FieldValue.arrayRemove(...invalidTokens),
            };
            if (invalidTokens.includes(data.fcmToken)) {
              patch.fcmToken = FieldValue.delete();
            }
            batch.set(profile.ref, patch, {merge: true});
          }
          await batch.commit();
        }

        if (result.failureCount > 0 && result.successCount === 0) {
          throw new Error("FCM rejected all recipient device tokens.");
        }

        await notificationRef.update({
          pushStatus: "sent",
          pushSuccessCount: result.successCount,
          pushFailureCount: result.failureCount,
          pushSentAt: FieldValue.serverTimestamp(),
          pushLeaseUntil: FieldValue.delete(),
          pushError: FieldValue.delete(),
        });
      } catch (error) {
        await notificationRef.update({
          pushStatus: "failed",
          pushLeaseUntil: FieldValue.delete(),
          pushError: error.message || String(error),
        });
        logger.error("Unable to deliver task notification", {
          notificationId: event.params.notificationId,
          error,
        });
        throw error;
      }
    },
);
