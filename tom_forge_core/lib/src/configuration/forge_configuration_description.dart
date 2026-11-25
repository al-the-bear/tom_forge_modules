import 'forge_setting.dart';
import 'forge_setting_hooks.dart' show ForgeSettingHooks;
import 'forge_text.dart';

/// An icon as data: a glyph of an icon font, so the description stays free
/// of Flutter (`tom_configuration_ui` makes an `IconData` of it).
class ForgeIconRef {
  /// The glyph [codePoint] of [fontFamily] (default: the Material icons).
  const ForgeIconRef(
    this.codePoint, {
    this.fontFamily = 'MaterialIcons',
    this.fontPackage,
  });

  /// The glyph.
  final int codePoint;

  /// The icon font.
  final String fontFamily;

  /// The package the font comes from, or null.
  final String? fontPackage;
}

/// A header inside a section with the settings below it: a sub-group of a
/// long section (the Markdown editor's *Headings*, *Lists*, *Tables*).
/// Groups are not nested.
class ForgeSettingsGroup extends ForgeSectionEntry {
  const ForgeSettingsGroup({
    required this.id,
    required this.title,
    required this.settings,
    this.help,
    this.collapsed = false,
  });

  /// The id, unique within its description.
  @override
  final String id;

  /// The header.
  final ForgeText title;

  /// What the group is about, shown on request.
  final ForgeText? help;

  /// Whether the group starts folded (its header shown, its settings not).
  final bool collapsed;

  /// The settings under the header, in order.
  final List<ForgeSetting<Object>> settings;
}

/// A group of settings that belong together; an application shows each
/// section as one tile (`tom_configuration_ui`), arranged as it decides.
///
/// Its [entries] are settings and sub-groups ([ForgeSettingsGroup], a header
/// with settings under it); [settings] lists every setting, the groups'
/// included.
class ForgeSettingsSection {
  const ForgeSettingsSection({
    required this.id,
    required this.title,
    required List<ForgeSectionEntry> settings,
    this.help,
    this.icon,
    this.order = 100,
  }) : entries = settings;

  /// The id, unique within its description.
  final String id;

  /// The title.
  final ForgeText title;

  /// What the section is about, shown on request.
  final ForgeText? help;

  /// The section's icon, or null.
  final ForgeIconRef? icon;

  /// Where it goes among the sections of every description (lower first);
  /// equal orders keep the order of registration.
  final int order;

  /// The entries — settings and groups — in the order they are shown.
  final List<ForgeSectionEntry> entries;

  /// Every setting, the groups' included, in the order they are shown.
  List<ForgeSetting<Object>> get settings => [
    for (final entry in entries)
      if (entry is ForgeSetting<Object>)
        entry
      else if (entry is ForgeSettingsGroup)
        ...entry.settings,
  ];

  /// The groups.
  Iterable<ForgeSettingsGroup> get groups =>
      entries.whereType<ForgeSettingsGroup>();
}

/// What a component can be configured in: its settings as typed entries,
/// grouped into sections.
///
/// Every component with options describes them so; the kit collects the
/// descriptions of every registered module (`tom_forge_kit`'s
/// `ForgeConfigurationDescriptionsExtra`), keeps the values through its
/// state-store port, and an application shows the sections as it decides.
class ForgeConfigurationDescription {
  const ForgeConfigurationDescription({
    required this.id,
    required this.title,
    required this.sections,
    this.help,
  });

  /// The component's id, unique among the descriptions of an application.
  final String id;

  /// The component's name.
  final ForgeText title;

  /// What the component is, shown on request.
  final ForgeText? help;

  /// The sections, in the order the component gives them.
  final List<ForgeSettingsSection> sections;

  /// Every setting of every section, in order.
  Iterable<ForgeSetting<Object>> get settings =>
      sections.expand((section) => section.settings);

  /// The setting with [id] (a companion of a setting too), or null.
  ForgeSetting<Object>? settingById(String id) {
    for (final setting in settings) {
      if (setting.id == id) return setting;
      for (final companion in setting.companions) {
        if (companion.id == id) return companion;
      }
    }
    return null;
  }

  /// Whether [setting] is one of this description's (or a companion of
  /// one).
  bool contains(ForgeSetting<Object> setting) {
    for (final own in settings) {
      if (identical(own, setting) || own.companions.contains(setting)) {
        return true;
      }
    }
    return false;
  }

  /// The section with [id], or null.
  ForgeSettingsSection? sectionById(String id) {
    for (final section in sections) {
      if (section.id == id) return section;
    }
    return null;
  }

