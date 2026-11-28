const {initializeApp} = require("firebase-admin/app");
const {createHash} = require("node:crypto");
const {FieldValue, getFirestore} = require("firebase-admin/firestore");
const {getAuth} = require("firebase-admin/auth");
const {setGlobalOptions} = require("firebase-functions/v2");
const {getMessaging} = require("firebase-admin/messaging");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {
  onDocumentCreated,
  onDocumentWritten,
} = require("firebase-functions/v2/firestore");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {logger} = require("firebase-functions");

setGlobalOptions({region: "asia-south1"});

initializeApp();

const db = getFirestore();

exports.updateStaffProfile = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in to manage staff.");
  }

  const callerSnapshot = await db.collection("users")
      .doc(request.auth.uid)
      .get();
  const callerRole = callerSnapshot.data()?.role;
  if (!["admin", "superAdmin"].includes(callerRole)) {
    throw new HttpsError("permission-denied", "You cannot manage staff.");
  }

  const {uid, name, contactNo, email, role} = request.data || {};
  const normalizedEmail = typeof email === "string" ? email.trim().toLowerCase() : "";
  const normalizedName = typeof name === "string" ? name.trim() : "";
  const normalizedContact = typeof contactNo === "string" ? contactNo.trim() : "";
  const allowedRoles = ["admin", "superAdmin", "user"];
  if (typeof uid !== "string" || !uid.trim() ||
      !normalizedName || !normalizedContact ||
      !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(normalizedEmail) ||
      !allowedRoles.includes(role)) {
    throw new HttpsError("invalid-argument", "Staff details are invalid.");
  }

  let staffRef = db.collection("users").doc(uid);
  let staffSnapshot = await staffRef.get();
  if (!staffSnapshot.exists) {
    const profileQuery = await db.collection("users")
        .where("uid", "==", uid)
        .limit(1)
        .get();
    if (!profileQuery.empty) {
      staffRef = profileQuery.docs[0].ref;
      staffSnapshot = profileQuery.docs[0];
    }
  }
  if (!staffSnapshot.exists) {
    throw new HttpsError("not-found", "Staff profile was not found.");
  }
  const currentProfile = staffSnapshot.data();
  if (callerRole === "admin" &&
      ((currentProfile.role === "superAdmin" &&
        role !== currentProfile.role) ||
       (role === "superAdmin" && currentProfile.role !== "superAdmin"))) {
    throw new HttpsError(
        "permission-denied",
        "Only a Super Admin can assign the Super Admin role.",
    );
  }

  const auth = getAuth();
  let previousAuthUser;
  try {
    previousAuthUser = await auth.getUser(uid);
    await auth.updateUser(uid, {
      displayName: normalizedName,
      email: normalizedEmail,
      emailVerified: normalizedEmail === previousAuthUser.email ?
        previousAuthUser.emailVerified : false,
    });
  } catch (error) {
    if (error.code === "auth/email-already-exists") {
      throw new HttpsError("already-exists", "This email is already in use.");
    }
    if (error.code === "auth/invalid-email") {
      throw new HttpsError("invalid-argument", "Enter a valid email address.");
    }
    logger.error("Could not update staff authentication account", {
      uid,
      error,
    });
    throw new HttpsError("internal", "Could not update the staff account.");
  }

  try {
    await staffRef.update({
      name: normalizedName,
      contactNo: normalizedContact,
      email: normalizedEmail,
      role,
    });
  } catch (error) {
    try {
      await auth.updateUser(uid, {
        displayName: previousAuthUser.displayName,
        email: previousAuthUser.email,
        emailVerified: previousAuthUser.emailVerified,
      });
    } catch (rollbackError) {
      logger.error("Could not roll back staff authentication update", {
        uid,
        error: rollbackError,
      });
    }
    logger.error("Could not update staff profile", {uid, error});
    throw new HttpsError("internal", "Could not save staff details.");
  }

  return {success: true};
});

function parseTaskDate(timestampValue, stringValue) {
  if (timestampValue && typeof timestampValue.toDate === "function") {
    const date = timestampValue.toDate();
    if (!Number.isNaN(date.getTime())) return date;
  }
  if (timestampValue instanceof Date) {
    if (!Number.isNaN(timestampValue.getTime())) return timestampValue;
  }
  if (typeof stringValue === "string") {
    const date = new Date(stringValue);
    return Number.isNaN(date.getTime()) ? null : date;
  }
  return null;
}

