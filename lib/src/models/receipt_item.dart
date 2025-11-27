/// Represents a single item on a receipt.
class ReceiptItem {
  /// Name or description of the item.
  final String name;

  /// Quantity of the item purchased.
  final double quantity;

  /// Unit of measurement (e.g., 'kom', 'kg', 'l').
  final String? unit;

  /// Price per unit.
  final double? unitPrice;

  /// Total price for this item (quantity * unitPrice).
  final double totalPrice;

  /// Creates a new [ReceiptItem] instance.
  const ReceiptItem({
    required this.name,
    this.quantity = 1.0,
    this.unit,
    this.unitPrice,
    required this.totalPrice,
  });

  /// Creates a [ReceiptItem] from a map.
  factory ReceiptItem.fromMap(Map<dynamic, dynamic> map) {
    return ReceiptItem(
      name: map['name'] as String? ?? '',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 1.0,
      unit: map['unit'] as String?,
      unitPrice: (map['unitPrice'] as num?)?.toDouble(),
      totalPrice: (map['totalPrice'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Converts this [ReceiptItem] to a map.
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'unitPrice': unitPrice,
      'totalPrice': totalPrice,
    };
  }

  @override
  String toString() {
    return 'ReceiptItem(name: $name, quantity: $quantity ${unit ?? ''}, '
        'totalPrice: $totalPrice)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReceiptItem &&
        other.name == name &&
        other.quantity == quantity &&
        other.unit == unit &&
        other.unitPrice == unitPrice &&
        other.totalPrice == totalPrice;
  }

  @override
  int get hashCode {
    return Object.hash(name, quantity, unit, unitPrice, totalPrice);
  }
}
