/// Question card + question map (ExerciseRunner, Luyện Nghe): the map to the right on wide
/// screens, below on narrow ones. Either way Tab goes through the whole question (blanks,
/// Back / Next, …) before the map, as it reads on a phone.
library;

import 'package:flutter/material.dart';

class QuestionWithMap extends StatelessWidget {
  final Widget question, map;
  final bool wide;
  const QuestionWithMap({super.key, required this.question, required this.map, required this.wide});

  @override
  Widget build(BuildContext context) {
    Widget part(double order, Widget child) => FocusTraversalOrder(order: NumericFocusOrder(order), child: FocusTraversalGroup(child: child));
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: wide
          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: part(1, question)),
              const SizedBox(width: 24),
              SizedBox(width: 260, child: part(2, map)),
            ])
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              part(1, question),
              const SizedBox(height: 16),
              part(2, map),
            ]),
    );
  }
}
