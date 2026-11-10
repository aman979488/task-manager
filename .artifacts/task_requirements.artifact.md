# Task Manager - Feature & UI/UX Enhancement Requirements

This document outlines the structured development requirements and feature specifications derived from the recent project update discussion.

---

## 1. Done Work & Time Tracking
- **Date Grouping**: Group items in the **Done Work** tab by Date (similar to date-wise grouping in other sections).
- **Time Badges**: In the Done Work view, replace priority badges with **Start Time** and **End Time**.
- **Metrics Display**: Show total hours worked and the number of days elapsed since the task started.
- **Time Editing**: Add a dedicated quick-edit button/popup to easily modify Start and End times.

---

## 2. Collapsible Sections State Persistence
- **State Retention**: When users expand or collapse sections in **My Work** (or other tab views), the expanded/collapsed state must be preserved across tabs and re-renders (should not reset unexpectedly).

---

## 3. Task Detail & Note Field UI
- **Form Field Styling**: Render the note/description field in task details as an outlined form text field so it is visibly editable at a glance.
- **Line Restrictions**: Restrict text fields/notes to 2–3 visible lines in list views to prevent overflow, while allowing full view in detail mode.
- **Clutter Reduction**: Remove redundant buttons and clean up the UI layout.

---

## 4. Default Priority
- **Default Value**: If no priority is explicitly chosen for a task, the default priority must be **"Free"**.

---

## 5. Tile Interactivity & Clickability
- **Full Row Clickability**: Ensure that clicking anywhere on task list tiles (especially in Overdue, Process, and My Work rows) opens the task details rather than requiring clicks on specific small icons or text.

---

## 6. Monitor Field Integration
- **Positioning**: Add the **"Monitor"** field right before "Free" priority in the metadata bar.
- **User Selection**: Support selecting team members/users for the monitor field (similar to the Assignee selector).
- **Visibility**: Tasks with a monitor assigned should be visible to both the assignee and the designated monitor.

---

## 7. Multi-Assign Capability
- **Batch Assignment**: In the Assign metadata selector, allow multi-selecting/adding multiple team members at once (e.g. with checkboxes or quick add).

---

## 8. Assignee & Completed Tasks Breakdown Views
- **Assign Tab**: Display a list of team members in the Assign tab.
- **Member Task Details**: Tapping a team member opens their assigned tasks view, including a dedicated **"Completed Tasks"** section at the bottom for tasks they have marked as done.
- **Navigation**: Ensure a clear Back button is present in all assignee detail navigation bars.
