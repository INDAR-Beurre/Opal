class Artist {
  final String id;
  final String name;
  final String? thumbnailUrl;
  final String? subscriberCount;

  const Artist({
    required this.id,
    required this.name,
    this.thumbnailUrl,
    this.subscriberCount,
  });
}
