// What happens in each of the devlog's lab episodes (tool/lab_film.dart,
// docs/media/devlog.md). Each one opens the bench where the last one left
// it, so the five read as one level being built: the dog's.

import 'package:flutter/material.dart' show DropdownButton, Icons;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/level/dog_levels.dart';
import 'package:waraya/level/level.dart';
import 'package:waraya/level/playthrough.dart';

import 'lab_film.dart';

/// The room the dog's level is built in, before anything is in it: the
/// floor, the two walls and the way out of `DogLevels.theDog`.
Level _room({List<Rect> more = const [], List<DogSpec> dogs = const []}) =>
    Level(
      id: 'the-dog',
      name: 'الكلب',
      teaches: 'الكلب بيجري ورا أي حاجة بتتحرك. ماضيك كمان.',
      delaySeconds: 6,
      spawnX: -700,
      floorTop: 620,
      blocks: [
        const Rect.fromLTRB(-1400, 620, 1600, 2200),
        const Rect.fromLTRB(-1040, 140, -1000, 620),
        const Rect.fromLTRB(1300, 140, 1340, 620),
        ...more,
      ],
      dogs: dogs,
      goal: const Rect.fromLTRB(1100, 548, 1180, 620),
    );

const _d = LogicalKeyboardKey.keyD;

// Closer looks at the lab (1920 x 1080), each 16:9 like the screen they
// fill: the buttons, the panel the numbers go in, and the floor.
const _toolbar = Rect.fromLTWH(0, 0, 1280, 720);
const _panel = Rect.fromLTWH(800, 60, 1120, 630);
const _floor = Rect.fromLTWH(200, 250, 1450, 816);
const _gate = Rect.fromLTWH(0, 800, 500, 281);

/// The dog of `DogLevels.theDog`, where it is in the level that ships.
const _dog = DogSpec(
  area: Rect.fromLTRB(0, 560, 900, 620),
  home: 650,
  backTo: -300,
);

/// Its two steps and the ledge over its ground.
const _steps = [
  Rect.fromLTRB(-660, 510, -500, 524),
  Rect.fromLTRB(-500, 400, -340, 414),
  Rect.fromLTRB(-340, 284, 150, 304),
];

/// «The dog first»'s room before its door and its button
/// (`DogLevels.theDogFirst`): the floor, the walls, the dog, the way out.
final Level _secondRoom = Level(
  id: 'the-dog-first',
  name: 'الكلب الأول',
  teaches: 'ماضيك بيعمل الحاجات بالترتيب اللي عملتها بيه.',
  delaySeconds: 6,
  spawnX: -200,
  floorTop: 620,
  blocks: const [
    Rect.fromLTRB(-1400, 620, 1400, 2200),
    Rect.fromLTRB(-800, 140, -760, 620),
    Rect.fromLTRB(900, 140, 940, 620),
  ],
  dogs: const [
    DogSpec(area: Rect.fromLTRB(0, 560, 500, 620), home: 300, backTo: -190),
  ],
  goal: const Rect.fromLTRB(720, 548, 800, 620),
);

/// Up the steps and along the ledge: the start of the dog's answer.
const _upAndAlong = [
  Move.right(0.55, jump: true),
  Move.right(0.55, jump: true),
  Move.right(0.25),
  Move.right(0.55, jump: true),
  Move.right(2.0),
];

