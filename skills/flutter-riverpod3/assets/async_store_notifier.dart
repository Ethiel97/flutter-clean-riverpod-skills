// features/<feature>/presentation/providers/items_provider.dart
//
// Template for a screen's store: an AsyncNotifier whose state is an
// immutable value class, with a paginated load-more that never blanks the
// list on failure.
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide AsyncResult;
import 'package:your_app/core/errors/errors.dart';
import 'package:your_app/features/items/di/di.dart';
import 'package:your_app/features/items/domain/domain.dart';

/// Value equality matters: Riverpod only notifies listeners when the new
/// state is not `==` to the old one, and `select` compares by value too.
class ItemsState extends Equatable {
  const ItemsState({
    required this.items,
    this.nextCursor,
    this.isLoadingMore = false,
  });

  final List<Item> items;
  final String? nextCursor;
  final bool isLoadingMore;

  bool get hasMore => nextCursor != null;

  ItemsState copyWith({
    List<Item>? items,
    String? nextCursor,
    bool? isLoadingMore,
  }) => ItemsState(
    items: items ?? this.items,
    nextCursor: nextCursor ?? this.nextCursor,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
  );

  @override
  List<Object?> get props => [items, nextCursor, isLoadingMore];
}

class ItemsNotifier extends AsyncNotifier<ItemsState> {
  static const _pageSize = 20;

  @override
  Future<ItemsState> build() async {
    // `watch` in build: the store rebuilds if the repository is swapped.
    final page = await ref.watch(itemRepositoryProvider).getPage(limit: _pageSize);
    // The one sanctioned throw: the failure surfaces as AsyncError.
    final value = page.getOrThrow();
    return ItemsState(items: value.items, nextCursor: value.nextCursor);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));

    // `read` in methods: a one-off call, not a dependency of this store.
    final result = await ref
        .read(itemRepositoryProvider)
        .getPage(cursor: current.nextCursor, limit: _pageSize);

    // The provider may have been disposed while the request was in flight.
    if (!ref.mounted) return;

    state = AsyncData(
      result.fold(
        (page) => current.copyWith(
          items: [...current.items, ...page.items],
          nextCursor: page.nextCursor,
          isLoadingMore: false,
        ),
        // Keep what the user is reading; only drop the spinner.
        (failure) => current.copyWith(isLoadingMore: false),
      ),
    );
  }

  /// Mutations return the Result so the caller (a submission notifier) can
  /// report a failure, while this store changes only on success.
  AsyncResult<Unit> remove(String id) async {
    final result = await ref.read(itemRepositoryProvider).delete(id);
    if (!ref.mounted) return result;

    result.onSuccess((_) {
      final current = state.value;
      if (current == null) return;
      state = AsyncData(
        current.copyWith(items: current.items.where((i) => i.id != id).toList()),
      );
    });
    return result;
  }
}

final itemsProvider = AsyncNotifierProvider<ItemsNotifier, ItemsState>(
  ItemsNotifier.new,
);
