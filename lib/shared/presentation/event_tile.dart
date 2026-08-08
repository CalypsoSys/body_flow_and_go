import 'package:flutter/material.dart';

import '../../features/events/domain/body_event.dart';
import 'event_display.dart';

class EventTile extends StatelessWidget {
  const EventTile({super.key, required this.event, this.onTap});

  final BodyEvent event;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final details = eventDetailsSummary(event);

    return Semantics(
      button: onTap != null,
      label: '${event.eventType.displayName} at ${formatEventTime(event)}',
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        minVerticalPadding: 12,
        leading: CircleAvatar(
          backgroundColor: colors.secondaryContainer,
          foregroundColor: colors.onSecondaryContainer,
          child: Icon(event.eventType.icon),
        ),
        title: Text(
          event.eventType.displayName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: (details.isEmpty && (event.notes?.isEmpty ?? true))
            ? null
            : Text(
                [
                  if (details.isNotEmpty) details,
                  if (event.notes?.isNotEmpty ?? false) event.notes!,
                ].join('\n'),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(formatEventTime(event)),
            if (onTap != null) const Icon(Icons.chevron_right),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
