import 'package:moveup/models/activity.dart';
import 'package:moveup/services/json_list_store.dart';
import 'package:moveup/services/sample_data.dart';

// Menyimpan aktivitas sebagai file JSON di penyimpanan aplikasi, terpisah per akun
class ActivityStore extends JsonListStore<Activity> {
  ActivityStore._() : super('activities');

  static final instance = ActivityStore._();

  // Terbaru di depan
  List<Activity> get activities => items;

  @override
  Comparator<Activity> get order => (a, b) => b.startTime.compareTo(a.startTime);

  @override
  String idOf(Activity item) => item.id;

  @override
  Map<String, dynamic> encode(Activity item) => item.toJson();

  @override
  Activity decode(Map<String, dynamic> json) => Activity.fromJson(json);

  @override
  List<Activity> seed() => [];

  @override
  List<Activity>? upgrade(List<Activity> loaded) {
    final recorded = loaded.where((a) => !SampleData.isSampleId(a.id)).toList();
    return recorded.length == loaded.length ? null : recorded;
  }

  List<Activity> between(DateTime from, DateTime to) =>
      activities.where((a) => !a.startTime.isBefore(from) && a.startTime.isBefore(to)).toList();
}
