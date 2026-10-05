import 'package:go_router/go_router.dart';

import '../features/map_screen/models/task.dart';
import '../features/map_screen/screens/map_screen.dart';
import '../features/map_screen/screens/task_detail_page.dart';
import '../features/map_screen/screens/assignee_tasks_view.dart';
import 'app_routes.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const MapScreen(title: 'Task Manager'),
      ),
      GoRoute(
        path: AppRoutes.taskDetail,
        builder: (context, state) {
          final task = state.extra as Task;
          return TaskDetailPage(task: task, onChanged: () {}, onDelete: () {});
        },
      ),
      GoRoute(
        path: AppRoutes.assigneeTasks,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          final assigneeName = extra['assigneeName'] as String? ?? '';
          final tasks = extra['tasks'] as List<Task>? ?? [];
          return AssigneeTasksView(assigneeName: assigneeName, tasks: tasks);
        },
      ),
    ],
  );
}
