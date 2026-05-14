import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/bitrix_task_model.dart';
import '../../../data/services/bitrix_task_service.dart';
import '../../providers/auth_provider.dart';

class TaskSelectionScreen extends StatefulWidget {
  const TaskSelectionScreen({super.key});

  @override
  State<TaskSelectionScreen> createState() => _TaskSelectionScreenState();
}

class _TaskSelectionScreenState extends State<TaskSelectionScreen> {
  List<BitrixTaskModel> _tasks = [];
  bool _loading = true;
  String? _error;
  String _search = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = context.read<BitrixTaskService>();
      final tasks = await service.getLastTasks();
      setState(() => _tasks = tasks);
    } catch (e) {
      setState(() => _error = 'Error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _select(BitrixTaskModel task) {
    final auth = context.read<AuthProvider>();
    auth.setTask(task.id, task.title);
    Navigator.of(context).pop();
  }

  void _clear() {
    final auth = context.read<AuthProvider>();
    auth.setTask(null, null);
    Navigator.of(context).pop();
  }

  List<BitrixTaskModel> get _filtered {
    if (_search.isEmpty) return _tasks;
    final q = _search.toLowerCase();
    return _tasks
        .where((t) =>
            t.title.toLowerCase().contains(q) ||
            t.id.contains(q) ||
            (t.responsible?.toLowerCase().contains(q) ?? false))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final currentTaskId = context.watch<AuthProvider>().taskId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleccionar tarea'),
        actions: [
          if (currentTaskId != null)
            TextButton(
              onPressed: _clear,
              child: Text('Quitar',
                  style: TextStyle(color: colors.error)),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar tarea...',
                prefixIcon: const Icon(Icons.search_rounded),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          if (_loading)
            const Expanded(
                child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline,
                        color: colors.error, size: 40),
                    const SizedBox(height: 8),
                    Text(_error!,
                        style: TextStyle(color: colors.error)),
                    const SizedBox(height: 16),
                    FilledButton.tonal(
                      onPressed: _load,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            )
          else if (_filtered.isEmpty)
            const Expanded(
              child: Center(child: Text('No hay tareas disponibles')),
            )
          else
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                itemCount: _filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final task = _filtered[i];
                  final isSelected = task.id == currentTaskId;
                  return _TaskCard(
                    task: task,
                    isSelected: isSelected,
                    onTap: () => _select(task),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final BitrixTaskModel task;
  final bool isSelected;
  final VoidCallback onTap;

  const _TaskCard({
    required this.task,
    required this.isSelected,
    required this.onTap,
  });

  Color _statusColor(BuildContext context, String status) {
    final colors = Theme.of(context).colorScheme;
    switch (status) {
      case '2':
        return colors.primary;
      case '3':
        return const Color(0xFF059669);
      case '4':
        return const Color(0xFFD97706);
      case '5':
        return colors.error;
      default:
        return colors.outline;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case '2':
        return 'En progreso';
      case '3':
        return 'Completada';
      case '4':
        return 'Pendiente';
      case '5':
        return 'Diferida';
      default:
        return 'Estado $status';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final statusColor = _statusColor(context, task.status);

    return Card(
      elevation: isSelected ? 2 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(color: colors.primary, width: 2)
            : BorderSide.none,
      ),
      color: isSelected ? colors.primaryContainer.withOpacity(0.3) : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _statusLabel(task.status),
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: statusColor),
                          ),
                        ),
                        if (task.responsible != null) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              task.responsible!,
                              style: TextStyle(
                                  fontSize: 12, color: colors.outline),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (task.deadline != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.schedule_rounded,
                              size: 13, color: colors.outline),
                          const SizedBox(width: 4),
                          Text(
                            '${task.deadline!.day.toString().padLeft(2, '0')}/${task.deadline!.month.toString().padLeft(2, '0')}/${task.deadline!.year}',
                            style: TextStyle(
                                fontSize: 12, color: colors.outline),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (isSelected)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(Icons.check_circle_rounded,
                      color: colors.primary, size: 22),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
