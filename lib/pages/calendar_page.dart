import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../models/event.dart';
import '../database/event_database.dart';
import '../services/notification_service.dart';
import '../utils/lunar_util.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

enum ViewMode { month, week, day }

class _CalendarPageState extends State<CalendarPage> {
  late EventDatabase _database;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  ViewMode _viewMode = ViewMode.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Event>> _events = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _database = EventDatabase();
    _loadEvents();
  }

  // 从数据库加载事件
  void _loadEvents() async {
    final events = await _database.getAllEvents();
    setState(() {
      _events.clear();
      for (var event in events) {
        final normalizedDate = DateTime(
          event.startTime.year,
          event.startTime.month,
          event.startTime.day,
        );
        if (_events[normalizedDate] == null) {
          _events[normalizedDate] = [];
        }
        _events[normalizedDate]!.add(event);
      }
    });

    // 在 setState 外部重新安排所有通知
    for (var event in events) {
      if (event.reminderMinutes != null && event.reminderMinutes! > 0) {
        final reminderTime = event.startTime.subtract(
          Duration(minutes: event.reminderMinutes!),
        );
        // 只在时间未过期时安排
        if (reminderTime.isAfter(DateTime.now())) {
          await NotificationService().scheduleNotification(
            id: event.id.hashCode,
            title: event.title,
            body: '日程即将开始',
            scheduledDateTime: reminderTime,
          );
        }
      }
    }
  }

  // 获取指定日期的事件列表
  List<Event> _getEventsForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _events[normalizedDay] ?? [];
  }

  // 添加或更新事件
  Future<void> _addOrUpdateEvent(Event event) async {
    // 立即更新 UI（乐观更新）
    setState(() {
      final normalizedDate = DateTime(
        event.startTime.year,
        event.startTime.month,
        event.startTime.day,
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

    // 后台异步保存到数据库和处理通知
    _saveEventInBackground(event);
  }

  // 后台保存事件
  Future<void> _saveEventInBackground(Event event) async {
    try {
      // 保存到数据库
      await _database.insertOrUpdateEvent(event);

      // 先取消旧的通知（如果存在）
      await NotificationService().cancelNotification(event.id.hashCode);

      // 如果设置了新的提醒时间，重新调度通知
      if (event.reminderMinutes != null && event.reminderMinutes! > 0) {
        final reminderTime = event.startTime.subtract(
          Duration(minutes: event.reminderMinutes!),
        );

        // 只在未过期时调度
        if (reminderTime.isAfter(DateTime.now())) {
          await NotificationService().scheduleNotification(
            id: event.id.hashCode,
            title: event.title,
            body: '日程即将开始',
            scheduledDateTime: reminderTime,
          );
        }
      }
    } catch (e) {
      // 如果保存失败，可以选择回滚 UI 或显示错误提示
    }
  }

  // 获取提醒时间的文本描述
  String _getReminderText(int minutes) {
    if (minutes < 60) {
      return '提前 $minutes 分钟提醒';
    } else if (minutes < 1440) {
      final hours = minutes ~/ 60;
      return '提前 $hours 小时提醒';
    } else {
      final days = minutes ~/ 1440;
      return '提前 $days 天提醒';
    }
  }

  // 删除事件
  void _deleteEvent(Event event) {
    // 立即更新 UI
    setState(() {
      final normalizedDate = DateTime(
        event.startTime.year,
        event.startTime.month,
        event.startTime.day,
      );

      _events[normalizedDate]?.removeWhere((e) => e.id == event.id);
      if (_events[normalizedDate]?.isEmpty ?? false) {
        _events.remove(normalizedDate);
      }
    });

    // 后台异步删除
    _deleteEventInBackground(event);
  }

  // 后台删除事件
  Future<void> _deleteEventInBackground(Event event) async {
    try {
      // 从数据库删除
      await _database.deleteEvent(event.id);

      // 取消通知
      NotificationService().cancelNotification(event.id.hashCode);
    } catch (e) {
      // 删除失败
    }
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

    // 初始化提醒时间
    int? reminderMinutes = event?.reminderMinutes;

    // 防止重复提交的标志
    bool isSubmitting = false;

    final _formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false, // 防止点击外部关闭
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
                  const SizedBox(height: 16),
                  // 提醒设置
                  DropdownButtonFormField<int?>(
                    value: reminderMinutes,
                    decoration: const InputDecoration(
                      labelText: '提醒',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.notifications),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('不提醒'),
                      ),
                      const DropdownMenuItem<int>(
                        value: 1,
                        child: Text('事件前1分钟'),
                      ),
                      const DropdownMenuItem<int>(
                        value: 5,
                        child: Text('事件前5分钟'),
                      ),
                      const DropdownMenuItem<int>(
                        value: 10,
                        child: Text('事件前10分钟'),
                      ),
                      const DropdownMenuItem<int>(
                        value: 15,
                        child: Text('事件前15分钟'),
                      ),
                      const DropdownMenuItem<int>(
                        value: 30,
                        child: Text('事件前30分钟'),
                      ),
                      const DropdownMenuItem<int>(
                        value: 60,
                        child: Text('事件前1小时'),
                      ),
                      const DropdownMenuItem<int>(
                        value: 1440,
                        child: Text('事件前1天'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        reminderMinutes = value;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (_formKey.currentState!.validate()) {
                        // 防止重复提交
                        setState(() {
                          isSubmitting = true;
                        });

                        try {
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
                                DateTime.now().millisecondsSinceEpoch
                                    .toString(),
                            title: titleController.text,
                            startTime: startDateTime,
                            endTime: endDateTime,
                            description: descriptionController.text.isEmpty
                                ? null
                                : descriptionController.text,
                            reminderMinutes: reminderMinutes,
                          );

                          // 添加事件
                          await _addOrUpdateEvent(newEvent);

                          // 关闭对话框
                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        } catch (e) {
                          // 如果出错，恢复按钮状态并显示错误
                          setState(() {
                            isSubmitting = false;
                          });
                          if (context.mounted) {
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text('保存失败: $e')));
                          }
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(isEditing ? '更新' : '添加'),
            ),
          ],
        ),
      ),
    );
  }

  // 显示事件详情对话框
  void _showEventDetails(Event event) {
    final lunarInfo = LunarUtil.getDetailedLunarInfo(event.startTime);

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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(DateFormat('yyyy年MM月dd日').format(event.startTime)),
                      Text(
                        lunarInfo['农历'] ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.deepOrange[400],
                        ),
                      ),
                    ],
                  ),
                ),
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
            if (event.reminderMinutes != null &&
                event.reminderMinutes! > 0) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.notifications_active, size: 20),
                  const SizedBox(width: 8),
                  Text(_getReminderText(event.reminderMinutes!)),
                ],
              ),
            ],
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
                markersMaxCount: 0,
              ),
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
              ),
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (context, day, focusedDay) {
                  return _buildCalendarCell(day, false, false);
                },
                todayBuilder: (context, day, focusedDay) {
                  return _buildCalendarCell(day, true, false);
                },
                selectedBuilder: (context, day, focusedDay) {
                  return _buildCalendarCell(day, false, true);
                },
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

  // 构建日历单元格，显示农历信息
  Widget _buildCalendarCell(DateTime day, bool isToday, bool isSelected) {
    final lunarText = LunarUtil.getLunarDisplayText(day);
    final hasEvents = _getEventsForDay(day).isNotEmpty;

    Color? backgroundColor;
    Color? textColor;

    if (isSelected) {
      backgroundColor = Colors.deepPurple;
      textColor = Colors.white;
    } else if (isToday) {
      backgroundColor = Colors.blue;
      textColor = Colors.white;
    }

    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${day.day}',
                  style: TextStyle(
                    color: textColor ?? Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  lunarText,
                  style: TextStyle(
                    color: textColor?.withAlpha(200) ?? Colors.deepOrange[400],
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (hasEvents)
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: textColor ?? Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
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
              const SizedBox(height: 4),
              Text(
                LunarUtil.getFullLunarDate(selectedDate),
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.deepOrange[400],
                  fontWeight: FontWeight.w500,
                ),
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
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              '当天没有日程',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
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
