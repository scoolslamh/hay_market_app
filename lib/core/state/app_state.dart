import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppState {
  final String? userPhone;

  final String? marketId;
  final String? marketName;

  final String? neighborhoodId;
  final String? neighborhoodName;

  AppState({
    this.userPhone,
    this.marketId,
    this.marketName,
    this.neighborhoodId,
    this.neighborhoodName,
  });

  AppState copyWith({
    String? userPhone,
    String? marketId,
    String? marketName,
    String? neighborhoodId,
    String? neighborhoodName,
  }) {
    return AppState(
      userPhone: userPhone ?? this.userPhone,
      marketId: marketId ?? this.marketId,
      marketName: marketName ?? this.marketName,
      neighborhoodId: neighborhoodId ?? this.neighborhoodId,
      neighborhoodName: neighborhoodName ?? this.neighborhoodName,
    );
  }
}
