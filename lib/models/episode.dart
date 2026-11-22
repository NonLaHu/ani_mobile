/// Represents an individual anime episode
class Episode {
  final String id;
  final String animeId;
  final int number;
  final String title;
  final String? thumbnail;
  final bool isFiller;
  final bool isDub;
  final bool isSub;
  final String? airDate;

  const Episode({
    required this.id,
    required this.animeId,
    required this.number,
    required this.title,
    this.thumbnail,
    this.isFiller = false,
    this.isDub = false,
    this.isSub = true,
    this.airDate,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'animeId': animeId,
    'number': number,
    'title': title,
    'thumbnail': thumbnail,
    'isFiller': isFiller,
    'isDub': isDub,
    'isSub': isSub,
    'airDate': airDate,
  };

  factory Episode.fromJson(Map<String, dynamic> json) => Episode(
    id: json['id'] as String,
    animeId: json['animeId'] as String,
    number: json['number'] as int? ?? 1,
    title: json['title'] as String? ?? 'Episode ${json['number']}',
    thumbnail: json['thumbnail'] as String?,
    isFiller: json['isFiller'] as bool? ?? false,
    isDub: json['isDub'] as bool? ?? false,
    isSub: json['isSub'] as bool? ?? true,
    airDate: json['airDate'] as String?,
  );

  Episode copyWith({
    String? id,
    String? animeId,
    int? number,
    String? title,
    String? thumbnail,
    bool? isFiller,
    bool? isDub,
    bool? isSub,
    String? airDate,
  }) {
    return Episode(
      id: id ?? this.id,
      animeId: animeId ?? this.animeId,
      number: number ?? this.number,
      title: title ?? this.title,
      thumbnail: thumbnail ?? this.thumbnail,
      isFiller: isFiller ?? this.isFiller,
      isDub: isDub ?? this.isDub,
      isSub: isSub ?? this.isSub,
      airDate: airDate ?? this.airDate,
    );
  }

  @override
  String toString() => 'Episode $number: $title (ID: $id, Dub: $isDub)';
}