function taskDate(task, field) {
  return parseTaskDate(task[`${field}At`], task[field]);
}

function dueTaskNotifications(task, now) {
  if (task.isDone === true) return [];
  const due = [];
  const reminderAt = taskDate(task, "reminder");
  if (!task.reminderSent && reminderAt && reminderAt <= now) {
    due.push({
      type: "task_reminder",
      sentField: "reminderSent",
      scheduledAt: reminderAt,
      title: "Task reminder",
      body: `Reminder for task: "${task.title || ""}"`,
    });
  }

  const deadlineAt = taskDate(task, "deadline");
  const deadlineDistance = deadlineAt ? deadlineAt.getTime() - now.getTime() : 0;
  if (!task.deadlineReminderSent &&
      deadlineAt &&
      deadlineDistance > 0 &&
      deadlineDistance <= 3 * 60 * 60 * 1000) {
    due.push({
      type: "task_deadline",
      sentField: "deadlineReminderSent",
      scheduledAt: deadlineAt,
      title: "Deadline approaching",
      body: `Your task "${task.title || ""}" is due within 3 hours.`,
    });
  }
  return due;
}

async function taskNotificationRecipients(task) {
  const rawNames = Array.isArray(task.assigneeNames) &&
      task.assigneeNames.length > 0 ?
    task.assigneeNames :
    (task.assignee || "").toString().split(",");
  const names = [...new Set(rawNames
      .map((name) => name?.toString().trim())
      .filter(Boolean))];
  const uids = new Set((Array.isArray(task.assigneeUids) ?
    task.assigneeUids : []
  ).map((uid) => uid?.toString().trim()).filter(Boolean));
  if (names.length === 0 && task.assigneeUid) {
    uids.add(task.assigneeUid.toString().trim());
  }
  if (names.length === 0 && uids.size === 0 && task.createdBy?.uid) {
    uids.add(task.createdBy.uid.toString().trim());
  }

  const profiles = new Map();
  const addProfile = (profile) => {
    if (profile.exists) profiles.set(profile.ref.path, profile);
  };
  let incomplete = false;
  for (const uid of uids) {
    let profile;
    if (!uid.includes("/")) {
      profile = await db.collection("users").doc(uid).get();
    }
    if (!profile?.exists) {
      const matches = await db.collection("users")
          .where("uid", "==", uid)
          .limit(1)
          .get();
      profile = matches.docs[0];
    }
    if (!profile?.exists) {
      incomplete = true;
      continue;
    }
    addProfile(profile);
  }
  for (const name of names) {
    let profile;
    for (const field of ["name", "fullName", "email"]) {
      const matches = await db.collection("users")
          .where(field, "==", name)
          .limit(1)
          .get();
      if (!matches.empty) {
        profile = matches.docs[0];
        break;
      }
    }
    if (!profile?.exists) {
      const matches = await db.collection("cps")
          .where("cpName", "==", name)
          .limit(1)
          .get();
      profile = matches.docs[0];
    }
    if (!profile?.exists) {
      incomplete = true;
      continue;
    }
    addProfile(profile);
  }

  const recipients = new Map();
  for (const profile of profiles.values()) {
    const data = profile.data();
    const tokens = new Set();
    if (typeof data.fcmToken === "string" && data.fcmToken.trim()) {
      tokens.add(data.fcmToken.trim());
    }
    if (Array.isArray(data.fcmTokens)) {
      for (const token of data.fcmTokens) {
        if (typeof token === "string" && token.trim()) tokens.add(token.trim());
      }
    }
    if (tokens.size === 0) {
      incomplete = true;
      continue;
    }
    const uid = data.uid?.toString().trim() ||
      (profile.ref.parent.id === "users" ? profile.id : "");
    const key = uid || profile.ref.path;
    const recipient = recipients.get(key) || {
      uid,
      name: data.name?.toString().trim() ||
        data.fullName?.toString().trim() ||
        data.cpName?.toString().trim() ||
        names.find((name) => name.toLowerCase() ===
          (data.email || "").toString().trim().toLowerCase()) ||
        "",
      tokens: new Set(),
    };
    for (const token of tokens) recipient.tokens.add(token);
    recipients.set(key, recipient);
  }

  return {
    recipients: [...recipients.values()],
    complete: !incomplete && recipients.size > 0,
  };
}

function taskAssigneeSignature(task) {
  return JSON.stringify([
    task.assignee,
    task.assigneeNames,
    task.assigneeUid,
    task.assigneeUids,
    task.createdBy?.uid,
  ]);
}

