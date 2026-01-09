class MunicipalModel {
  MunicipalModel(
    this.name,
    this.vertexCount, {
    required this.minLat,
    required this.minLng,
    required this.maxLat,
    required this.maxLng,
    required this.polygons,
    required this.centroidLat,
    required this.centroidLng,
    this.zKey,
  });

  final String name;

  final int vertexCount;

  final double minLat, minLng, maxLat, maxLng;

  final List<List<List<List<double>>>> polygons;

  final double centroidLat;

  final double centroidLng;

  int? zKey;
}
