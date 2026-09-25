import 'dart:ui' as ui;

// ignore: depend_on_referenced_packages, implementation_imports
import 'package:file/src/interface/file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// ignore: depend_on_referenced_packages
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_map/flutter_map.dart';

///////////////////////////////////////////

class CachedTileProvider extends TileProvider {
  final BaseCacheManager cacheManager = DefaultCacheManager();

  ///
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final String url = getTileUrl(coordinates, options);
    return CachedNetworkImage(url, cacheManager: cacheManager);
  }

  ///
  @override
  String getTileUrl(TileCoordinates coordinates, TileLayer options) {
    return options.urlTemplate!
        .replaceAll('{z}', coordinates.z.toString())
        .replaceAll('{x}', coordinates.x.toString())
        .replaceAll('{y}', coordinates.y.toString());
  }
}

///////////////////////////////////////////

class CachedNetworkImage extends ImageProvider<CachedNetworkImage> {
  CachedNetworkImage(this.url, {required this.cacheManager});

  final String url;
  final BaseCacheManager cacheManager;

  /// ImageCache のキーとして URL で同一判定させる。
  /// これが無いと毎回別キー扱いになり、同じタイルでもメモリキャッシュが効かず再デコードされていた
  @override
  bool operator ==(Object other) => other is CachedNetworkImage && other.url == url;

  ///
  @override
  int get hashCode => url.hashCode;

  ///
  @override
  Future<CachedNetworkImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<CachedNetworkImage>(this);
  }

  ///
  @override
  ImageStreamCompleter loadBuffer(
    CachedNetworkImage key,
    Future<ui.Codec> Function(ui.ImmutableBuffer buffer,
            {int? cacheWidth, int? cacheHeight})
        decode,
  ) {
    return OneFrameImageStreamCompleter(_loadAsync(key, decode));
  }

  ///
  Future<ImageInfo> _loadAsync(
    CachedNetworkImage key,
    Future<ui.Codec> Function(ui.ImmutableBuffer buffer,
            {int? cacheWidth, int? cacheHeight})
        decode,
  ) async {
    try {
      // キャッシュから画像を取得
      final File file = await cacheManager.getSingleFile(key.url);

      final Uint8List bytes = await file.readAsBytes();

      // デコード処理
      final ui.ImmutableBuffer buffer =
          await ui.ImmutableBuffer.fromUint8List(bytes);

      final ui.Codec codec = await decode(buffer);

      final ui.FrameInfo frame = await codec.getNextFrame();

      return ImageInfo(image: frame.image);
    } catch (e) {
      throw Exception('Failed to load image.');
    }
  }
}