function taskNotificationId(taskId, notification, recipient) {
  const recipientKey = recipient.uid || recipient.name || "assignee";
  const recipientHash = createHash("sha256")
      .update(recipientKey)
      .digest("hex")
      .slice(0, 16);
  return `${taskId}_${notification.type}_${notification.scheduledAt.getTime()}_${recipientHash}`;
}

async function queueTaskNotification(
    taskSnapshot,
    originalTask,
    notification,
    recipients,
) {
  const taskRef = taskSnapshot.ref;
  const notificationRefs = recipients.map((recipient) =>
    db.collection("notifications").doc(
        taskNotificationId(taskSnapshot.id, notification, recipient),
    ),
  );
  return db.runTransaction(async (transaction) => {
    const currentSnapshot = await transaction.get(taskRef);
    if (!currentSnapshot.exists) return false;
    const currentTask = currentSnapshot.data();
    if (currentTask[notification.sentField] === true ||
        taskAssigneeSignature(currentTask) !==
          taskAssigneeSignature(originalTask)) {
      return false;
    }
    const currentDueNotification = dueTaskNotifications(
        currentTask,
        new Date(),
    ).find((item) =>
      item.sentField === notification.sentField &&
      item.scheduledAt.getTime() === notification.scheduledAt.getTime(),
    );
    if (!currentDueNotification) return false;

    const existingNotifications = await Promise.all(
        notificationRefs.map((ref) => transaction.get(ref)),
    );
    for (let index = 0; index < recipients.length; index++) {
      if (existingNotifications[index].exists) continue;
      const recipient = recipients[index];
      transaction.create(notificationRefs[index], {
        recipientName: recipient.name,
        recipientUid: recipient.uid || null,
        recipientFcmToken: [...recipient.tokens][0],
        title: notification.title,
        body: notification.body,
        timestamp: FieldValue.serverTimestamp(),
        isRead: false,
        type: notification.type,
        taskId: taskSnapshot.id,
      });
    }
    transaction.update(taskRef, {[notification.sentField]: true});
    return true;
  });
}

exports.dispatchScheduledTaskNotifications = onSchedule(
    {
      schedule: "every 1 minutes",
      timeZone: "UTC",
      maxInstances: 1,
      concurrency: 1,
      timeoutSeconds: 120,
    },
    async () => {
      const snapshot = await db.collection("map").get();
      const now = new Date();
      for (const taskSnapshot of snapshot.docs) {
        const task = taskSnapshot.data();
        const dueNotifications = dueTaskNotifications(task, now);
        if (dueNotifications.length === 0) continue;

        try {
          const {recipients, complete} =
            await taskNotificationRecipients(task);
          if (!complete) {
            logger.warn("Task reminder recipients have no complete token set", {
              taskId: taskSnapshot.id,
              types: dueNotifications.map((item) => item.type),
            });
            continue;
          }
          for (const notification of dueNotifications) {
            const queued = await queueTaskNotification(
                taskSnapshot,
                task,
                notification,
                recipients,
            );
            if (queued) {
              logger.info("Queued scheduled task notification", {
                taskId: taskSnapshot.id,
                type: notification.type,
                recipientCount: recipients.length,
              });
            }
          }
        } catch (error) {
          logger.error("Failed to queue scheduled task notification", {
            taskId: taskSnapshot.id,
            error,
          });
        }
      }
    },
);

