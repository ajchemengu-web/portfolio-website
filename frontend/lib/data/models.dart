/// Plain Dart data models mirroring the Flask API's JSON responses
/// (app/api/*.py `_serialize()` functions on the backend). Hand-written
/// fromJson/toJson rather than code-generated (json_serializable) so the
/// project has zero build_runner dependency — it compiles with nothing more
/// than the Flutter SDK.
library;

List<String> _stringList(dynamic value) =>
    (value as List? ?? const []).map((e) => e.toString()).toList();

DateTime? _dateOrNull(dynamic value) => value == null ? null : DateTime.tryParse(value as String);

/// Generic wrapper for the paginated list endpoints ("items"/"page"/
/// "page_size"/"total"/"total_pages").
class Paginated<T> {
  Paginated({required this.items, required this.page, required this.pageSize, required this.total, required this.totalPages});

  final List<T> items;
  final int page;
  final int pageSize;
  final int total;
  final int totalPages;

  factory Paginated.fromJson(Map<String, dynamic> json, T Function(Map<String, dynamic>) itemParser) {
    return Paginated<T>(
      items: (json['items'] as List? ?? const [])
          .map((e) => itemParser(Map<String, dynamic>.from(e as Map)))
          .toList(),
      page: json['page'] as int? ?? 1,
      pageSize: json['page_size'] as int? ?? 12,
      total: json['total'] as int? ?? 0,
      totalPages: json['total_pages'] as int? ?? 1,
    );
  }
}

class Milestone {
  Milestone({required this.id, required this.title, this.notes, this.milestoneDate, required this.isComplete});

  final String id;
  final String title;
  final String? notes;
  final DateTime? milestoneDate;
  final bool isComplete;

  factory Milestone.fromJson(Map<String, dynamic> json) => Milestone(
        id: json['id'] as String,
        title: json['title'] as String,
        notes: json['notes'] as String?,
        milestoneDate: _dateOrNull(json['milestone_date']),
        isComplete: json['is_complete'] as bool? ?? false,
      );
}

class ResearchProject {
  ResearchProject({
    required this.id,
    required this.slug,
    required this.title,
    this.category,
    this.abstractText,
    this.researchQuestion,
    this.motivation,
    this.objectives,
    this.methodology,
    this.results,
    this.futureWork,
    this.ethicsStatement,
    this.references = const [],
    required this.status,
    required this.progressPercentage,
    this.currentPhase,
    this.estimatedCompletion,
    required this.isDraft,
    this.publishedAt,
    this.milestones = const [],
  });

  final String id;
  final String slug;
  final String title;
  final String? category;
  final String? abstractText;
  final String? researchQuestion;
  final String? motivation;
  final String? objectives;
  final String? methodology;
  final String? results;
  final String? futureWork;
  final String? ethicsStatement;
  final List<String> references;
  final String status;
  final int progressPercentage;
  final String? currentPhase;
  final DateTime? estimatedCompletion;
  final bool isDraft;
  final DateTime? publishedAt;
  final List<Milestone> milestones;

