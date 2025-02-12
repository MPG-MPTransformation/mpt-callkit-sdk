import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ImageSlider extends StatefulWidget {
  final List<String> imageUrls;
  final int initialPage;

  const ImageSlider({super.key, required this.imageUrls, this.initialPage = 0});

  @override
  State<ImageSlider> createState() => _ImageSliderState();
}

class _ImageSliderState extends State<ImageSlider> {
  late final PageController _pageController;

  @override
  void initState() {
    _pageController = PageController(initialPage: widget.initialPage);
    super.initState();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Stack(children: [
          Padding(
            padding: const EdgeInsets.all(2.0),
            child: PageView.builder(
              itemCount: widget.imageUrls.length,
              controller: _pageController,
              itemBuilder: (context, index) {
                return _ZoomableImage(
                  imageUrl: widget.imageUrls[index],
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

class _ZoomableImage extends StatefulWidget {
  final String imageUrl;

  const _ZoomableImage({required this.imageUrl});

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage> {
  final TransformationController _transformationController =
      TransformationController();
  TapDownDetails? _doubleTapDetails;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (details) {
        _doubleTapDetails = details;
      },
      onDoubleTap: () {
        if (_transformationController.value != Matrix4.identity()) {
          // Reset zoom
          _transformationController.value = Matrix4.identity();
        } else {
          // Zoom in double-tap position
          final position = _doubleTapDetails!.localPosition;
          _transformationController.value = Matrix4.identity()
            ..translate(-position.dx * 1.5, -position.dy * 1.5)
            ..scale(2.0);
        }
      },
      child: InteractiveViewer(
        transformationController: _transformationController,
        panEnabled: true,
        minScale: 1.0,
        maxScale: 3.0,
        child: CachedNetworkImage(
          imageUrl: widget.imageUrl,
          fit: BoxFit.contain,
          placeholder: (context, url) => const Center(
            child: CircularProgressIndicator(),
          ),
          errorWidget: (context, url, error) => const Icon(Icons.error),
        ),
      ),
    );
  }
}