exports.onNotificationCreated = onDocumentCreated(
    {
      document: "notifications/{notificationId}",
    },
    async (event) => {
      const snapshot = event.data;
      if (!snapshot) return;
      const data = snapshot.data();
      if (![
        "task_assigned",
        "task_reminder",
        "task_deadline",
      ].includes(data.type)) {
        return;
      }

      const tokens = new Set();
      const addToken = (token) => {
        if (typeof token === "string" && token.trim()) {
          tokens.add(token.trim());
        }
      };
      addToken(data.recipientFcmToken);

      const recipientUid = data.recipientUid?.toString().trim();
      if (recipientUid) {
        const [profile, profilesByUid] = await Promise.all([
          db.collection("users").doc(recipientUid).get(),
          db.collection("users").where("uid", "==", recipientUid).get(),
        ]);
        const profiles = new Map();
        if (profile.exists) profiles.set(profile.ref.path, profile);
        for (const match of profilesByUid.docs) {
          profiles.set(match.ref.path, match);
        }
        for (const userProfile of profiles.values()) {
          const userData = userProfile.data();
          addToken(userData.fcmToken);
          for (const token of userData.fcmTokens || []) {
            addToken(token);
          }
        }
      }

      const tokenList = [...tokens];
      if (tokenList.length === 0) {
        await snapshot.ref.update({
          pushStatus: "no_token",
          pushError: "No FCM token found for the task assignee.",
        });
        logger.warn("No FCM token found for task assignment", {
          notificationId: event.params.notificationId,
          recipientUid: recipientUid || null,
        });
        return;
      }

      try {
        const result = await getMessaging().sendEachForMulticast({
          tokens: tokenList,
          notification: {
            title: data.title?.toString() || "Task Manager",
            body: data.body?.toString() || "",
          },
          data: {
            notificationId: event.params.notificationId,
            type: data.type,
          },
          android: {
            priority: "high",
            notification: {channelId: "task_notifications"},
          },
          apns: {
            payload: {aps: {sound: "default"}},
          },
        });

        const failures = result.responses
            .map((response, index) => {
              if (response.success) return null;
              return {
                tokenIndex: index,
                code: response.error?.code || "messaging/unknown-error",
                message: response.error?.message || "Unknown FCM error",
              };
            })
            .filter(Boolean);
        const failureDetails = failures
            .map((failure) => `${failure.code}: ${failure.message}`)
            .join("; ");
        await snapshot.ref.update({
          pushStatus: result.successCount > 0 ? "sent" : "failed",
          pushSuccessCount: result.successCount,
          pushFailureCount: result.failureCount,
          pushSentAt: FieldValue.serverTimestamp(),
          pushError: failureDetails || FieldValue.delete(),
        });
        if (result.successCount === 0) {
          logger.error("FCM rejected all task-assignment tokens", {
            notificationId: event.params.notificationId,
            failures,
          });
          return;
        }
        logger.info("Task notification push sent", {
          notificationId: event.params.notificationId,
          successCount: result.successCount,
          failureCount: result.failureCount,
          failures,
        });
      } catch (error) {
        await snapshot.ref.update({
          pushStatus: "failed",
          pushError: String(error.code || error.message),
        });
        logger.error("Could not send task notification push", {
          notificationId: event.params.notificationId,
          error,
        });
        throw error;
      }
    },
);

exports.dispatchScheduledFlashMessages = onSchedule(
    {
      schedule: "every 1 minutes",
      timeZone: "UTC",
      maxInstances: 1,
      concurrency: 1,
      timeoutSeconds: 120,
    },
    async () => {
      const now = new Date();
      const snapshot = await db.collection("flashMessages")
          .where("status", "==", "scheduled")
          .get();

      for (const scheduledMessage of snapshot.docs) {
        const scheduledAt = scheduledMessage.data().sendAt?.toDate?.();
        if (!(scheduledAt instanceof Date)) {
          logger.warn("Scheduled Flash has no valid sendAt timestamp", {
            flashId: scheduledMessage.id,
          });
          continue;
        }
        if (scheduledAt > now) continue;

        try {
          await db.runTransaction(async (transaction) => {
            const currentSnapshot =
              await transaction.get(scheduledMessage.ref);
            if (!currentSnapshot.exists) return;
            const current = currentSnapshot.data();
            const currentSendAt = current.sendAt?.toDate?.();
            if (current.status !== "scheduled" ||
                !(currentSendAt instanceof Date) ||
                currentSendAt > now) {
              return;
            }
            transaction.update(scheduledMessage.ref, {
              status: "delivered",
            });
          });
        } catch (error) {
          logger.error("Could not dispatch scheduled Flash message", {
            flashId: scheduledMessage.id,
            error,
          });
        }
      }
    },
);

