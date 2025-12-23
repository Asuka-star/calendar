import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../models/event.dart';

/// iCalendar (RFC 5545) 服务类
/// 用于导入、导出和订阅 .ics 格式的日历数据
class ICalendarService {
  // RFC 5545 日期时间格式
  static final DateFormat _dateTimeFormat = DateFormat(
    'yyyyMMdd\'T\'HHmmss\'Z\'',
  );
  static final DateFormat _localDateTimeFormat = DateFormat(
    'yyyyMMdd\'T\'HHmmss',
  );

  /// 将事件列表导出为 iCalendar 格式字符串
  String exportToICS(List<Event> events) {
    final buffer = StringBuffer();

    // iCalendar 头部
    buffer.writeln('BEGIN:VCALENDAR');
    buffer.writeln('VERSION:2.0');
    buffer.writeln('PRODID:-//神人日历//NONSGML v1.0//CN');
    buffer.writeln('CALSCALE:GREGORIAN');
    buffer.writeln('METHOD:PUBLISH');
    buffer.writeln('X-WR-CALNAME:神人日历');
    buffer.writeln('X-WR-TIMEZONE:Asia/Shanghai');
    buffer.writeln('X-WR-CALDESC:神人日历导出的事件');

    // 添加每个事件
    for (var event in events) {
      buffer.writeln('BEGIN:VEVENT');
      buffer.writeln('UID:${event.id}@shenren-calendar');
      buffer.writeln('DTSTAMP:${_formatDateTimeUTC(DateTime.now())}');

      // 使用本地时间格式
      buffer.writeln('DTSTART:${_localDateTimeFormat.format(event.startTime)}');
      buffer.writeln('DTEND:${_localDateTimeFormat.format(event.endTime)}');

      // 添加创建和修改时间
      final now = DateTime.now();
      buffer.writeln('CREATED:${_formatDateTimeUTC(now)}');
      buffer.writeln('LAST-MODIFIED:${_formatDateTimeUTC(now)}');
      buffer.writeln('SEQUENCE:0');

      // 标题和描述（需要行折叠）
      _writeFoldedLine(buffer, 'SUMMARY', _escapeText(event.title));

      if (event.description != null && event.description!.isNotEmpty) {
        _writeFoldedLine(
          buffer,
          'DESCRIPTION',
          _escapeText(event.description!),
        );
      }

      // 状态和透明度
      buffer.writeln('STATUS:CONFIRMED');
      buffer.writeln('TRANSP:OPAQUE');

      // 添加提醒（VALARM）
      if (event.reminderMinutes != null && event.reminderMinutes! > 0) {
        buffer.writeln('BEGIN:VALARM');
        buffer.writeln('ACTION:DISPLAY');
        buffer.writeln('TRIGGER:-PT${event.reminderMinutes}M');
        _writeFoldedLine(buffer, 'DESCRIPTION', _escapeText(event.title));
        buffer.writeln('END:VALARM');
      }

      buffer.writeln('END:VEVENT');
    }

    buffer.writeln('END:VCALENDAR');
    return buffer.toString();
  }

  /// 格式化为 UTC 时间
  String _formatDateTimeUTC(DateTime dateTime) {
    return _dateTimeFormat.format(dateTime.toUtc());
  }

  /// 写入折叠行（RFC 5545 规定每行最多 75 字节）
  void _writeFoldedLine(StringBuffer buffer, String property, String value) {
    final line = '$property:$value';
    if (line.length <= 75) {
      buffer.writeln(line);
    } else {
      // 第一行写入 75 个字符
      buffer.writeln(line.substring(0, 75));
      int pos = 75;
      // 后续行以空格开头，每行最多 74 个字符（因为开头的空格）
      while (pos < line.length) {
        final remaining = line.length - pos;
        final chunkSize = remaining > 74 ? 74 : remaining;
        buffer.writeln(' ${line.substring(pos, pos + chunkSize)}');
        pos += chunkSize;
      }
    }
  }

