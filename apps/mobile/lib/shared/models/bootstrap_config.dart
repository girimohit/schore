class BootstrapConfig {
  final UserModel user;
  final SchoolModel school;
  final BrandingModel branding;
  final FeatureFlagsModel featureFlags;
  final List<String> permissions;
  final AppVersionModel appVersion;

  BootstrapConfig({
    required this.user,
    required this.school,
    required this.branding,
    required this.featureFlags,
    required this.permissions,
    required this.appVersion,
  });

  factory BootstrapConfig.fromJson(Map<String, dynamic> json) {
    return BootstrapConfig(
      user: UserModel.fromJson(json['user']),
      school: SchoolModel.fromJson(json['school']),
      branding: BrandingModel.fromJson(json['branding'] ?? {}),
      featureFlags: FeatureFlagsModel.fromJson(json['featureFlags'] ?? {}),
      permissions: List<String>.from(json['permissions'] ?? []),
      appVersion: AppVersionModel.fromJson(json['appVersion'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user': user.toJson(),
      'school': school.toJson(),
      'branding': branding.toJson(),
      'featureFlags': featureFlags.toJson(),
      'permissions': permissions,
      'appVersion': appVersion.toJson(),
    };
  }
}

class UserModel {
  final String id;
  final String email;
  final String role;

  UserModel({required this.id, required this.email, required this.role});

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'email': email, 'role': role};
}

class SchoolModel {
  final String id;
  final String name;
  final String code;

  SchoolModel({required this.id, required this.name, required this.code});

  factory SchoolModel.fromJson(Map<String, dynamic> json) {
    return SchoolModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      code: json['code'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'code': code};
}

class BrandingModel {
  final String primaryColor;
  final String secondaryColor;
  final String accentColor;
  final String? logoUrl;
  final String? splashUrl;
  final String fontFamily;

  BrandingModel({
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    this.logoUrl,
    this.splashUrl,
    required this.fontFamily,
  });

  factory BrandingModel.fromJson(Map<String, dynamic> json) {
    return BrandingModel(
      primaryColor: json['primaryColor'] ?? '#6200EE',
      secondaryColor: json['secondaryColor'] ?? '#03DAC6',
      accentColor: json['accentColor'] ?? '#FF0266',
      logoUrl: json['logoUrl'],
      splashUrl: json['splashUrl'],
      fontFamily: json['fontFamily'] ?? 'Inter',
    );
  }

  Map<String, dynamic> toJson() => {
        'primaryColor': primaryColor,
        'secondaryColor': secondaryColor,
        'accentColor': accentColor,
        'logoUrl': logoUrl,
        'splashUrl': splashUrl,
        'fontFamily': fontFamily,
      };
}

class FeatureFlagsModel {
  final bool attendance;
  final bool homework;
  final bool exams;
  final bool notices;
  final bool remarks;
  final bool timetable;

  FeatureFlagsModel({
    required this.attendance,
    required this.homework,
    required this.exams,
    required this.notices,
    required this.remarks,
    required this.timetable,
  });

  factory FeatureFlagsModel.fromJson(Map<String, dynamic> json) {
    return FeatureFlagsModel(
      attendance: json['attendance'] ?? false,
      homework: json['homework'] ?? false,
      exams: json['exams'] ?? false,
      notices: json['notices'] ?? false,
      remarks: json['remarks'] ?? false,
      timetable: json['timetable'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'attendance': attendance,
        'homework': homework,
        'exams': exams,
        'notices': notices,
        'remarks': remarks,
        'timetable': timetable,
      };
}

class AppVersionModel {
  final String minimumSupportedVersion;
  final String latestVersion;
  final bool forceUpdate;

  AppVersionModel({
    required this.minimumSupportedVersion,
    required this.latestVersion,
    required this.forceUpdate,
  });

  factory AppVersionModel.fromJson(Map<String, dynamic> json) {
    return AppVersionModel(
      minimumSupportedVersion: json['minimumSupportedVersion'] ?? '1.0.0',
      latestVersion: json['latestVersion'] ?? '1.0.0',
      forceUpdate: json['forceUpdate'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'minimumSupportedVersion': minimumSupportedVersion,
        'latestVersion': latestVersion,
        'forceUpdate': forceUpdate,
      };
}
