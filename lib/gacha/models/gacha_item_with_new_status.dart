import 'gacha_item.dart';

class GachaItemWithNewStatus {
  // The full path of promotion, e.g., [common_item, rare_item, super_rare_item]
  final List<GachaItem> promotionPath;
  final bool isNew;

  GachaItem get initialItem => promotionPath.first;
  GachaItem get finalItem => promotionPath.last;
  bool get didPromote => promotionPath.length > 1;

  GachaItemWithNewStatus({
    required this.promotionPath,
    required this.isNew,
  }) : assert(promotionPath.isNotEmpty);
}
