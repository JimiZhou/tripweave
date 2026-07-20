import 'models.dart';

enum CreationStep {
  import,
  curate,
  analyze,
  templates,
  preview,
  timeline,
  export,
}

enum AgentEventKind { thought, action, observation, completed, error }

class AgentEvent {
  const AgentEvent({
    required this.kind,
    required this.message,
    required this.createdAt,
  });

  final AgentEventKind kind;
  final String message;
  final DateTime createdAt;
}

class AgentClipPlan {
  const AgentClipPlan({
    required this.mediaId,
    required this.durationMs,
    required this.caption,
    this.startMs = 0,
  });

  final String mediaId;
  final int durationMs;
  final String caption;
  final int startMs;

  Map<String, Object> toJson() => {
    'mediaId': mediaId,
    'durationMs': durationMs,
    'caption': caption,
    'startMs': startMs,
  };
}

class AgentEditPlan {
  const AgentEditPlan({
    required this.title,
    required this.style,
    required this.ratio,
    required this.musicId,
    required this.clips,
  });

  final String title;
  final String style;
  final VlogRatio ratio;
  final String musicId;
  final List<AgentClipPlan> clips;

  int get totalDurationMs =>
      clips.fold(0, (total, clip) => total + clip.durationMs);

  Map<String, Object> toJson() => {
    'title': title,
    'style': style,
    'ratio': ratio.name,
    'musicId': musicId,
    'totalDurationMs': totalDurationMs,
    'clips': clips.map((clip) => clip.toJson()).toList(),
  };
}

class AgentTemplateProposal {
  const AgentTemplateProposal({
    required this.id,
    required this.name,
    required this.description,
    required this.rationale,
    required this.accent,
    required this.plan,
  });

  final String id;
  final String name;
  final String description;
  final String rationale;
  final String accent;
  final AgentEditPlan plan;
}

class AgentRunResult {
  const AgentRunResult({
    required this.plan,
    required this.summary,
    this.renderedPath,
    this.validation,
  });

  final AgentEditPlan plan;
  final String summary;
  final String? renderedPath;
  final String? validation;
}
