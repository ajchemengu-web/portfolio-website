/// Bundled placeholder content shown whenever the backend API can't be
/// reached (most importantly: before it has been deployed at all). This
/// keeps the site fully presentable — for a college admissions reviewer or
/// recruiter following a shared link — even during early development, and
/// gives a concrete shape for the real content to replace via the admin
/// dashboard later.
library;

import 'models.dart';

final List<ResearchProject> placeholderResearch = [
  ResearchProject(
    id: 'r1',
    slug: 'federated-learning-for-edge-intrusion-detection',
    title: 'Federated Learning for Edge-Based Intrusion Detection',
    category: 'AI & Cybersecurity',
    abstractText:
        'This project investigates whether a federated learning approach can match centrally-trained '
        'intrusion detection models in accuracy while keeping raw network traffic on-device, addressing '
        'both bandwidth and privacy constraints common to IoT deployments.',
    researchQuestion:
        'Can a federated model trained across distributed edge nodes achieve intrusion-detection accuracy '
        'comparable to a centrally trained baseline, without transmitting raw packet data off-device?',
    motivation:
        'Centralised intrusion-detection pipelines require shipping raw traffic to a server, which is both a '
        'bandwidth cost and a privacy liability for edge/IoT networks.',
    objectives: 'Build a federated averaging pipeline, benchmark against a centralised baseline on NSL-KDD '
        'and a synthetic IoT traffic set, and measure the accuracy/communication-cost trade-off.',
    methodology: 'Simulated federated clients using Flower, non-IID data partitioning across simulated edge '
        'nodes, and a lightweight 1D-CNN classifier tuned for constrained hardware.',
    results: 'Early rounds show federated averaging within 2.1% accuracy of the centralised baseline after '
        '40 communication rounds, with an 89% reduction in data transmitted off-device.',
    futureWork: 'Extend to differential-privacy-preserving aggregation and evaluate against adversarial '
        'poisoning of client updates.',
    ethicsStatement:
        'All traffic datasets used are public research benchmarks; no real user traffic is collected or stored.',
    references: [
      'McMahan et al., "Communication-Efficient Learning of Deep Networks from Decentralized Data", 2017',
      'NSL-KDD Dataset, University of New Brunswick',
    ],
    status: 'active',
    progressPercentage: 65,
    currentPhase: 'Model benchmarking against centralised baseline',
    isDraft: false,
    milestones: [
      Milestone(id: 'm1', title: 'Literature review complete', isComplete: true),
      Milestone(id: 'm2', title: 'Federated pipeline implemented', isComplete: true),
      Milestone(id: 'm3', title: 'Baseline comparison benchmarks', isComplete: false),
    ],
  ),
  ResearchProject(
    id: 'r2',
    slug: 'explainable-anomaly-detection-scada',
    title: 'Explainable Anomaly Detection for SCADA Systems',
    category: 'Cybersecurity',
    abstractText:
        'Applies SHAP-based explainability to anomaly detection models protecting industrial control systems, '
        'so operators can trust and act on model alerts rather than treating them as an opaque black box.',
    status: 'planning',
    progressPercentage: 15,
    currentPhase: 'Dataset acquisition and threat-model definition',
    isDraft: false,
  ),
  ResearchProject(
    id: 'r3',
    slug: 'transfer-learning-low-resource-swahili-nlp',
    title: 'Transfer Learning for Low-Resource Swahili NLP',
    category: 'Artificial Intelligence',
    abstractText:
        'Explores cross-lingual transfer from high-resource languages to improve Swahili text classification '
        'and named-entity recognition under limited labelled-data conditions.',
    status: 'completed',
    progressPercentage: 100,
    currentPhase: 'Write-up for publication',
    isDraft: false,
  ),
];

