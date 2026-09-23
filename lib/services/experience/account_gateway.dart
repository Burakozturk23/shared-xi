import 'package:firebase_auth/firebase_auth.dart';
import '../auth_service.dart';
import '../account_deletion_service.dart';

class AccountGateway {
  const AccountGateway();
  User? get user => AuthService.currentUser;
  bool get connected => AuthService.isGoogleAccount;
  Future<AccountDeletionResult> delete() =>
      AccountDeletionService.deleteCurrentAccount();
}