exports.onFlashMessageDelivered = onDocumentWritten(
    {
      document: "flashMessages/{flashId}",
    },
    async (event) => {
      const after = event.data?.after;
      if (!after?.exists) return;
      const before = event.data.before?.data();
      const flash = after.data();
      if (flash.status !== "delivered" || before?.status === "delivered") {
        return;
      }

      const claim = await db.runTransaction(async (transaction) => {
        const currentSnapshot = await transaction.get(after.ref);
        if (!currentSnapshot.exists) return false;
        const current = currentSnapshot.data();
        if (current.status !== "delivered" || current.pushStatus === "sent") {
          return false;
        }
        const leaseUntil = current.pushLeaseUntil?.toMillis?.() || 0;
        if (current.pushStatus === "sending" && leaseUntil > Date.now()) {
          return false;
        }
        transaction.update(after.ref, {
          pushStatus: "sending",
          pushLeaseUntil: new Date(Date.now() + 5 * 60 * 1000),
        });
        return true;
      });
      if (!claim) return;

      const recipientUid = flash.recipientUid?.toString().trim();
      if (!recipientUid) {
        await after.ref.update({
          pushStatus: "no_recipient",
          pushLeaseUntil: FieldValue.delete(),
          pushError: "No recipient UID on the flash message.",
        });
        logger.warn("Flash message has no recipient UID", {
          flashId: event.params.flashId,
        });
        return;
      }

      try {
        const [profile, profilesByUid] = await Promise.all([
          db.collection("users").doc(recipientUid).get(),
          db.collection("users").where("uid", "==", recipientUid).get(),
        ]);
        const profiles = new Map();
        if (profile.exists) profiles.set(profile.ref.path, profile);
        for (const match of profilesByUid.docs) {
          profiles.set(match.ref.path, match);
        }
        const tokens = new Set();
        for (const userProfile of profiles.values()) {
          const userData = userProfile.data();
          if (typeof userData.fcmToken === "string" &&
              userData.fcmToken.trim()) {
            tokens.add(userData.fcmToken.trim());
          }
          if (Array.isArray(userData.fcmTokens)) {
            for (const token of userData.fcmTokens) {
              if (typeof token === "string" && token.trim()) {
                tokens.add(token.trim());
              }
            }
          }
        }

        const tokenList = [...tokens];
        if (tokenList.length === 0) {
          await after.ref.update({
            pushStatus: "no_token",
            pushLeaseUntil: FieldValue.delete(),
            pushError: "No FCM token found for the Flash message recipient.",
          });
          logger.warn("No FCM token found for Flash message recipient", {
            flashId: event.params.flashId,
            recipientUid,
          });
          return;
        }

        const title = `⚡ ${flash.senderName?.toString() || "Staff"}`;
        const body = flash.text?.toString() || "";
        const data = {
          type: "flash",
          flashId: event.params.flashId,
          title,
          body,
        };
        if (typeof flash.taskId === "string" && flash.taskId) {
          data.taskId = flash.taskId;
        }
        const result = await getMessaging().sendEachForMulticast({
          tokens: tokenList,
          data,
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
                alert: {title, body},
                sound: "default",
              },
            },
          },
        });
        const failures = result.responses
            .map((response) => response.success ? null : {
              code: response.error?.code || "messaging/unknown-error",
              message: response.error?.message || "Unknown FCM error",
            })
            .filter(Boolean);
        const failureDetails = failures
            .map((failure) => `${failure.code}: ${failure.message}`)
            .join("; ");
        await after.ref.update({
          pushStatus: result.successCount > 0 ? "sent" : "failed",
          pushSuccessCount: result.successCount,
          pushFailureCount: result.failureCount,
          pushSentAt: FieldValue.serverTimestamp(),
          pushLeaseUntil: FieldValue.delete(),
          pushError: failureDetails || FieldValue.delete(),
        });
        if (result.successCount === 0) {
          throw new Error(failureDetails || "FCM rejected all Flash tokens.");
        }
        logger.info("Flash message push sent", {
          flashId: event.params.flashId,
          recipientUid,
          successCount: result.successCount,
          failureCount: result.failureCount,
        });
      } catch (error) {
        await after.ref.update({
          pushStatus: "failed",
          pushLeaseUntil: FieldValue.delete(),
          pushError: String(error.code || error.message),
        });
        logger.error("Could not send Flash message push", {
          flashId: event.params.flashId,
          recipientUid,
          error,
        });
        throw error;
      }
    },
);