final List<Publication> placeholderPublications = [
  Publication(
    id: 'p1',
    slug: 'federated-ids-preprint-2026',
    title: 'Federated Averaging for Lightweight Network Intrusion Detection at the Edge',
    publicationType: 'preprint',
    abstractText: 'A preprint describing the federated intrusion-detection architecture and early benchmark '
        'results referenced in the accompanying research project.',
    citation: 'Juma, A. (2026). Federated Averaging for Lightweight Network Intrusion Detection at the Edge. '
        'Preprint.',
    authors: ['Ali Juma'],
    publicationDate: DateTime(2026, 3, 14),
  ),
  Publication(
    id: 'p2',
    slug: 'swahili-transfer-learning-report',
    title: 'Cross-Lingual Transfer for Swahili Text Classification: A Technical Report',
    publicationType: 'technical_report',
    abstractText: 'Technical report documenting methodology and results for the low-resource Swahili NLP project.',
    citation: 'Juma, A. (2025). Cross-Lingual Transfer for Swahili Text Classification. Technical Report.',
    authors: ['Ali Juma'],
    publicationDate: DateTime(2025, 11, 2),
  ),
];

final List<SoftwareProject> placeholderProjects = [
  SoftwareProject(
    id: 'sp1',
    slug: 'research-portfolio-platform',
    title: 'Research Portfolio Platform (this website)',
    description:
        'A self-managed research portfolio and CMS: Flutter Web front end, Flask REST API, JWT-authenticated '
        'admin dashboard, and Supabase Postgres/Storage backend.',
    features: [
      'Public research, publications, projects, blog, timeline, and gallery pages',
      'Admin dashboard for full content management with no code changes',
      'Secure file uploads with visibility controls (public / view-only / private)',
    ],
    architecture: 'Flutter Web (Riverpod + GoRouter) talking to a Flask REST API over JWT bearer auth, backed '
        'by Supabase Postgres and Supabase Storage, deployed on Railway.',
    technologies: ['Flutter', 'Dart', 'Riverpod', 'Flask', 'PostgreSQL', 'Supabase', 'Railway'],
    githubUrl: 'https://github.com/your-handle/portfolio',
    status: 'active',
    progressPercentage: 80,
  ),
  SoftwareProject(
    id: 'sp2',
    slug: 'packet-sentry',
    title: 'PacketSentry — Lightweight Traffic Anomaly CLI',
    description: 'A command-line tool that scores live network traffic against a pre-trained anomaly model '
        'and raises alerts for suspicious flows, built to support the SCADA anomaly-detection research.',
    technologies: ['Python', 'Scapy', 'scikit-learn'],
    githubUrl: 'https://github.com/your-handle/packet-sentry',
    status: 'active',
    progressPercentage: 55,
  ),
];

final List<BlogPost> placeholderBlogPosts = [
  BlogPost(
    id: 'b1',
    slug: 'why-federated-learning-for-iot-security',
    title: 'Why Federated Learning Makes Sense for IoT Security',
    excerpt: 'Notes on why keeping raw traffic on-device changes the privacy and bandwidth calculus for '
        'intrusion detection at the edge.',
    category: 'Research Notes',
    tags: ['federated-learning', 'iot', 'security'],
    status: 'published',
    publishedAt: DateTime(2026, 4, 2),
  ),
  BlogPost(
    id: 'b2',
    slug: 'reading-notes-attention-is-all-you-need',
    title: 'Reading Notes: "Attention Is All You Need"',
    excerpt: 'A close read of the original Transformer paper, with the parts that took me longest to '
        'actually understand.',
    category: 'Learning Reflections',
    tags: ['nlp', 'transformers', 'papers'],
    status: 'published',
    publishedAt: DateTime(2026, 2, 18),
  ),
];

