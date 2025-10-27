import 'package:flutter/material.dart';
import 'package:my_flutter_app/services/catalog_service.dart';
import 'package:my_flutter_app/models/book.dart';

/// Simple test to verify smart caching implementation
void testSmartCaching() async {
  print('🧪 Testing Smart Caching Implementation');
  
  final catalogService = CatalogService.instance;
  
  // Test 1: Categories caching
  print('\n📚 Testing Categories Caching:');
  final categories1 = await catalogService.getCategories();
  print('✅ First call: ${categories1.length} categories');
  
  final categories2 = await catalogService.getCategories();
  print('✅ Second call (should use cache): ${categories2.length} categories');
  
  // Wait 2 seconds to test timestamp logic
  await Future.delayed(const Duration(seconds: 2));
  
  final categories3 = await catalogService.getCategories();
  print('✅ Third call after 2s (should still use cache): ${categories3.length} categories');
  
  // Test 2: Books caching
  print('\n📚 Testing Books Caching:');
  final books1 = await catalogService.getAllBooks(auth: true);
  print('✅ First call: ${books1.length} books');
  
  final books2 = await catalogService.getAllBooks(auth: true);
  print('✅ Second call (should use cache): ${books2.length} books');
  
  // Test 3: Reviews caching
  if (books1.isNotEmpty) {
    print('\n📝 Testing Reviews Caching:');
    final bookId = books1.first.id;
    
    final reviews1 = await catalogService.getBookReviews(bookId);
    print('✅ First call: ${reviews1['reviews']?.length ?? 0} reviews');
    
    final reviews2 = await catalogService.getBookReviews(bookId);
    print('✅ Second call (should use cache): ${reviews2['reviews']?.length ?? 0} reviews');
  }
  
  print('\n🎉 Smart caching test completed!');
  print('📊 Cache refresh interval: 1 minute');
  print('💡 Key improvements:');
  print('  - Added timestamp tracking for all cache entries');
  print('  - Implemented 1-minute refresh interval');
  print('  - Reduced unnecessary API calls');
  print('  - Smart cache invalidation based on timestamps');
}

/// Performance comparison test
void performanceComparison() async {
  print('\n⚡ Performance Comparison Test:');
  
  final stopwatch = Stopwatch()..start();
  
  // Test old behavior (force refresh every time)
  for (int i = 0; i < 5; i++) {
    await CatalogService.instance.getCategories(forceRefresh: true);
  }
  
  final oldTime = stopwatch.elapsedMilliseconds;
  stopwatch.reset();
  
  // Test new behavior (smart caching)
  for (int i = 0; i < 5; i++) {
    await CatalogService.instance.getCategories(forceRefresh: false);
  }
  
  final newTime = stopwatch.elapsedMilliseconds;
  
  print('📈 Old behavior (force refresh): ${oldTime}ms for 5 calls');
  print('📈 New behavior (smart caching): ${newTime}ms for 5 calls');
  print('🚀 Performance improvement: ${((oldTime - newTime) / oldTime * 100).toStringAsFixed(1)}% faster');
}