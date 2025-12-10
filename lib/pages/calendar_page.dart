import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../models/event.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

enum ViewMode { month, week, day }

class _CalendarPageState extends State<CalendarPage> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  ViewMode _viewMode = ViewMode.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Event>> _events = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  // 获取指定日期的事件列表
  List<Event> _getEventsForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _events[normalizedDay] ?? [];
  }

  // 添加或更新事件
  void _addOrUpdateEvent(Event event) {
    setState(() {
      final normalizedDate = DateTime(
        event.date.year,
        event.date.month,
        event.date.day,
      );

      if (_events[normalizedDate] == null) {
        _events[normalizedDate] = [];
      }

      final existingIndex = _events[normalizedDate]!.indexWhere(
        (e) => e.id == event.id,
      );

      if (existingIndex != -1) {
        _events[normalizedDate]![existingIndex] = event;
      } else {
        _events[normalizedDate]!.add(event);
      }
    });
  }

  // 删除事件
  void _deleteEvent(Event event) {
    setState(() {
      final normalizedDate = DateTime(
        event.date.year,
        event.date.month,
        event.date.day,
      );

      _events[normalizedDate]?.removeWhere((e) => e.id == event.id);
      if (_events[normalizedDate]?.isEmpty ?? false) {
        _events.remove(normalizedDate);
      }
    });
  }

  // 显示添加/编辑事件对话框
  void _showEventDialog({Event? event}) {
    final isEditing = event != null;
    final titleController = TextEditingController(text: event?.title ?? '');
    final descriptionController = TextEditingController(
      text: event?.description ?? '',
    );
    // 固定使用当前选中的日期，不可更改
    final DateTime selectedDate = _selectedDay ?? _focusedDay;

    // 初始化时间
    TimeOfDay startTime = event != null
        ? TimeOfDay.fromDateTime(event.startTime)
        : TimeOfDay.fromDateTime(DateTime.now());
    TimeOfDay endTime = event != null
        ? TimeOfDay.fromDateTime(event.endTime)
        : TimeOfDay.fromDateTime(DateTime.now().add(const Duration(hours: 1)));

    final _formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(isEditing ? '编辑日程' : '添加日程'),
          content: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: '标题',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '标题不能为空';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: '描述',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  // 显示固定日期，不可点击
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Colors.grey),
                        const SizedBox(width: 12),
                        Text(
                          DateFormat('yyyy年MM月dd日').format(selectedDate),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: startTime,
                        initialEntryMode: TimePickerEntryMode.input,
                        builder: (context, child) {
                          return MediaQuery(
                            data: MediaQuery.of(
                              context,
                            ).copyWith(alwaysUse24HourFormat: true),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setState(() {
                          startTime = picked;
                          // 如果结束时间早于开始时间，自动调整
                          final startMinutes =
                              startTime.hour * 60 + startTime.minute;
                          final endMinutes = endTime.hour * 60 + endTime.minute;
                          if (endMinutes <= startMinutes) {
                            endTime = TimeOfDay(
                              hour: (startTime.hour + 1) % 24,
                              minute: startTime.minute,
                            );
                          }
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: '开始时间',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.access_time),
                      ),
                      child: Text(
                        startTime.format(context),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FormField<TimeOfDay>(
                    initialValue: endTime,
                    validator: (value) {
                      if (value == null) return null;

                      final startMinutes =
                          startTime.hour * 60 + startTime.minute;
                      final endMinutes = value.hour * 60 + value.minute;

                      if (endMinutes <= startMinutes) {
                        return '结束时间必须晚于开始时间';
                      }
                      return null;
                    },
                    builder: (FormFieldState<TimeOfDay> field) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            onTap: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: endTime,
                                initialEntryMode: TimePickerEntryMode.input,
                                builder: (context, child) {
                                  return MediaQuery(
                                    data: MediaQuery.of(
                                      context,
                                    ).copyWith(alwaysUse24HourFormat: true),
                                    child: child!,
                                  );
                                },
                              );
                              if (picked != null) {
                                setState(() {
                                  endTime = picked;
                                  field.didChange(picked);
                                });
                              }
                            },
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: '结束时间',
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.access_time),
                                errorText: field.errorText,
                              ),
                              child: Text(
                                endTime.format(context),
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  final startDateTime = DateTime(
                    selectedDate.year,
                    selectedDate.month,
                    selectedDate.day,
                    startTime.hour,
                    startTime.minute,
                  );
                  final endDateTime = DateTime(
                    selectedDate.year,
                    selectedDate.month,
                    selectedDate.day,
                    endTime.hour,
                    endTime.minute,
                  );

                  final newEvent = Event(
                    id:
                        event?.id ??
                        DateTime.now().millisecondsSinceEpoch.toString(),
                    title: titleController.text,
                    startTime: startDateTime,
                    endTime: endDateTime,
                    description: descriptionController.text.isEmpty
                        ? null
                        : descriptionController.text,
                  );
                  this.setState(() {
                    _addOrUpdateEvent(newEvent);
                  });
                  Navigator.pop(context);
                }
              },
              child: Text(isEditing ? '更新' : '添加'),
            ),
          ],
        ),
      ),
    );
  }

  // 显示事件详情对话框
  void _showEventDetails(Event event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(event.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 20),
                const SizedBox(width: 8),
                Text(DateFormat('yyyy年MM月dd日').format(event.startTime)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.access_time, size: 20),
                const SizedBox(width: 8),
                Text(
                  '${DateFormat('HH:mm').format(event.startTime)} - ${DateFormat('HH:mm').format(event.endTime)}',
                ),
              ],
            ),
            if (event.description != null) ...[
              const SizedBox(height: 16),
              Text(event.description!, style: const TextStyle(fontSize: 16)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showEventDialog(event: event);
            },
            child: const Text('编辑'),
          ),
          TextButton(
            onPressed: () {
              _deleteEvent(event);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('日历'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          PopupMenuButton<ViewMode>(
            icon: const Icon(Icons.view_module),
            onSelected: (ViewMode mode) {
              setState(() {
                _viewMode = mode;
                if (mode == ViewMode.month) {
                  _calendarFormat = CalendarFormat.month;
                } else if (mode == ViewMode.week) {
                  _calendarFormat = CalendarFormat.week;
                }
              });
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<ViewMode>>[
              const PopupMenuItem<ViewMode>(
                value: ViewMode.month,
                child: Row(
                  children: [
                    Icon(Icons.calendar_month),
                    SizedBox(width: 8),
                    Text('月视图'),
                  ],
                ),
              ),
              const PopupMenuItem<ViewMode>(
                value: ViewMode.week,
                child: Row(
                  children: [
                    Icon(Icons.calendar_view_week),
                    SizedBox(width: 8),
                    Text('周视图'),
                  ],
                ),
              ),
              const PopupMenuItem<ViewMode>(
                value: ViewMode.day,
                child: Row(
                  children: [
                    Icon(Icons.calendar_today),
                    SizedBox(width: 8),
                    Text('日视图'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_viewMode != ViewMode.day)
            TableCalendar(
              firstDay: DateTime.utc(2000, 1, 1),
              lastDay: DateTime.utc(2050, 12, 31),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              eventLoader: _getEventsForDay,
              startingDayOfWeek: StartingDayOfWeek.monday,
              calendarStyle: const CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: Colors.deepPurple,
                  shape: BoxShape.circle,
                ),
                markerDecoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
              ),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              onFormatChanged: (format) {
                setState(() {
                  _calendarFormat = format;
                });
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
              },
            ),
          if (_viewMode == ViewMode.day) _buildDayViewHeader(),
          const SizedBox(height: 8),
          Expanded(child: _buildEventList()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEventDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildDayViewHeader() {
    final selectedDate = _selectedDay ?? _focusedDay;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() {
                _focusedDay = DateTime(
                  _focusedDay.year,
                  _focusedDay.month,
                  _focusedDay.day - 1,
                );
                _selectedDay = _focusedDay;
              });
            },
          ),
          Column(
            children: [
              Text(
                DateFormat('yyyy年MM月dd日').format(selectedDate),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                DateFormat('EEEE', 'zh_CN').format(selectedDate),
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(() {
                _focusedDay = DateTime(
                  _focusedDay.year,
                  _focusedDay.month,
                  _focusedDay.day + 1,
                );
                _selectedDay = _focusedDay;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEventList() {
    final events = _getEventsForDay(_selectedDay ?? _focusedDay);
    // 按开始时间排序
    events.sort((a, b) => a.startTime.compareTo(b.startTime));

    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '当天没有日程',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: ListTile(
            leading: CircleAvatar(
              child: Text(
                DateFormat('HH:mm').format(event.startTime).substring(0, 2),
              ),
            ),
            title: Text(
              event.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      '${DateFormat('HH:mm').format(event.startTime)} - ${DateFormat('HH:mm').format(event.endTime)}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
                if (event.description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    event.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _showEventDialog(event: event),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('确认删除'),
                        content: Text('确定要删除"${event.title}"吗?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('取消'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              _deleteEvent(event);
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            child: const Text('删除'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
            onTap: () => _showEventDetails(event),
          ),
        );
      },
    );
  }
}
