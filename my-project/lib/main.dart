import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // إعداد Google Mobile Ads
  await MobileAds.instance.initialize();

  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  RewardedAd? _rewardedAd;
  bool isAdReady = false;
  int points = 0;
  bool adAlreadyShownThisSession = false;

  late Database _db;

  final String rewardedAdUnitId = 'ca-app-pub-7359116936099131/4452070614';

  Future<void> initDb() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, "point_in_app.db");

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE points(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            total_points INTEGER
          )
        ''');
        await db.insert('points', {'total_points': 0});
      },
    );

    final result = await _db.query('points', limit: 1);
    if (result.isNotEmpty) {
      setState(() {
        points = result[0]['total_points'] ?? 0;
      });
    }
  }

  Future<void> updatePoints(int newPoints) async {
    await _db.update('points', {'total_points': newPoints}, where: 'id = ?', whereArgs: [1]);
    setState(() {
      points = newPoints;
    });
  }

  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          setState(() {
            _rewardedAd = ad;
            isAdReady = true;
          });
        },
        onAdFailedToLoad: (error) {
          setState(() {
            isAdReady = false;
          });
        },
      ),
    );
  }

  void _showRewardedAd() {
    if (_rewardedAd == null || adAlreadyShownThisSession) return;

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
      },
    );

    _rewardedAd!.show(onUserEarnedReward: (AdWithoutView ad, RewardItem reward) async {
      final newPoints = points + reward.amount.toInt();
      await updatePoints(newPoints);
    });

    _rewardedAd = null;
    adAlreadyShownThisSession = true;
    setState(() {
      isAdReady = false;
    });
  }

  @override
  void initState() {
    super.initState();
    initDb().then((_) => _loadRewardedAd());
  }

  @override
  void dispose() {
    _rewardedAd?.dispose();
    _db.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('نقاط التطبيق: $points'), centerTitle: true),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: isAdReady && !adAlreadyShownThisSession ? _showRewardedAd : null,
                child: Text(isAdReady ? 'شاهد إعلان مكافأة واحصل على نقطة' : 'جارٍ تحميل الإعلان...'),
              ),
              SizedBox(height: 20),
              Text(
                '⚠️ إعلانك الحقيقي (مرة واحدة لكل تشغيل)',
                style: TextStyle(fontSize: 12, color: Colors.redAccent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}