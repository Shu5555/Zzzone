import 'package:flutter/material.dart';

class ShopItem {
  final String id;
  final String name;
  final int cost;
  final Color previewColor;

  const ShopItem({
    required this.id,
    required this.name,
    required this.cost,
    required this.previewColor,
  });
}

// 商品カタログ
final List<ShopItem> backgroundShopCatalog = [
  const ShopItem(id: 'color_#ef5350', name: 'Red', cost: 1000, previewColor: Color(0xffef5350)),
  const ShopItem(id: 'color_#ec407a', name: 'Pink', cost: 1000, previewColor: Color(0xffec407a)),
  const ShopItem(id: 'color_#ff7043', name: 'Coral', cost: 1000, previewColor: Color(0xffff7043)),
  const ShopItem(id: 'color_#ffa726', name: 'Orange', cost: 1000, previewColor: Color(0xffffa726)),
  const ShopItem(id: 'color_#ffca28', name: 'Amber', cost: 1000, previewColor: Color(0xffffca28)),
  const ShopItem(id: 'color_#d4e157', name: 'Lime', cost: 1000, previewColor: Color(0xffd4e157)),
  const ShopItem(id: 'color_#9ccc65', name: 'Light Green', cost: 1000, previewColor: Color(0xff9ccc65)),
  const ShopItem(id: 'color_#66bb6a', name: 'Green', cost: 1000, previewColor: Color(0xff66bb6a)),
  const ShopItem(id: 'color_#26a69a', name: 'Teal', cost: 1000, previewColor: Color(0xff26a69a)),
  const ShopItem(id: 'color_#26c6da', name: 'Cyan', cost: 1000, previewColor: Color(0xff26c6da)),
  const ShopItem(id: 'color_#29b6f6', name: 'Light Blue', cost: 1000, previewColor: Color(0xff29b6f6)),
  const ShopItem(id: 'color_#5c6bc0', name: 'Indigo', cost: 1000, previewColor: Color(0xff5c6bc0)),
  const ShopItem(id: 'color_#7e57c2', name: 'Deep Purple', cost: 1000, previewColor: Color(0xff7e57c2)),
  const ShopItem(id: 'color_#8d6e63', name: 'Brown', cost: 1000, previewColor: Color(0xff8d6e63)),
  // New Pastel Colors
  const ShopItem(id: 'color_#f8bbd0', name: 'Pastel Pink', cost: 1000, previewColor: Color(0xfff8bbd0)),
  const ShopItem(id: 'color_#bbdefb', name: 'Pastel Blue', cost: 1000, previewColor: Color(0xffbbdefb)),
  const ShopItem(id: 'color_#d1c4e9', name: 'Pastel Purple', cost: 1000, previewColor: Color(0xffd1c4e9)),
  const ShopItem(id: 'color_#c8e6c9', name: 'Pastel Green', cost: 1000, previewColor: Color(0xffc8e6c9)),
  const ShopItem(id: 'color_#fff9c4', name: 'Pastel Yellow', cost: 1000, previewColor: Color(0xfffff9c4)),
  // 'white' is a special case, handled separately as a free item.
  // const ShopItem(id: 'color_#ffffff', name: 'White', cost: 0, previewColor: Color(0xffffffff)),
];
