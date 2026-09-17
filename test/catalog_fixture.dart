import 'dart:convert';
import 'dart:io';
import 'package:aaaskola/catalog.dart';
import 'package:aaaskola/main.dart';
import 'package:aaaskola/progress.dart';

Map<String, dynamic> seedJson() =>
    jsonDecode(File('server/content-seed.json').readAsStringSync())
        as Map<String, dynamic>;
AaaSkolaApp testApp({ProgressController? progress}) => AaaSkolaApp(
  progress: progress,
  catalog: CatalogController(initial: SchoolCatalog.fromJson(seedJson())),
);
