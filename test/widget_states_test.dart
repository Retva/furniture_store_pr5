import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furniture_store/models/page_result.dart';
import 'package:furniture_store/state/list_state.dart';
import 'package:furniture_store/widgets/list_state_body.dart';
import 'package:furniture_store/widgets/state_views.dart';

Widget wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  group('Состояния списка', () {
    testWidgets('показывает индикатор загрузки, когда данных ещё нет', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          ListStateBody<String>(
            state: const ListLoading(),
            hasFilters: false,
            builder: (_) => const Text('данные'),
            onRetry: () {},
            onResetFilters: () {},
            onGoToPage: (_) {},
            emptyTitle: 'Пусто',
            emptyMessage: 'Нет записей',
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Загружаем…'), findsOneWidget);
      expect(find.text('данные'), findsNothing);
    });

    testWidgets('показывает пустой результат без кнопки повтора', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          ListStateBody<String>(
            state: ListLoaded(PageResult.empty()),
            hasFilters: false,
            builder: (_) => const Text('данные'),
            onRetry: () {},
            onResetFilters: () {},
            onGoToPage: (_) {},
            emptyTitle: 'Товаров пока нет',
            emptyMessage: 'Добавьте первую запись.',
          ),
        ),
      );

      expect(find.text('Товаров пока нет'), findsOneWidget);
      expect(find.text('Повторить'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('показывает ошибку и вызывает повтор', (tester) async {
      var retried = false;

      await tester.pumpWidget(
        wrap(
          ListStateBody<String>(
            state: const ListFailed('Сервер недоступен'),
            hasFilters: false,
            builder: (_) => const Text('данные'),
            onRetry: () => retried = true,
            onResetFilters: () {},
            onGoToPage: (_) {},
            emptyTitle: 'Пусто',
            emptyMessage: 'Нет записей',
          ),
        ),
      );

      expect(find.text('Не удалось загрузить данные'), findsOneWidget);
      expect(find.text('Сервер недоступен'), findsOneWidget);
      expect(find.text('Повторить'), findsOneWidget);

      await tester.tap(find.text('Повторить'));
      await tester.pump();
      expect(retried, isTrue);
    });
  });

  group('ErrorView', () {
    testWidgets('кнопка повтора видна вместе со значком обновления', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(ErrorView(message: 'Нет сети', onRetry: () {})),
      );

      expect(find.text('Повторить'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });
  });
}
