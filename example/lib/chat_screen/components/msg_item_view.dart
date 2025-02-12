import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:mpt_callkit/models/models.dart';
import 'package:url_launcher/url_launcher.dart';

import 'image_slider.dart';

class MsgItemView extends StatefulWidget {
  const MsgItemView({
    super.key,
    required this.item,
  });

  final MsgData item;

  @override
  State<MsgItemView> createState() => _MsgItemViewState();
}

class _MsgItemViewState extends State<MsgItemView> {
  final maxImageInline = 3;
  var numOfFakeImages = 0;
  List<String> words = [];

  bool checkIsUrl(String text) {
    final RegExp urlRegExp = RegExp(
      r'^(https?:\/\/)?(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)$',
      caseSensitive: false,
    );
    return urlRegExp.hasMatch(text);
  }

  Future<void> _launchUrl(String text) async {
    if (text.isEmpty) {
      return;
    }

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    Uri url = Uri.parse(text.startsWith('http') ? text : 'https://$text');

    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Could not launch URL: ${url.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Attachment>? listImages = widget.item.attachments
        ?.where((element) => element.mediaType == "image")
        .toList();

    List<Attachment>? listFiles = widget.item.attachments
        ?.where((element) => element.mediaType == "file")
        .toList();

    if (listImages!.length < maxImageInline && listImages.isNotEmpty) {
      //
      numOfFakeImages = maxImageInline - listImages.length;
    } else {
      numOfFakeImages = 0;
    }

    if (widget.item.messageResponse?.messageType == "TEXT") {
      // split text message to list words, according to space, quote, bracket
      words = RegExp(r'(\s+|\(|\)|")|\S+')
          .allMatches(widget.item.messageResponse?.text ?? "")
          .map((match) => match.group(0)!)
          .toList();
    }

    bool isCustomer = widget.item.messageResponse?.sendFrom == "CUSTOMER";
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Align(
        alignment: isCustomer ? Alignment.centerRight : Alignment.centerLeft,
        child: widget.item.messageResponse?.messageType == "TEXT"
            ? Column(
                crossAxisAlignment: isCustomer
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Container(
                    constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.7),
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 14),
                    margin:
                        const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
                    decoration: BoxDecoration(
                      color: isCustomer ? Colors.blue : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(12),
                        topRight: const Radius.circular(12),
                        bottomLeft: isCustomer
                            ? const Radius.circular(12)
                            : Radius.zero,
                        bottomRight: isCustomer
                            ? Radius.zero
                            : const Radius.circular(12),
                      ),
                    ),
                    child: RichText(
                      text: TextSpan(
                        children: words.map((word) {
                          bool isUrl = checkIsUrl(word);
                          return TextSpan(
                            text: word,
                            style: TextStyle(
                              color: isCustomer
                                  ? isUrl
                                      ? Colors.yellow
                                      : Colors.white
                                  : isUrl
                                      ? Colors.deepPurple
                                      : Colors.black,
                              decoration: isUrl
                                  ? TextDecoration.underline
                                  : TextDecoration.none,
                            ),
                            recognizer:
                                TapGestureRecognizer() // launch url if it is
                                  ..onTap = () {
                                    if (isUrl) {
                                      _launchUrl(word);
                                    }
                                  },
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Text(
                      widget.item.creationTime ?? "N/A",
                      style: TextStyle(
                        color: isCustomer
                            ? Colors.grey
                            : Colors.black.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              )
            : Container(
                constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.7),
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: isCustomer
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: maxImageInline,
                        crossAxisSpacing: 0,
                        mainAxisSpacing: 5,
                      ),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: listImages.length +
                          (isCustomer ? numOfFakeImages : 0),
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      itemBuilder: (context, index) {
                        if (isCustomer && index < numOfFakeImages) {
                          return const SizedBox(height: 100, width: 100);
                        }

                        final imageIndex =
                            isCustomer ? index - numOfFakeImages : index;
                        final imageUrl = listImages[imageIndex].media!;

                        return Padding(
                          padding: const EdgeInsets.all(5),
                          child: GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => ImageSlider(
                                    imageUrls: listImages
                                        .map((e) => e.media!)
                                        .toList(),
                                    initialPage: imageIndex,
                                  ),
                                ),
                              );
                            },
                            child: CachedNetworkImage(
                              imageUrl: imageUrl,
                              placeholder: (context, url) => const Center(
                                child: CircularProgressIndicator(),
                              ),
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                              alignment: isCustomer
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              errorWidget: (context, url, error) => Image.asset(
                                "assets/icons/img_not_found.jpg",
                                width: 100,
                                height: 100,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: listFiles?.length ?? 0,
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.all(5),
                          child: GestureDetector(
                            onTap: () {
                              // launch file url
                              _launchUrl(listFiles?[index].media ?? "");
                            },
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.grey,
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                spacing: 5,
                                children: [
                                  Image.asset(
                                    "assets/icons/file_icon.png",
                                    width: 40,
                                    height: 40,
                                  ),
                                  Expanded(
                                    child: Text(
                                      listFiles?[index].fileName ?? "",
                                      maxLines: 2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Text(
                        widget.item.creationTime ?? "N/A",
                        style: TextStyle(
                          color: isCustomer
                              ? Colors.grey
                              : Colors.black.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
