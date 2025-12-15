import 'package:lunar/lunar.dart';

class LunarUtil {
  /// 获取农历日期字符串（月日格式）
  static String getLunarDate(DateTime date) {
    final solar = Solar.fromDate(date);
    final lunar = solar.getLunar();

    // 返回农历月日
    return '${lunar.getMonthInChinese()}${lunar.getDayInChinese()}';
  }

  /// 获取完整农历日期字符串
  static String getFullLunarDate(DateTime date) {
    final solar = Solar.fromDate(date);
    final lunar = solar.getLunar();

    return '${lunar.getYearInChinese()}年${lunar.getMonthInChinese()}${lunar.getDayInChinese()}';
  }

  /// 获取农历节日（如果有）
  static String? getLunarFestival(DateTime date) {
    final solar = Solar.fromDate(date);
    final lunar = solar.getLunar();

    // 获取农历节日
    final festivals = lunar.getFestivals();
    if (festivals.isNotEmpty) {
      return festivals.first;
    }

    // 获取阳历节日
    final solarFestivals = solar.getFestivals();
    if (solarFestivals.isNotEmpty) {
      return solarFestivals.first;
    }

    return null;
  }

  /// 获取农历节气
  static String? getSolarTerm(DateTime date) {
    final solar = Solar.fromDate(date);
    final jieQi = solar.getLunar().getJieQi();
    return jieQi.isEmpty ? null : jieQi;
  }

  /// 获取农历天干地支年份
  static String getYearInGanZhi(DateTime date) {
    final solar = Solar.fromDate(date);
    final lunar = solar.getLunar();
    return lunar.getYearInGanZhi();
  }

  /// 获取生肖
  static String getYearShengXiao(DateTime date) {
    final solar = Solar.fromDate(date);
    final lunar = solar.getLunar();
    return lunar.getYearShengXiao();
  }

  /// 获取农历显示文本（优先显示节日和节气，否则显示日期）
  static String getLunarDisplayText(DateTime date) {
    // 优先显示节气
    final solarTerm = getSolarTerm(date);
    if (solarTerm != null && solarTerm.isNotEmpty) {
      return solarTerm;
    }

    // 其次显示节日
    final festival = getLunarFestival(date);
    if (festival != null) {
      return festival;
    }

    // 最后显示农历日期
    final solar = Solar.fromDate(date);
    final lunar = solar.getLunar();
    final day = lunar.getDayInChinese();

    // 如果是初一，显示月份
    if (day == '初一') {
      return lunar.getMonthInChinese();
    }

    return day;
  }

  /// 获取详细的农历信息
  static Map<String, String> getDetailedLunarInfo(DateTime date) {
    final solar = Solar.fromDate(date);
    final lunar = solar.getLunar();

    final info = <String, String>{};

    // 农历日期
    info['农历'] = '${lunar.getMonthInChinese()}${lunar.getDayInChinese()}';

    // 天干地支年份
    info['年份'] = '${lunar.getYearInGanZhi()}${lunar.getYearShengXiao()}年';

    // 月份天干地支
    info['月份'] = lunar.getMonthInGanZhi() + '月';

    // 日期天干地支
    info['日期'] = lunar.getDayInGanZhi() + '日';

    // 节气
    final jieQi = lunar.getJieQi();
    if (jieQi.isNotEmpty) {
      info['节气'] = jieQi;
    }

    // 节日
    final festivals = <String>[];
    festivals.addAll(lunar.getFestivals());
    festivals.addAll(solar.getFestivals());
    if (festivals.isNotEmpty) {
      info['节日'] = festivals.join('、');
    }

    // 星座
    final xingZuo = solar.getXingZuo();
    if (xingZuo.isNotEmpty) {
      info['星座'] = xingZuo;
    }

    return info;
  }
}
