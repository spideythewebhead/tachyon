class PackageInfo {
  PackageInfo({
    required this.name,
    required this.rootUri,
    required this.packageUri,
    required this.languageVersion,
  });

  factory PackageInfo.fromJson(Map<dynamic, dynamic> json) {
    return PackageInfo(
      name: json['name'] as String,
      rootUri: Uri.parse(json['rootUri'] as String),
      packageUri: json['packageUri'] == null ? null : Uri.parse(json['packageUri'] as String),
      languageVersion: json['languageVersion'] as String,
    );
  }

  final String name;
  final Uri rootUri;
  final Uri? packageUri;
  final String languageVersion;
}
