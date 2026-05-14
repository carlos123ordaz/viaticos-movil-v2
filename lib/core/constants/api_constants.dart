class ApiConstants {
  static const String baseUrl = 'https://viaticos-0sro.onrender.com/api';
  static const String ocrBaseUrl = 'http://192.168.70.69:8000';

  // Auth
  static const String login = '/auth/login';
  static const String loginMicrosoft = '/auth/microsoft/login';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String changePassword = '/auth/change-password';

  // Expenses
  static const String expenses = '/expenses';
  static const String expenseCapture = '/expenses/capture';
  static const String expenseVoice = '/expenses/voice-to-expense';

  // Users
  static const String userMe = '/users/me';
  static const String pushToken = '/users/push-token';

  // Bitrix
  static const String bitrixTasks = '/bitrix/tasks';

  // Expense Categories & Receipt Types
  static const String expenseCategories = '/expense-categories';
  static const String receiptTypes = '/receipt-types';

  // Cost Centers
  static const String costCenters = '/cost-centers';
  static const String subCostCenters = '/sub-cost-centers';
  static const String subSubCostCenters = '/sub-sub-cost-centers';

  // Expense Settlements
  static const String expenseSettlementsFinalize = '/expense-settlements/finalize';
}