exports.onFlashMessageResponded = onDocumentWritten(
    {
      document: "flashMessages/{flashId}",
    },
    async (event) => {
      const before = event.data?.before?.data();
      const after = event.data?.after;
      if (!after?.exists) return;
      const flash = after.data();
      const response = flash.response?.toString().trim();
      if (!response || flash.status !== "seen") return;
      if (before?.response === flash.response &&
          before?.responseText === flash.responseText) {
        return;
      }

      const claimed = await db.runTransaction(async (transaction) => {
        const currentSnapshot = await transaction.get(after.ref);
        if (!currentSnapshot.exists) return false;
        const current = currentSnapshot.data();
        if (current.status !== "seen" ||
            current.response !== flash.response ||
            current.responseText !== flash.responseText ||
            current.responsePushStatus === "sent" ||
            current.responsePushStatus === "no_sender" ||
            current.responsePushStatus === "no_token") {
          return false;
        }
        const leaseUntil =
          current.responsePushLeaseUntil?.toMillis?.() || 0;
        if (current.responsePushStatus === "sending" &&
            leaseUntil > Date.now()) {
          return false;
        }
        transaction.update(after.ref, {
          responsePushStatus: "sending",
          responsePushLeaseUntil: new Date(Date.now() + 5 * 60 * 1000),
        });
        return true;
      });
      if (!claimed) return;

      const senderUid = flash.senderUid?.toString().trim();
      if (!senderUid) {
        await after.ref.update({
          responsePushStatus: "no_sender",
          responsePushLeaseUntil: FieldValue.delete(),
          responsePushError: "No sender UID on the Flash message.",
        });
        logger.warn("Flash response has no sender UID", {
          flashId: event.params.flashId,
        });
        return;
      }

      try {
        const [profile, profilesByUid] = await Promise.all([
          db.collection("users").doc(senderUid).get(),
          db.collection("users").where("uid", "==", senderUid).get(),
        ]);
        const profiles = new Map();
        if (profile.exists) profiles.set(profile.ref.path, profile);
        for (const match of profilesByUid.docs) {
          profiles.set(match.ref.path, match);
        }
        const tokens = new Set();
        for (const userProfile of profiles.values()) {
          const userData = userProfile.data();
          if (typeof userData.fcmToken === "string" &&
              userData.fcmToken.trim()) {
            tokens.add(userData.fcmToken.trim());
          }
          if (Array.isArray(userData.fcmTokens)) {
            for (const token of userData.fcmTokens) {
              if (typeof token === "string" && token.trim()) {
                tokens.add(token.trim());
              }
            }
          }
        }

        const tokenList = [...tokens];
        if (tokenList.length === 0) {
          await after.ref.update({
            responsePushStatus: "no_token",
            responsePushLeaseUntil: FieldValue.delete(),
            responsePushError: "No FCM token found for the Flash sender.",
          });
          logger.warn("No FCM token found for Flash response sender", {
            flashId: event.params.flashId,
            senderUid,
          });
          return;
        }

        const responderName = flash.recipientName?.toString().trim() ||
          "A staff member";
        const answer = response === "Others" ?
          flash.responseText?.toString().trim() || "Others" :
          response;
        const title = "⚡ Flash message reply";
        const body = `${responderName} replied: ${answer}`;
        const result = await getMessaging().sendEachForMulticast({
          tokens: tokenList,
          notification: {title, body},
          data: {
            type: "flash_response",
            flashId: event.params.flashId,
            response,
            responseText: flash.responseText?.toString() || "",
          },
          android: {
            priority: "high",
            notification: {channelId: "task_notifications"},
          },
          apns: {
            headers: {
              "apns-priority": "10",
              "apns-push-type": "alert",
            },
            payload: {
              aps: {
                alert: {title, body},
                sound: "default",
              },
            },
          },
        });
        const failures = result.responses
            .map((item) => item.success ? null : {
              code: item.error?.code || "messaging/unknown-error",
              message: item.error?.message || "Unknown error",
            })
            .filter(Boolean);
        const failureDetails = failures
            .map((failure) => `${failure.code}: ${failure.message}`)
            .join("; ");
        await after.ref.update({
          responsePushStatus: result.successCount > 0 ? "sent" : "failed",
          responsePushSuccessCount: result.successCount,
          responsePushFailureCount: result.failureCount,
          responsePushSentAt: FieldValue.serverTimestamp(),
          responsePushLeaseUntil: FieldValue.delete(),
          responsePushError: failureDetails || FieldValue.delete(),
        });
        if (result.successCount === 0) {
          throw new Error(failureDetails || "FCM rejected all sender tokens.");
        }
        logger.info("Flash response push sent", {
          flashId: event.params.flashId,
          senderUid,
          successCount: result.successCount,
          failureCount: result.failureCount,
        });
      } catch (error) {
        await after.ref.update({
          responsePushStatus: "failed",
          responsePushLeaseUntil: FieldValue.delete(),
          responsePushError: String(error.code || error.message),
        });
        logger.error("Could not send Flash response push", {
          flashId: event.params.flashId,
          senderUid,
          error,
        });
        throw error;
      }
    },
);