final episodes = <Episode>[
  Episode(
    number: 1,
    slug: 'lab-1-a-dog',
    start: _room(),
    play: (film) async {
      film.say(
        'بعمل لعبة لوحدي… ودي الورشة',
        'كل مرحلة بتتبني هنا الأول، بمستطيلات',
      );
      await film.wait(2.6);
      film.say('النهارده: عدو جديد');
      film.look(_toolbar);
      await film.click(find.text('+ dog'), seconds: 0.8);
      await film.wait(0.5);
      film.say('كلب شارع', 'أرضه من هنا لهنا، وبيجري ورا أي حاجة بتتحرك');
      film.look(_panel);
      await film.type('x', '0');
      await film.type('y', '560');
      await film.type('width', '900');
      await film.wait(0.8);
      film.say('أول تجربة');
      film.look(_toolbar);
      await film.click(find.byIcon(Icons.play_arrow), seconds: 0.7);
      film.look(_floor);
      await film.wait(0.6);
      await film.hold([_d], 3.2);
      await film.wait(1.2);
      film.say('اتعضّيت…', 'زي ما اتعضّيت وانا صغير بالظبط');
      await film.wait(2.4);
      film.say('بكرة: هستخبى منه فوق');
      film.look();
      await film.wait(2);
    },
  ),
  Episode(
    number: 2,
    slug: 'lab-2-hide-up-there',
    start: _room(dogs: const [_dog]),
    play: (film) async {
      film.say('امبارح الكلب عضّني', 'النهارده: هطلع فوقه');
      await film.wait(2.2);
      film.say('سلّمتين…');
      for (final (i, step) in _steps.indexed) {
        if (i == 2) film.say('ورفّ فوق أرضه', 'هو يجري تحت… ومش هيطولني');
        film.look(_toolbar);
        await film.click(find.text('+ wall / floor'), seconds: 0.45);
        film.look(_panel);
        await film.type('x', '${step.left.toInt()}');
        await film.type('y', '${step.top.toInt()}');
        await film.type('width', '${step.width.toInt()}');
        await film.type('height', '${step.height.toInt()}');
      }
      film.look();
      await film.wait(0.8);
      film.say('نجرّب');
      film.look(_toolbar);
      await film.click(find.byIcon(Icons.play_arrow), seconds: 0.5);
      film.look(_floor);
      await film.run(
        [
          ..._upAndAlong,
          const Move(3.4),
          const Move.left(2.6),
          const Move.right(4),
        ],
        cues: {
          3.9: () => film.say('فوق… مش طايلني', 'بيجري تحتي ويهوهو'),
          6.4: () => film.say('بس لازم أنزل في الآخر'),
          9.6: () =>
              film.say('وهو مستنيني', 'وقفت… والكلب مبيجريش ورا حد واقف'),
        },
      );
      await film.wait(1.2);
      film.say('طب لو حد تاني هو اللي اتحرك؟', 'بكرة');
      film.look();
      await film.wait(2.4);
    },
  ),
  Episode(
    number: 3,
    slug: 'lab-3-a-companion',
    start: DogLevels.theDog,
    play: (film) async {
      film.say(
        'الحمد لله معانا ونيس',
        'ظلّنا: بيعيد كل حاجة عملتها… بعد ٦ ثواني',
      );
      await film.wait(2.6);
      film.say('هسجّل الحل', 'الزرار الأحمر: اللعبة بتحفظ اللي هعمله');
      film.look(_toolbar);
      await film.click(find.byIcon(Icons.fiber_manual_record), seconds: 0.6);
      film.look(_floor);
      final answer = DogLevels.theDog.solution;
      await film.run(
        answer,
        cues: {
          3.9: () => film.say('أتمشّى رايح جاي فوق', 'على الفاضي… حالياً'),
          7.6: () => film.say('وأنزل'),
          10.4: () =>
              film.say('وبعد ٦ ثواني… ماضيّا اللي بيتمشّى', 'والكلب يجري وراه'),
        },
      );
      await film.wait(1.4);
      film.say('عدّيت', 'والحل اتحفظ');
      film.look(_panel);
      await film.wait(2.2);
      film.say('بس لسه في الورشة', 'لحد ما حد يلعبها بإيده الأول');
      film.look(_gate);
      await film.wait(2.6);
      film.look();
      await film.wait(0.6);
    },
  ),
  Episode(
    number: 4,
    slug: 'lab-4-the-dog-first',
    start: _secondRoom,
    play: (film) async {
      film.say('المرحلة الرابعة', 'نفس الكلب… بس فيه باب');
      await film.wait(2.2);
      film.say('باب بعد أرض الكلب');
      film.look(_toolbar);
      await film.click(find.text('+ door'), seconds: 0.45);
      film.look(_panel);
      await film.type('x', '600');
      await film.type('y', '140');
      await film.type('height', '480');
      film.say('وزرار يفتحه… ورايا', 'بعيد عن عين الكلب');
      film.look(_toolbar);
      await film.click(find.text('+ plate'), seconds: 0.45);
      film.look(_panel);
      await film.type('x', '-300');
      await film.type('y', '608');
      await film.type('width', '60');
      await film.click(find.byType(DropdownButton<String>), seconds: 0.4);
      await film.wait(0.3);
      await film.click(find.text('gate').last, seconds: 0.35);
      film.look();
      await film.wait(0.8);
      film.say('أدوس الزرار… وأجري؟');
      film.look(_toolbar);
      await film.click(find.byIcon(Icons.play_arrow), seconds: 0.5);
      film.look(_floor);
      await film.run(
        const [Move.left(0.45), Move(1.0), Move.right(4.5)],
        cues: {1.6: () => film.say('الباب مفتوح… والكلب صاحي')},
      );
      await film.wait(1);
      film.say('ماضيّا على الزرار', 'بس مفيش حد بيلهي الكلب');
      await film.wait(2.2);
      film.say(
        'ماضيك بيعمل الحاجات بالترتيب',
        'يبقى الكلب الأول… وبعدين الزرار',
      );
      film.look(_toolbar);
      await film.click(find.byIcon(Icons.edit), seconds: 0.5);
      await film.click(find.byIcon(Icons.fiber_manual_record), seconds: 0.5);
      film.look(_floor);
      await film.run(
        DogLevels.theDogFirst.solution,
        cues: {
          0.4: () => film.say('الأول: أتمشّى قدّامه', 'على الفاضي'),
          4.0: () => film.say('وبعدين الزرار'),
          6.0: () => film.say('وأجري', 'ماضيّا بيتمشّى… والكلب وراه'),
          10.4: () => film.say('وأستنى عند الباب', 'لحد ما ماضيّا يرجع للزرار'),
        },
        until: () => film.statusSays('solution kept'),
      );
      await film.wait(1.2);
      film.say('عدّيت', 'والحل اتحفظ');
      film.look(_panel);
      await film.wait(2.2);
      film.say('مرحلة رابعة للكلب', 'فاضل حد يلعبها بإيده');
      film.look();
      await film.wait(2.2);
    },
  ),
];
