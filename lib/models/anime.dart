/// Represents an Anime series or movie
class Anime {
  final String id;
  final String title;
  final String? japaneseTitle;
  final String coverImage;
  final String? bannerImage;
  final String synopsis;
  final List<String> genres;
  final String status; // 'Ongoing', 'Completed', etc.
  final int totalEpisodes;
  final String? releaseYear;
  final String type; // 'TV', 'Movie', 'OVA', 'Special'
  final bool hasSub;
  final bool hasDub;
  final double? rating; // 0.0 - 10.0
  final Map<String, dynamic> extraData;

  const Anime({
    required this.id,
    required this.title,
    this.japaneseTitle,
    required this.coverImage,
    this.bannerImage,
    required this.synopsis,
    this.genres = const [],
    this.status = 'Unknown',
    this.totalEpisodes = 0,
    this.releaseYear,
    this.type = 'TV',
    this.hasSub = true,
    this.hasDub = false,
    this.rating,
    this.extraData = const {},
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'japaneseTitle': japaneseTitle,
    'coverImage': coverImage,
    'bannerImage': bannerImage,
    'synopsis': synopsis,
    'genres': genres,
    'status': status,
    'totalEpisodes': totalEpisodes,
    'releaseYear': releaseYear,
    'type': type,
    'hasSub': hasSub,
    'hasDub': hasDub,
    'rating': rating,
    'extraData': extraData,
  };

  factory Anime.fromJson(Map<String, dynamic> json) => Anime(
    id: json['id'] as String,
    title: json['title'] as String,
    japaneseTitle: json['japaneseTitle'] as String?,
    coverImage: json['coverImage'] as String? ?? '',
    bannerImage: json['bannerImage'] as String?,
    synopsis: json['synopsis'] as String? ?? 'No synopsis available.',
    genres: (json['genres'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const [],
    status: json['status'] as String? ?? 'Unknown',
    totalEpisodes: json['totalEpisodes'] as int? ?? 0,
    releaseYear: json['releaseYear'] as String?,
    type: json['type'] as String? ?? 'TV',
    hasSub: json['hasSub'] as bool? ?? true,
    hasDub: json['hasDub'] as bool? ?? false,
    rating: (json['rating'] as num?)?.toDouble(),
    extraData: (json['extraData'] as Map<String, dynamic>?) ?? const {},
  );

  Anime copyWith({
    String? id,
    String? title,
    String? japaneseTitle,
    String? coverImage,
    String? bannerImage,
    String? synopsis,
    List<String>? genres,
    String? status,
    int? totalEpisodes,
    String? releaseYear,
    String? type,
    bool? hasSub,
    bool? hasDub,
    double? rating,
    Map<String, dynamic>? extraData,
  }) {
    return Anime(
      id: id ?? this.id,
      title: title ?? this.title,
      japaneseTitle: japaneseTitle ?? this.japaneseTitle,
      coverImage: coverImage ?? this.coverImage,
      bannerImage: bannerImage ?? this.bannerImage,
      synopsis: synopsis ?? this.synopsis,
      genres: genres ?? this.genres,
      status: status ?? this.status,
      totalEpisodes: totalEpisodes ?? this.totalEpisodes,
      releaseYear: releaseYear ?? this.releaseYear,
      type: type ?? this.type,
      hasSub: hasSub ?? this.hasSub,
      hasDub: hasDub ?? this.hasDub,
      rating: rating ?? this.rating,
      extraData: extraData ?? this.extraData,
    );
  }

  @override
  String toString() => 'Anime($title, ID: $id, $status)';
}
