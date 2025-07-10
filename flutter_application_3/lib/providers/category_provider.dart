import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CategoryProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _categoryDocs = [];
  List<String> _categories = [];
  List<String> get categories => _categories;
  List<Map<String, dynamic>> get categoryDocs => _categoryDocs;

  CategoryProvider() {
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final user = _auth.currentUser;
    if (user == null) {
      _categoryDocs = [];
      _categories = ['None'];
      notifyListeners();
      return;
    }
    try {
      final ref = _firestore.collection('users').doc(user.uid).collection('categories');
      final snapshot = await ref.orderBy('order', descending: false).get();
      _categoryDocs = snapshot.docs.map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>}).toList();
      _categories = _categoryDocs.map((doc) => doc['name'] as String).toList();

      // 自动修正 order 字段缺失或不连续
      bool needFix = false;
      int expectedOrder = 0;
      for (int i = 0; i < _categoryDocs.length; i++) {
        final doc = _categoryDocs[i];
        if (doc['name'] == 'None') continue; // None 不参与 order
        if (doc['order'] != expectedOrder) {
          // 修正 Firestore
          await ref.doc(doc['id']).update({'order': expectedOrder});
          needFix = true;
        }
        expectedOrder++;
      }
      if (needFix) {
        // 修正后重新加载
        final fixedSnapshot = await ref.orderBy('order', descending: false).get();
        _categoryDocs = fixedSnapshot.docs.map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>}).toList();
        _categories = _categoryDocs.map((doc) => doc['name'] as String).toList();
      }

      // 保证None在最前面
      if (_categories.contains('None')) {
        _categories.remove('None');
        _categories.insert(0, 'None');
      }
      notifyListeners();
    } catch (e) {
      print('Error loading categories: $e');
      _categoryDocs = [];
      _categories = ['None'];
      notifyListeners();
    }
  }

  Future<void> reorderCategory(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || newIndex < 0 || oldIndex >= _categories.length || newIndex >= _categories.length) return;
    final user = _auth.currentUser;
    if (user == null) return;
    // 允许所有分类都能自由拖动调整顺序
    try {
      final item = _categories.removeAt(oldIndex);
      _categories.insert(newIndex, item);
      // 同步到Firestore
      final ref = _firestore.collection('users').doc(user.uid).collection('categories');
      for (int i = 0; i < _categories.length; i++) {
        final name = _categories[i];
        final docs = await ref.where('name', isEqualTo: name).get();
        for (var doc in docs.docs) {
          await doc.reference.update({'order': i});
        }
      }
      notifyListeners();
    } catch (e) {
      print('Error reordering categories: $e');
      // 恢复原始顺序
      await _loadCategories();
    }
  }

  Future<void> addCategory(String name) async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final ref = _firestore.collection('users').doc(user.uid).collection('categories');
      // 检查是否已存在同名分类
      final exists = await ref.where('name', isEqualTo: name).get();
      if (exists.docs.isNotEmpty) return; // 已存在则不添加
      // 只统计非 None 分类数量
      int order = _categoryDocs.where((doc) => doc['name'] != 'None').length;
      await ref.add({'name': name, 'order': order});
      await _loadCategories();
    } catch (e) {
      print('Error adding category: $e');
    }
  }

  Future<void> updateCategory(String oldName, String newName) async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final ref = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('categories');
      final snapshot = await ref.where('name', isEqualTo: oldName).get();
      for (var doc in snapshot.docs) {
        await doc.reference.update({'name': newName});
      }
      await _loadCategories();
    } catch (e) {
      print('Error updating category: $e');
    }
  }

  Future<void> deleteCategory(String name) async {
    if (name == 'None') return;
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final ref = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('categories');
      final snapshot = await ref.where('name', isEqualTo: name).get();
      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }
      await _loadCategories();
    } catch (e) {
      print('Error deleting category: $e');
    }
  }
} 