import 'package:cloud_functions/cloud_functions.dart';
import '../models/info_centre.dart';

class InfoCentreService {
  final FirebaseFunctions? functions;
  InfoCentreService({this.functions});
  Future<InfoCentreData> load(String orgId) async {
    final result = await (functions ?? FirebaseFunctions.instance)
        .httpsCallable('infoCentreList')
        .call({'orgId': orgId, 'preview': true});
    return InfoCentreData.fromJson(
        Map<String, dynamic>.from(result.data as Map));
  }

  Future<String> reveal(String orgId, String id) async {
    final result = await (functions ?? FirebaseFunctions.instance)
        .httpsCallable('infoCentreReveal')
        .call({'orgId': orgId, 'id': id});
    return (result.data as Map)['password'] as String;
  }
}
