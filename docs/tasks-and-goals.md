# Tasks and weekly goals

This guide covers the task workspace for app users and developers.

## For app users

The home workspace groups work into tabs such as **Days**, **Goals**, **My
Work**, **Done Work**, **Assign**, and **Overdue**. Users with admin access may
also see **All Work** and a configurable **Group by** tab.

Create a task with a title, then add details as needed:

- Priority, work type, reminder, deadline, and weekly goal.
- Assignee, monitor, client, project, and folder.
- Notes, steps, files, and task-specific notifications.

Open a task to edit its details. Mark tasks done from the task list; the app may
ask for confirmation. Use the workspace controls to search, sort, group, change
the view, or select multiple tasks for deletion. **My Work** and other tabs show
work relevant to the signed-in user and their access level.

Tasks assigned to you appear in **My Work** under their priority. If you are
listed as a task's monitor, it appears under **Free Works**; monitoring is
separate from task priority. Tasks you created and assigned to someone else
also appear in your **Assign** tab.

Weekly goals can be viewed and managed from **Goals**. Assign a goal a week,
title, and target; task progress can then be reviewed alongside the goal.

## For developers

- The task model is [`Task`](../lib/features/map_screen/models/task.dart).
  It serializes task fields, steps, files, and task notification settings.
- [`TaskRepository`](../lib/features/map_screen/repositories/task_repository.dart)
  persists tasks in the Firestore `map` collection and watches for updates.
  Query scope depends on the signed-in user's access and assignment.
- [`MapScreenViewModel`](../lib/features/map_screen/viewmodels/map_screen_viewmodel.dart)
  owns task loading, filtering, selection, and list presentation state.
- Weekly goals use a separate repository and
  [`WeeklyGoalsViewModel`](../lib/features/map_screen/viewmodels/weekly_goals_viewmodel.dart).
- Task creation and task details are implemented in
  [`add_task_bottom_sheet.dart`](../lib/features/map_screen/screens/views/add_task_bottom_sheet.dart)
  and [`task_detail_page.dart`](../lib/features/map_screen/screens/task_detail_page.dart).

Keep Firestore serialization compatible with existing task documents when
adding or renaming fields. Update the model and relevant tests together.

Related: [developer guide](developer-guide.md),
[notifications and flash messages](notifications-and-flash-messages.md).
