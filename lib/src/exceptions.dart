class TypeCoercionException implements Exception {
  TypeCoercionException(this.expectedType, this.actualType);

  final Type expectedType;
  final Type actualType;

  @override
  String toString({bool includeActualType = false}) {
    final trailingString = includeActualType ? " (input is '$actualType')" : "";
    return "input is not expected type '$expectedType'$trailingString";
  }
}