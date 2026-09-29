import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../widgets/apple_bars.dart';
import '../../di.dart';
import '../../models/place.dart';
import '../../models/review.dart';
import '../../utils/format.dart';
import '../../widgets/async_body.dart';
import '../../widgets/inset_group.dart';
import '../../widgets/inset_list_view.dart';
import '../../widgets/verdict_icon.dart';
import '../place/place_detail_screen.dart';

class MyReviewsScreen extends StatefulWidget {
  const MyReviewsScreen({super.key});

  @override
  State<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends State<MyReviewsScreen> {
  late Future<List<(Review, Place)>> _future = reviewRepo.myReviews();

  void _reload() => setState(() => _future = reviewRepo.myReviews());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const AppleAppBar(title: Text('我的評價')),
      body: AsyncBody<List<(Review, Place)>>(
        future: _future,
        onRetry: _reload,
        builder: (context, items) {
          if (items.isEmpty) {
            return const Center(child: Text('你還沒有寫過評價'));
          }
          return InsetListView(
            padding: barInsets(context, bottom: 24).add(const EdgeInsets.symmetric(horizontal: 16)),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final (review, place) = items[i];
              return ListTile(
                leading: VerdictIcon(review.verdict, size: 32),
                title: Text(place.name),
                subtitle: Text(
                  '${review.verdict.label} · ${fmtRelative(review.createdAt)}\n${review.body}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                isThreeLine: true,
                trailing: const Chevron(),
                onTap: () async {
                  await Navigator.of(context).push(CupertinoPageRoute(
                    builder: (_) => PlaceDetailScreen(placeId: place.id, initial: place),
                  ));
                  _reload();
                },
              );
            },
          );
        },
      ),
    );
  }
}