  /// What is wrong with the description, for its author (in English, not
  /// for users): empty ids, an id twice, two settings at one storage
  /// location, a default that breaks its own constraints, a condition on a
  /// setting the description lacks, a group inside a group. With [hooks],
  /// also every hook a setting names that the registry lacks. Empty when it
  /// is sound.
  List<String> problems({ForgeSettingHooks? hooks}) {
    final out = <String>[];
    if (id.isEmpty) out.add('the description has no id');
    final sectionIds = <String>{};
    final entryIds = <String>{};
    final settingIds = <String>{};
    final locations = <String, ForgeSetting<Object>>{};
    void addSetting(ForgeSetting<Object> setting, String where) {
      if (setting.id.isEmpty) out.add('a setting of $where has no id');
      settingIds.add(setting.id);
      if (!entryIds.add(setting.id)) {
        out.add('$id has the setting id "${setting.id}" twice');
      }
      if (setting.storesValue) {
        final location = setting.storage.location;
        final other = locations[location];
        if (other != null && !identical(other, setting)) {
          out.add('${setting.id} and ${other.id} are both stored at $location');
        } else {
          locations[location] = setting;
        }
      }
      final problem = setting.validate(setting.defaultValue);
      if (problem != null) {
        out.add('the default of ${setting.id} is not valid: $problem');
      }
      if (hooks != null) {
        for (final hook in setting.hookIds) {
          if (!hooks.has(hook)) {
            out.add('${setting.id} names the hook "$hook", which is missing');
          }
        }
      }
    }

    final companions = <ForgeSetting<Object>>[];
    for (final section in sections) {
      if (section.id.isEmpty) out.add('a section of $id has no id');
      if (!sectionIds.add(section.id)) {
        out.add('$id has the section id "${section.id}" twice');
      }
      for (final entry in section.entries) {
        if (entry is ForgeSettingsGroup) {
          if (entry.id.isEmpty) {
            out.add('a group of $id/${section.id} has no id');
          }
          if (!entryIds.add(entry.id)) {
            out.add('$id has the group id "${entry.id}" twice');
          }
          for (final setting in entry.settings) {
            addSetting(setting, '$id/${section.id}/${entry.id}');
            companions.addAll(setting.companions);
          }
        } else if (entry is ForgeSetting<Object>) {
          addSetting(entry, '$id/${section.id}');
          companions.addAll(entry.companions);
        } else {
          out.add('$id/${section.id} has an entry of an unknown type');
        }
      }
    }
    final seenCompanions = <ForgeSetting<Object>>[];
    for (final companion in companions) {
      if (seenCompanions.any((c) => identical(c, companion))) continue;
      seenCompanions.add(companion);
      final other = locations[companion.storage.location];
      if (other != null && !identical(other, companion)) {
        out.add(
          'the companion ${companion.id} and ${other.id} are both stored at '
          '${companion.storage.location}',
        );
      } else {
        locations[companion.storage.location] = companion;
      }
    }
    for (final setting in settings) {
      if (setting.hasValue && !setting.storesValue) {
        out.add('${setting.id} has no storage key');
      }
      for (final condition in [setting.visibleWhen, setting.enabledWhen]) {
        if (condition != null && !settingIds.contains(condition.settingId)) {
          out.add(
            '${setting.id} has a condition on "${condition.settingId}", '
            'which $id lacks',
          );
        }
      }
    }
    return out;
  }
}

/// One section of one description: what an application shows as a tile.
class ForgeConfigurationSectionRef {
  const ForgeConfigurationSectionRef(this.description, this.section);

  /// The description the section belongs to.
  final ForgeConfigurationDescription description;

  /// The section.
  final ForgeSettingsSection section;

  /// `<description id>/<section id>`, unique among an application's sections.
  String get id => '${description.id}/${section.id}';
}

/// Every section of [descriptions], ordered by [ForgeSettingsSection.order]
/// (lower first); sections of equal order keep the order of the descriptions
/// and of their sections.
List<ForgeConfigurationSectionRef> forgeOrderedSections(
  Iterable<ForgeConfigurationDescription> descriptions,
) {
  final refs = [
    for (final description in descriptions)
      for (final section in description.sections)
        ForgeConfigurationSectionRef(description, section),
  ];
  final indexed = refs.asMap().entries.toList()
    ..sort((a, b) {
      final byOrder = a.value.section.order.compareTo(b.value.section.order);
      return byOrder != 0 ? byOrder : a.key.compareTo(b.key);
    });
  return [for (final entry in indexed) entry.value];
}
