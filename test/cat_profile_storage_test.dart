import 'package:feline_detector/models/cat_profile.dart';
import 'package:feline_detector/services/cat_profile_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'ensureDefaultProfile creates a default profile and active cat id',
    () async {
      final profiles = await CatProfileStorage.ensureDefaultProfile();

      expect(profiles, hasLength(1));
      expect(profiles.single, isA<CatProfile>());
      expect(profiles.single.name, 'My Cat');

      final activeId = await CatProfileStorage.loadActiveCatId();
      expect(activeId, profiles.single.id);
    },
  );
}
