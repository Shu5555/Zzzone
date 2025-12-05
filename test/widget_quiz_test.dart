import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sleep_management_app/main.dart';
import 'package:sleep_management_app/screens/home_screen.dart';
import 'package:sleep_management_app/screens/quiz_screen.dart';
import 'package:sleep_management_app/services/supabase_ranking_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Import for flutter_dotenv

import 'mocks.mocks.dart'; // Generated mock file

void main() {
  group('Quiz Feature', () {
    late MockSupabaseRankingService mockSupabaseRankingService;

    setUpAll(() async { // Mark as async to use await for dotenv.load
      // Initialize FFI for sqflite
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;

      // Load dotenv
      await dotenv.load(fileName: ".env");

      // Mock SupabaseRankingService
      mockSupabaseRankingService = MockSupabaseRankingService();
      // Stub getUser to prevent errors, as HomeScreen tries to call it.
      // Return a basic user profile that doesn't trigger complex logic.
      when(mockSupabaseRankingService.getUser(any)).thenAnswer((_) async => {'userId': 'test_user_id', 'favorite_quote_id': 'random'});
    });

    testWidgets('Quiz button navigates to QuizScreen', (WidgetTester tester) async {
      // Build our app and trigger a frame.
      // Pass the mocked service to MyApp
      await tester.pumpWidget(MyApp(supabaseService: mockSupabaseRankingService));

      // Ensure the home screen is displayed
      expect(find.byType(HomeScreen), findsOneWidget);

      // Find the 'Zzzoneクイズ' button
      final quizButtonFinder = find.widgetWithText(ElevatedButton, 'Zzzoneクイズ');
      expect(quizButtonFinder, findsOneWidget);

      // Tap the button and trigger a frame.
      await tester.tap(quizButtonFinder);
      await tester.pumpAndSettle(); // Wait for navigation animation to complete

      // Verify that the QuizScreen is displayed
      expect(find.byType(QuizScreen), findsOneWidget);
      expect(find.text('Zzzoneクイズ'), findsOneWidget);
    });
  });
}
