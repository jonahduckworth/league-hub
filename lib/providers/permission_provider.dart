import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/permission_service.dart';

/// Global singleton — PermissionService is stateless (pure functions).
final permissionServiceProvider =
    Provider<PermissionService>((ref) => const PermissionService());