  factory ResearchProject.fromJson(Map<String, dynamic> json) => ResearchProject(
        id: json['id'] as String,
        slug: json['slug'] as String,
        title: json['title'] as String,
        category: json['category'] as String?,
        abstractText: json['abstract'] as String?,
        researchQuestion: json['research_question'] as String?,
        motivation: json['motivation'] as String?,
        objectives: json['objectives'] as String?,
        methodology: json['methodology'] as String?,
        results: json['results'] as String?,
        futureWork: json['future_work'] as String?,
        ethicsStatement: json['ethics_statement'] as String?,
        references: _stringList(json['references']),
        status: json['status'] as String? ?? 'planning',
        progressPercentage: json['progress_percentage'] as int? ?? 0,
        currentPhase: json['current_phase'] as String?,
        estimatedCompletion: _dateOrNull(json['estimated_completion']),
        isDraft: json['is_draft'] as bool? ?? true,
        publishedAt: _dateOrNull(json['published_at']),
        milestones: (json['milestones'] as List? ?? const [])
            .map((e) => Milestone.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

class FileInfo {
  FileInfo({required this.id, required this.filename, required this.visibility, this.sizeBytes, this.downloadUrl});

  final String id;
  final String filename;
  final String visibility;
  final int? sizeBytes;
  final String? downloadUrl;

  factory FileInfo.fromJson(Map<String, dynamic> json) => FileInfo(
        id: json['id'] as String,
        filename: json['filename'] as String,
        visibility: json['visibility'] as String? ?? 'private',
        sizeBytes: json['size_bytes'] as int?,
        downloadUrl: json['download_url'] as String?,
      );
}

class Publication {
  Publication({
    required this.id,
    required this.slug,
    required this.title,
    required this.publicationType,
    this.abstractText,
    this.citation,
    this.authors = const [],
    this.publicationDate,
    this.doi,
    this.file,
  });

  final String id;
  final String slug;
  final String title;
  final String publicationType;
  final String? abstractText;
  final String? citation;
  final List<String> authors;
  final DateTime? publicationDate;
  final String? doi;
  final FileInfo? file;

  factory Publication.fromJson(Map<String, dynamic> json) => Publication(
        id: json['id'] as String,
        slug: json['slug'] as String,
        title: json['title'] as String,
        publicationType: json['publication_type'] as String? ?? 'preprint',
        abstractText: json['abstract'] as String?,
        citation: json['citation'] as String?,
        authors: _stringList(json['authors']),
        publicationDate: _dateOrNull(json['publication_date']),
        doi: json['doi'] as String?,
        file: json['file'] == null ? null : FileInfo.fromJson(Map<String, dynamic>.from(json['file'] as Map)),
      );
}

class SoftwareProject {
  SoftwareProject({
    required this.id,
    required this.slug,
    required this.title,
    this.description,
    this.features = const [],
    this.architecture,
    this.technologies = const [],
    this.githubUrl,
    this.liveDemoUrl,
    this.screenshots = const [],
    this.lessonsLearned,
    this.futureImprovements,
    required this.status,
    required this.progressPercentage,
  });

  final String id;
  final String slug;
  final String title;
  final String? description;
  final List<String> features;
  final String? architecture;
  final List<String> technologies;
  final String? githubUrl;
  final String? liveDemoUrl;
  final List<String> screenshots;
  final String? lessonsLearned;
  final String? futureImprovements;
  final String status;
  final int progressPercentage;

  factory SoftwareProject.fromJson(Map<String, dynamic> json) => SoftwareProject(
        id: json['id'] as String,
        slug: json['slug'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        features: _stringList(json['features']),
        architecture: json['architecture'] as String?,
        technologies: _stringList(json['technologies']),
        githubUrl: json['github_url'] as String?,
        liveDemoUrl: json['live_demo_url'] as String?,
        screenshots: _stringList(json['screenshots']),
        lessonsLearned: json['lessons_learned'] as String?,
        futureImprovements: json['future_improvements'] as String?,
        status: json['status'] as String? ?? 'active',
        progressPercentage: json['progress_percentage'] as int? ?? 0,
      );
}

class BlogPost {
  BlogPost({
    required this.id,
    required this.slug,
    required this.title,
    this.excerpt,
    this.contentMarkdown,
    this.category,
    this.tags = const [],
    required this.status,
    this.coverImageUrl,
    this.publishedAt,
  });

  final String id;
  final String slug;
  final String title;
  final String? excerpt;
  final String? contentMarkdown;
  final String? category;
  final List<String> tags;
  final String status;
  final String? coverImageUrl;
  final DateTime? publishedAt;

  factory BlogPost.fromJson(Map<String, dynamic> json) => BlogPost(
        id: json['id'] as String,
        slug: json['slug'] as String,
        title: json['title'] as String,
        excerpt: json['excerpt'] as String?,
        contentMarkdown: json['content_markdown'] as String?,
        category: json['category'] as String?,
        tags: _stringList(json['tags']),
        status: json['status'] as String? ?? 'draft',
        coverImageUrl: json['cover_image_url'] as String?,
        publishedAt: _dateOrNull(json['published_at']),
      );
}

class Skill {
  Skill({required this.id, required this.name, required this.category, required this.proficiencyLevel, this.yearsExperience});

  final String id;
  final String name;
  final String category;
  final int proficiencyLevel;
  final double? yearsExperience;

  factory Skill.fromJson(Map<String, dynamic> json) => Skill(
        id: json['id'] as String,
        name: json['name'] as String,
        category: json['category'] as String,
        proficiencyLevel: json['proficiency_level'] as int? ?? 3,
        yearsExperience: (json['years_experience'] as num?)?.toDouble(),
      );
}

class TimelineEvent {
  TimelineEvent({required this.id, required this.title, this.description, required this.eventType, required this.eventDate, this.photoUrl});

  final String id;
  final String title;
  final String? description;
  final String eventType;
  final DateTime eventDate;
  final String? photoUrl;

  factory TimelineEvent.fromJson(Map<String, dynamic> json) => TimelineEvent(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        eventType: json['event_type'] as String,
        eventDate: DateTime.parse(json['event_date'] as String),
        photoUrl: json['photo_url'] as String?,
      );
}

class Achievement {
  Achievement({required this.id, required this.title, this.description, required this.category, this.issuer, this.dateAwarded});

  final String id;
  final String title;
  final String? description;
  final String category;
  final String? issuer;
  final DateTime? dateAwarded;

  factory Achievement.fromJson(Map<String, dynamic> json) => Achievement(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        category: json['category'] as String,
        issuer: json['issuer'] as String?,
        dateAwarded: _dateOrNull(json['date_awarded']),
      );
}

class GalleryItem {
  GalleryItem({required this.id, this.title, this.description, required this.category, required this.imageUrl, this.takenAt});

  final String id;
  final String? title;
  final String? description;
  final String category;
  final String imageUrl;
  final DateTime? takenAt;

  factory GalleryItem.fromJson(Map<String, dynamic> json) => GalleryItem(
        id: json['id'] as String,
        title: json['title'] as String?,
        description: json['description'] as String?,
        category: json['category'] as String,
        imageUrl: json['image_url'] as String,
        takenAt: _dateOrNull(json['taken_at']),
      );
}

class DownloadFile {
  DownloadFile({
    required this.id,
    required this.filename,
    this.description,
    this.version,
    this.sizeBytes,
    this.category,
    required this.visibility,
    required this.downloadCount,
  });

  final String id;
  final String filename;
  final String? description;
  final String? version;
  final int? sizeBytes;
  final String? category;
  final String visibility;
  final int downloadCount;

  factory DownloadFile.fromJson(Map<String, dynamic> json) => DownloadFile(
        id: json['id'] as String,
        filename: json['filename'] as String,
        description: json['description'] as String?,
        version: json['version'] as String?,
        sizeBytes: json['size_bytes'] as int?,
        category: json['category'] as String?,
        visibility: json['visibility'] as String? ?? 'public',
        downloadCount: json['download_count'] as int? ?? 0,
      );
}
