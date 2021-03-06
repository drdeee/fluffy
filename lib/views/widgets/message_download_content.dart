import 'package:famedlysdk/famedlysdk.dart';
import 'package:flutter/material.dart';
import 'package:fluffychat/utils/event_extension.dart';

class MessageDownloadContent extends StatelessWidget {
  final Event event;
  final Color textColor;

  const MessageDownloadContent(this.event, this.textColor, {Key key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final String filename = event.content.containsKey('filename')
        ? event.content['filename']
        : event.body;
    return Container(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              primary: Theme.of(context).scaffoldBackgroundColor,
              onPrimary: Theme.of(context).textTheme.bodyText1.color,
            ),
            onPressed: () => event.openFile(context),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.download_outlined),
                SizedBox(width: 8),
                Text(
                  filename,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          if (event.sizeString != null)
            Text(
              event.sizeString,
              style: TextStyle(
                color: textColor,
              ),
            ),
        ],
      ),
    );
  }
}