final Map<String, List<Skill>> placeholderSkills = {
  'programming_languages': [
    Skill(id: 's1', name: 'Python', category: 'programming_languages', proficiencyLevel: 5, yearsExperience: 4),
    Skill(id: 's2', name: 'Dart', category: 'programming_languages', proficiencyLevel: 4, yearsExperience: 2),
    Skill(id: 's3', name: 'C++', category: 'programming_languages', proficiencyLevel: 3, yearsExperience: 2),
  ],
  'artificial_intelligence': [
    Skill(id: 's4', name: 'PyTorch', category: 'artificial_intelligence', proficiencyLevel: 4, yearsExperience: 3),
    Skill(id: 's5', name: 'scikit-learn', category: 'artificial_intelligence', proficiencyLevel: 5, yearsExperience: 4),
  ],
  'cybersecurity': [
    Skill(id: 's6', name: 'Network Traffic Analysis', category: 'cybersecurity', proficiencyLevel: 4, yearsExperience: 2),
    Skill(id: 's7', name: 'Threat Modelling', category: 'cybersecurity', proficiencyLevel: 3, yearsExperience: 2),
  ],
  'cloud': [
    Skill(id: 's8', name: 'Supabase', category: 'cloud', proficiencyLevel: 4, yearsExperience: 1),
    Skill(id: 's9', name: 'Railway', category: 'cloud', proficiencyLevel: 3, yearsExperience: 1),
  ],
};

final List<TimelineEvent> placeholderTimeline = [
  TimelineEvent(
    id: 't1',
    title: 'Began undergraduate studies',
    description: 'Started a Bachelor\'s degree with a focus on AI, Machine Learning, and Cybersecurity.',
    eventType: 'education',
    eventDate: DateTime(2023, 9, 1),
  ),
  TimelineEvent(
    id: 't2',
    title: 'Started the Federated Intrusion Detection research project',
    eventType: 'research_milestone',
    eventDate: DateTime(2025, 9, 15),
  ),
  TimelineEvent(
    id: 't3',
    title: 'Research internship',
    description: 'Summer research internship applying ML to network security telemetry.',
    eventType: 'internship',
    eventDate: DateTime(2026, 6, 1),
  ),
];

final List<Achievement> placeholderAchievements = [
  Achievement(
    id: 'a1',
    title: 'Dean\'s List',
    category: 'academic',
    issuer: 'University',
    dateAwarded: DateTime(2025, 12, 20),
  ),
  Achievement(
    id: 'a2',
    title: 'National Cybersecurity CTF — 2nd Place',
    category: 'competition',
    issuer: 'National Cybersecurity Association',
    dateAwarded: DateTime(2025, 10, 5),
  ),
];

final List<GalleryItem> placeholderGallery = [
  GalleryItem(
    id: 'g1',
    title: 'Presenting at the departmental research symposium',
    category: 'conference',
    imageUrl: 'https://images.unsplash.com/photo-1560439514-4e9645039924?w=800',
  ),
  GalleryItem(
    id: 'g2',
    title: 'Lab session — edge device benchmarking',
    category: 'laboratory',
    imageUrl: 'https://images.unsplash.com/photo-1518770660439-4636190af475?w=800',
  ),
];

final List<DownloadFile> placeholderDownloads = [
  DownloadFile(
    id: 'd1',
    filename: 'Ali_Juma_CV.pdf',
    description: 'Current curriculum vitae',
    version: 'v3',
    sizeBytes: 245000,
    category: 'cv',
    visibility: 'public',
    downloadCount: 128,
  ),
  DownloadFile(
    id: 'd2',
    filename: 'Federated_IDS_Preprint.pdf',
    description: 'Preprint PDF for the federated intrusion-detection paper',
    version: 'v1',
    sizeBytes: 1_200_000,
    category: 'paper',
    visibility: 'public',
    downloadCount: 34,
  ),
];

const String placeholderBio = '''
I'm a researcher and developer focused on the intersection of Artificial Intelligence, Machine Learning, and
Cybersecurity — with a particular interest in building systems that are both intelligent and trustworthy:
models that make good decisions and can explain them, and infrastructure that's secure by design rather than
by afterthought.

My current research explores federated and privacy-preserving machine learning for network security, and I'm
increasingly interested in explainability as a first-class requirement for any model deployed in a
security-critical setting.

Outside of research, I build software end-to-end — from data pipelines to the interfaces people actually use —
because I think the best research is grounded in systems that work in practice, not just on paper.
''';

const String placeholderResearchVision = '''
My long-term research vision is to make privacy-preserving machine learning practical for security-critical,
resource-constrained environments — from IoT networks to industrial control systems — without asking operators
to trade away explainability or performance to get there.
''';
