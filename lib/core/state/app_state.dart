class AppState {
  final String? userPhone;

  final String? marketId;
  final String? marketName;

  final String? neighborhoodId;
  final String? neighborhoodName;

  /// 🔥 جديد (حل مشكلة الشاشة الفارغة)
  final List<dynamic> products;

  /// 🔥 حالة التحميل
  final bool isLoading;

  AppState({
    this.userPhone,
    this.marketId,
    this.marketName,
    this.neighborhoodId,
    this.neighborhoodName,
    this.products = const [],
    this.isLoading = false,
  });

  AppState copyWith({
    String? userPhone,
    String? marketId,
    String? marketName,
    String? neighborhoodId,
    String? neighborhoodName,
    List<dynamic>? products,
    bool? isLoading,
  }) {
    return AppState(
      userPhone: userPhone ?? this.userPhone,
      marketId: marketId ?? this.marketId,
      marketName: marketName ?? this.marketName,
      neighborhoodId: neighborhoodId ?? this.neighborhoodId,
      neighborhoodName: neighborhoodName ?? this.neighborhoodName,
      products: products ?? this.products,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}
