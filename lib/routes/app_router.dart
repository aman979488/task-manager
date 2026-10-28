import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../features/auth/login_page.dart';
import '../features/map_screen/models/task.dart';
import '../features/map_screen/screens/map_screen.dart';
import '../features/map_screen/screens/task_detail_page.dart';
import '../features/map_screen/screens/assignee_tasks_view.dart';
import '../features/map_screen/viewmodels/map_screen_viewmodel.dart';
import '../features/map_screen/viewmodels/add_task_viewmodel.dart';
import '../viewmodels/auth_viewmodel.dart';
import 'app_routes.dart';

class AppRouter {
  static final rootNavigatorKey = GlobalKey<NavigatorState>();

  static GoRouter create(AuthViewModel auth) => GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.home,
    refreshListenable: auth,
    redirect: (context, state) {
      final location = state.matchedLocation;
      if (!auth.ready) {
        return location == AppRoutes.splash ? null : AppRoutes.splash;
      }
      if (!auth.loggedIn) {
        return location == AppRoutes.login ? null : AppRoutes.login;
      }
      if (location == AppRoutes.login || location == AppRoutes.splash) {
        return AppRoutes.home;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, _) =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginPage()),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => MultiProvider(
          providers: [
            ChangeNotifierProvider<MapScreenViewModel>(
              create: (_) => MapScreenViewModel(),
            ),
            ChangeNotifierProvider<AddTaskViewModel>(
              create: (_) => AddTaskViewModel(),
            ),
          ],
          child: const MapScreen(title: 'Task Manager'),
        ),
      ),
      GoRoute(
        path: AppRoutes.taskDetail,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          final task = extra['task'] as Task;
          final onSave = extra['onSave'] as Future<void> Function();
          return TaskDetailPage(task: task, onChanged: () {}, onSave: onSave);
        },
      ),
      GoRoute(
        path: AppRoutes.assigneeTasks,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          final assigneeName = extra['assigneeName'] as String? ?? '';
          final tasks = extra['tasks'] as List<Task>? ?? [];
          final onOpenTask = extra['onOpenTask'] as void Function(Task);
          final onToggleTaskDone =
              extra['onToggleTaskDone']
                  as Future<void> Function(
                    Task task, {
                    bool confirmCompletion,
                    bool keepInMyDay,
                  })? ??
              (
                Task task, {
                bool confirmCompletion = false,
                bool keepInMyDay = false,
              }) async {};
          final onAddSubstep =
              extra['onAddSubstep'] as Future<void> Function(Task)?;
          final onAddTask =
              extra['onAddTask'] as Future<List<Task>> Function()?;
          final taskResultsBuilder =
              extra['taskResultsBuilder'] as Widget Function(List<Task>)?;
          return AssigneeTasksView(
            assigneeName: assigneeName,
            tasks: tasks,
            onOpenTask: onOpenTask,
            onToggleTaskDone: onToggleTaskDone,
            onAddSubstep: onAddSubstep,
            onAddTask: onAddTask,
            taskResultsBuilder: taskResultsBuilder,
          );
        },
      ),
    ],
  );
}