  /// 从 iCalendar 格式字符串导入事件列表
  List<Event> importFromICS(String icsContent) {
    final events = <Event>[];
    final lines = icsContent
        .split('\n')
        .map((line) => line.replaceAll('\r', ''))
        .toList();

    Map<String, String> currentEventData = {};
    bool inEvent = false;
    String? currentProperty;
    StringBuffer valueBuffer = StringBuffer();

    for (var i = 0; i < lines.length; i++) {
      var line = lines[i];

      if (line.isEmpty) continue;

      // 处理行折叠（以空格或制表符开头的行是续行）
      if (line.startsWith(' ') || line.startsWith('\t')) {
        valueBuffer.write(line.substring(1));
        continue;
      }

      // 保存上一个属性
      if (currentProperty != null && inEvent) {
        currentEventData[currentProperty] = valueBuffer.toString();
      }
      valueBuffer.clear();

      if (line == 'BEGIN:VEVENT') {
        inEvent = true;
        currentEventData = {};
        currentProperty = null;
      } else if (line == 'END:VEVENT') {
        if (inEvent && currentProperty != null) {
          currentEventData[currentProperty] = valueBuffer.toString();
        }
        if (inEvent) {
          final event = _buildEventFromData(currentEventData);
          if (event != null) {
            events.add(event);
          }
        }
        inEvent = false;
        currentProperty = null;
        valueBuffer.clear();
      } else if (inEvent && line.contains(':')) {
        // 解析属性
        final colonIndex = line.indexOf(':');
        final propertyPart = line.substring(0, colonIndex);
        final value = line.substring(colonIndex + 1);

        // 提取属性名（忽略参数，如 DTSTART;TZID=... 中的 TZID）
        final semicolonIndex = propertyPart.indexOf(';');
        currentProperty = semicolonIndex != -1
            ? propertyPart.substring(0, semicolonIndex).toUpperCase()
            : propertyPart.toUpperCase();

        valueBuffer.write(value);
      }
    }

    return events;
  }

  /// 从网络 URL 订阅日历
  Future<List<Event>> subscribeFromURL(String url) async {
    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        // 尝试不同的编码
        String content;
        try {
          content = utf8.decode(response.bodyBytes);
        } catch (e) {
          // 如果 UTF-8 解码失败，尝试 Latin-1
          content = latin1.decode(response.bodyBytes);
        }

        return importFromICS(content);
      } else {
        throw Exception('订阅失败: HTTP ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('订阅失败: $e');
    }
  }

  /// 从数据映射构建事件
  Event? _buildEventFromData(Map<String, String> data) {
    try {
      // UID 处理：移除可能的域名后缀（如 @shenren-calendar）
      String id =
          data['UID']?.trim() ??
          DateTime.now().millisecondsSinceEpoch.toString();
      if (id.contains('@')) {
        id = id.split('@').first;
      }

      final title = _unescapeText(data['SUMMARY'] ?? '');
      final description = data['DESCRIPTION'] != null
          ? _unescapeText(data['DESCRIPTION']!)
          : null;

      final startTime = _parseDateTime(data['DTSTART'] ?? '');
      final endTime = _parseDateTime(data['DTEND'] ?? '');

      if (title.isEmpty || startTime == null || endTime == null) {
        return null;
      }

      return Event(
        id: id,
        title: title,
        startTime: startTime,
        endTime: endTime,
        description: description,
      );
    } catch (e) {
      return null;
    }
  }

  /// 解析 iCalendar 日期时间
  DateTime? _parseDateTime(String value) {
    try {
      // 移除可能的参数（如 TZID=Asia/Shanghai:20231223T100000）
      String cleanValue = value;
      if (value.contains(':')) {
        cleanValue = value.split(':').last;
      }

      // 移除特殊字符，只保留数字
      final dateStr = cleanValue.replaceAll(RegExp(r'[TZ\-:]'), '');

      if (dateStr.length >= 8) {
        final year = int.parse(dateStr.substring(0, 4));
        final month = int.parse(dateStr.substring(4, 6));
        final day = int.parse(dateStr.substring(6, 8));

        if (dateStr.length >= 14) {
          // 包含时间：YYYYMMDDTHHMMSS
          final hour = int.parse(dateStr.substring(8, 10));
          final minute = int.parse(dateStr.substring(10, 12));
          final second = int.parse(dateStr.substring(12, 14));

          // 如果原始值包含 Z，表示 UTC 时间，需要转换为本地时间
          if (cleanValue.endsWith('Z')) {
            return DateTime.utc(
              year,
              month,
              day,
              hour,
              minute,
              second,
            ).toLocal();
          }
          return DateTime(year, month, day, hour, minute, second);
        } else {
          // 仅日期：YYYYMMDD（全天事件）
          return DateTime(year, month, day);
        }
      }
    } catch (e) {
      // 解析失败，返回 null
    }
    return null;
  }

  /// 转义特殊字符（RFC 5545）
  String _escapeText(String text) {
    return text
        .replaceAll('\\', '\\\\')
        .replaceAll(',', '\\,')
        .replaceAll(';', '\\;')
        .replaceAll('\n', '\\n');
  }

  /// 反转义特殊字符
  String _unescapeText(String text) {
    return text
        .replaceAll('\\n', '\n')
        .replaceAll('\\;', ';')
        .replaceAll('\\,', ',')
        .replaceAll('\\\\', '\\');
  }

  /// 将内容保存到文件
  Future<void> saveToFile(String content, String filePath) async {
    final file = File(filePath);
    await file.writeAsString(content, encoding: utf8);
  }

  /// 从文件读取内容
  Future<String> readFromFile(String filePath) async {
    final file = File(filePath);
    return await file.readAsString(encoding: utf8);
  }
}
