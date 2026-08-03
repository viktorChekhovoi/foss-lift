// Builds the feature catalogue's three pages from the YAML under `features/`.
//
//   dart run tool/features.dart            regenerate the pages
//   dart run tool/features.dart --check    verify without writing (CI / pre-commit)
//
// The source of truth is `features/catalogue/*.yaml`, `features/concepts.yaml`
// and `features/screens.yaml`. The HTML is output — never edit it by hand, the
// next run will overwrite you.
//
// --check is the part that keeps the catalogue honest. It fails on a tag that
// is not in the vocabulary, a duplicated item id, a section id that disagrees
// with its filename, and a section's or concept's path that has stopped
// existing — a
// catalogue that can rot quietly is a catalogue nobody trusts a year from now.
// A concept nobody defines, a screen nothing points at and generated HTML that
// has drifted are reported every run but never fail; see `Findings` for why.

import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';

// ---------------------------------------------------------------- the model

/// One catalogue entry, with section and group tags already folded in.
class Item {
  Item({
    required this.id,
    required this.sectionId,
    required this.sectionTitle,
    required this.group,
    required this.title,
    required this.detail,
    required this.screen,
    required this.points,
    required this.defines,
    required this.uses,
    required this.code,
    required this.manual,
  });

  final String id; // "04.board-marks-set-you" — stable, survives rewording
  final String sectionId;
  final String sectionTitle;
  final String group;
  final String title;
  final String? detail;
  final String screen;

  /// The screens this entry *describes* rather than lives on.
  ///
  /// Only the tour needs it, and it is the whole of what keeps the tour honest.
  /// A coach mark sits on the `tutorial` screen — that is where you go to look
  /// at it — while the thing it is talking about is somewhere else entirely, so
  /// `screen` alone cannot say "this step is about the Routines tab". Without
  /// that edge, changing a screen surfaces every entry on it and none of the
  /// tour steps that describe it, and the tour drifts out of date silently,
  /// which is exactly how it came to point at an app that had moved on.
  ///
  /// `--check` fails on a screen that does not exist and reports — never fatally
  /// — a step that points at a screen without sharing a single concept with the
  /// entries that live there. The second one is the honest signal: it means the
  /// step and the screen have no subject in common, so one of them is wrong.
  final List<String> points;
  final List<String> defines;
  final List<String> uses;
  final List<String> code;
  final bool manual;

  /// Every concept this item is linked to, in either direction.
  Iterable<String> get concepts => [...defines, ...uses];
}

class Group {
  Group(this.name, this.items);
  final String name;
  final List<Item> items;
}

class Section {
  Section({
    required this.id,
    required this.title,
    required this.tagline,
    required this.where,
    required this.code,
    required this.test,
    required this.groups,
  });

  final String id;
  final String title;
  final String tagline;
  final String where;
  final List<String> code;
  final List<String> test;
  final List<Group> groups;

  Iterable<Item> get items => groups.expand((g) => g.items);
}

class Concept {
  Concept(this.id, this.area, this.what, this.code);
  final String id;
  final String area;
  final String what;
  final List<String> code;
}

class Screen {
  Screen(this.id, this.title, this.route, this.reach, this.setup);
  final String id;
  final String title;
  final String? route;
  final String? reach;
  final String? setup;
}

// ----------------------------------------------------------------- loading

List<String> _strings(dynamic v) {
  if (v == null) return const [];
  if (v is String) return [v];
  return (v as YamlList).map((e) => e.toString()).toList();
}

/// Section, then group, then item — a tag set at any level applies to
/// everything under it, and a level below adds to it rather than replacing it.
/// That is what keeps a 76-item section from repeating `session.rest-timer`
/// fourteen times.
List<String> _inherit(List<String> outer, dynamic inner) {
  final out = [...outer];
  for (final v in _strings(inner)) {
    if (!out.contains(v)) out.add(v);
  }
  return out;
}

Section _loadSection(File f) {
  final doc = loadYaml(f.readAsStringSync()) as YamlMap;

  // `id: 04` is an integer to a YAML 1.2 parser and a string to a 1.1 one, so
  // it is normalised rather than trusted — every item id in the file is built
  // from it, and a section that silently renumbered itself would break every
  // link pointing into it. The filename is the authority.
  final id = doc['id'].toString().padLeft(2, '0');
  final fromName = RegExp(r'^(\d+)-').firstMatch(f.uri.pathSegments.last)?.group(1);
  if (id != fromName) {
    throw StateError('${f.path}: section id "$id" does not match its filename');
  }

  final secScreen = doc['screen'] as String? ?? 'none';
  final secDefines = _strings(doc['defines']);
  final secUses = _strings(doc['uses']);
  final secCode = _strings(doc['code']);

  final groups = <Group>[];
  for (final g in doc['groups'] as YamlList) {
    final gm = g as YamlMap;
    final gScreen = gm['screen'] as String? ?? secScreen;
    final gDefines = _inherit(secDefines, gm['defines']);
    final gUses = _inherit(secUses, gm['uses']);
    final gCode = _inherit(secCode, gm['code']);

    final items = <Item>[];
    for (final i in gm['items'] as YamlList) {
      final im = i as YamlMap;
      final defines = _inherit(gDefines, im['defines']);
      // Defining a concept subsumes using it, so an item that owns one is not
      // also listed in its blast radius. Without this an inherited group tag
      // would put the definer in both columns.
      final uses = _inherit(gUses, im['uses'])..removeWhere(defines.contains);
      items.add(Item(
        id: '$id.${im['id']}',
        sectionId: id,
        sectionTitle: doc['title'] as String,
        group: gm['name'] as String,
        title: im['t'] as String,
        detail: im['d'] as String?,
        screen: im['screen'] as String? ?? gScreen,
        // Item-level only, and deliberately not inherited: "this section is
        // about the session screen" would tag every entry under it, and a link
        // that is always true carries no information.
        points: _strings(im['points']),
        defines: defines,
        uses: uses,
        code: _inherit(gCode, im['code']),
        manual: im['manual'] as bool? ?? false,
      ));
    }
    groups.add(Group(gm['name'] as String, items));
  }

  return Section(
    id: id,
    title: doc['title'] as String,
    tagline: doc['tagline'] as String,
    where: doc['where'] as String? ?? '',
    code: secCode,
    test: _strings(doc['test']),
    groups: groups,
  );
}

class Catalogue {
  Catalogue(this.sections, this.concepts, this.screens);
  final List<Section> sections;
  final List<Concept> concepts;
  final List<Screen> screens;

  List<Item> get items => sections.expand((s) => s.items).toList();

  static Catalogue load(Directory root) {
    final dir = Directory('${root.path}/features/catalogue');
    final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.yaml')).toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    final sections = files.map(_loadSection).toList();

    final cdoc = loadYaml(File('${root.path}/features/concepts.yaml').readAsStringSync()) as YamlMap;
    final concepts = (cdoc['concepts'] as YamlList)
        .map((c) => Concept(c['id'] as String, c['area'] as String, c['what'] as String,
            _strings(c['code'])))
        .toList();

    final sdoc = loadYaml(File('${root.path}/features/screens.yaml').readAsStringSync()) as YamlMap;
    final screens = (sdoc['screens'] as YamlList)
        .map((s) => Screen(s['id'] as String, s['title'] as String, s['route'] as String?,
            s['reach'] as String?, s['setup'] as String?))
        .toList();

    return Catalogue(sections, concepts, screens);
  }
}

// -------------------------------------------------------------- validation

/// Two tiers, deliberately.
///
/// A **problem** is rot: a concept that does not exist, a path that has stopped
/// existing, a duplicated id, generated HTML that no longer matches its source.
/// These fail `--check`, because every one of them means the catalogue is now
/// lying about the code.
///
/// A **gap** is honest missing coverage: a concept nothing defines usually
/// means a real feature nobody has written down yet. Those are reported every
/// run and never fail the build — a gap you cannot commit around is a gap
/// somebody papers over with a fake entry.
class Findings {
  final List<String> problems = [];
  final List<String> gaps = [];
}

Findings validate(Catalogue cat, Directory root) {
  final findings = Findings();
  final problems = findings.problems;
  final conceptIds = {for (final c in cat.concepts) c.id};
  final screenIds = {for (final s in cat.screens) s.id};

  final seen = <String>{};
  for (final item in cat.items) {
    if (!seen.add(item.id)) problems.add('duplicate item id: ${item.id}');
    if (!screenIds.contains(item.screen)) {
      problems.add('${item.id}: no such screen "${item.screen}"');
    }
    for (final s in item.points) {
      if (!screenIds.contains(s)) {
        problems.add('${item.id}: points at no such screen "$s"');
      }
    }
    for (final c in item.concepts) {
      if (!conceptIds.contains(c)) {
        problems.add('${item.id}: no such concept "$c" — add it to features/concepts.yaml');
      }
    }
  }

  void checkPaths(String owner, List<String> paths) {
    for (final p in paths) {
      if (!File('${root.path}/$p').existsSync()) {
        problems.add('$owner: "$p" no longer exists');
      }
    }
  }

  for (final s in cat.sections) {
    checkPaths('section ${s.id}', s.code);
    checkPaths('section ${s.id}', s.test);
  }
  for (final c in cat.concepts) {
    checkPaths('concept ${c.id}', c.code);
  }

  // A concept used but never defined is the useful signal: something the app
  // does that the catalogue has never described. A screen nothing sits on is
  // the same hole seen from the other side.
  for (final c in cat.concepts) {
    final definers = cat.items.where((i) => i.defines.contains(c.id)).length;
    final users = cat.items.where((i) => i.uses.contains(c.id)).length;
    if (definers == 0 && users == 0) {
      findings.gaps.add('concept ${c.id}: nothing refers to it — drop it, or tag what uses it');
    } else if (definers == 0) {
      findings.gaps.add('concept ${c.id}: used by $users items, described by none — '
          'no catalogue entry says what it is');
    }
  }

  for (final s in cat.screens) {
    if (s.id == 'none') continue;
    if (!cat.items.any((i) => i.screen == s.id)) {
      findings.gaps.add('screen ${s.id}: no item is on it — nothing in the catalogue '
          'describes this screen');
    }
  }

  // The `points` edge, checked in both directions.
  //
  // An entry that describes another screen — a tour step — has to be talking
  // about the same thing that screen's own entries are, or the link is a label
  // with nothing behind it. Sharing one concept is a low bar on purpose: it
  // catches the step that has drifted onto a subject the screen no longer has,
  // without demanding that a one-sentence coach mark enumerate the screen.
  for (final item in cat.items) {
    for (final s in item.points) {
      if (!screenIds.contains(s)) continue; // already a problem, above
      final onScreen = cat.items.where((i) => i.screen == s);
      final theirs = {for (final i in onScreen) ...i.concepts};
      if (theirs.isEmpty) {
        findings.gaps.add('${item.id}: points at screen "$s", which no catalogue '
            'entry describes');
      } else if (!item.concepts.any(theirs.contains)) {
        findings.gaps.add('${item.id}: points at screen "$s" but shares no concept '
            'with the ${onScreen.length} entries on it — say what it is about, or '
            'stop pointing at it');
      }
    }
  }

  return findings;
}

// ------------------------------------------------------------------- pages

const _css = r'''
  :root {
    --bg: #ffffff; --bg2: #f7f7f6; --fg: #1a1a19; --fg2: #5f5f5c; --fg3: #8c8c88;
    --line: #e4e4e0; --line2: #d2d2cc; --accent: #b4531f; --accent-bg: #fbf1ea;
    --done: #3f7d47; --warn: #a8342c; --warn-bg: #fbeceb;
    --radius: 8px; --sidebar: 260px; --maxw: 780px;
  }
  @media (prefers-color-scheme: dark) {
    :root {
      --bg: #161614; --bg2: #1e1e1b; --fg: #ececE6; --fg2: #a9a9a2; --fg3: #78786f;
      --line: #2c2c28; --line2: #3b3b35; --accent: #e08a4e; --accent-bg: #2a201a;
      --done: #7fb886; --warn: #e0827a; --warn-bg: #2c1c1a;
    }
  }
  * { box-sizing: border-box; }
  html { scroll-behavior: smooth; scroll-padding-top: 84px; }
  body {
    margin: 0; background: var(--bg); color: var(--fg);
    font: 15px/1.55 ui-sans-serif, -apple-system, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
    -webkit-font-smoothing: antialiased;
  }
  a { color: var(--accent); }

  .topbar {
    position: sticky; top: 0; z-index: 20;
    background: color-mix(in srgb, var(--bg) 92%, transparent);
    backdrop-filter: blur(8px); border-bottom: 1px solid var(--line);
  }
  .topbar-in {
    max-width: calc(var(--sidebar) + var(--maxw) + 96px);
    margin: 0 auto; padding: 12px 24px;
    display: flex; align-items: center; gap: 16px; flex-wrap: wrap;
  }
  .brand { font-weight: 640; letter-spacing: -0.01em; white-space: nowrap; }
  .brand span { color: var(--fg3); font-weight: 400; }
  .pages { display: flex; gap: 2px; }
  .pages a {
    font-size: 13px; padding: 5px 10px; border-radius: var(--radius);
    text-decoration: none; color: var(--fg2); white-space: nowrap;
  }
  .pages a:hover { background: var(--bg2); color: var(--fg); }
  .pages a.on { background: var(--accent-bg); color: var(--accent); font-weight: 560; }
  .grow { flex: 1 1 120px; }
  .search {
    flex: 0 1 260px; font: inherit; font-size: 14px; padding: 6px 10px;
    border: 1px solid var(--line2); border-radius: var(--radius);
    background: var(--bg2); color: var(--fg);
  }
  .search:focus { outline: 2px solid var(--accent); outline-offset: -1px; }
  .btn {
    font: inherit; font-size: 13px; padding: 6px 11px; cursor: pointer;
    border: 1px solid var(--line2); border-radius: var(--radius);
    background: var(--bg2); color: var(--fg2); white-space: nowrap;
  }
  .btn:hover { color: var(--fg); border-color: var(--fg3); }
  .btn[aria-pressed="true"] { background: var(--accent-bg); border-color: var(--accent); color: var(--accent); }
  .count { font-variant-numeric: tabular-nums; color: var(--fg2); font-size: 13px; white-space: nowrap; }
  .count b { color: var(--fg); font-weight: 620; }
  .bar { height: 3px; background: var(--line); }
  .bar > i { display: block; height: 100%; width: 0; background: var(--accent); transition: width .18s ease; }

  .layout {
    max-width: calc(var(--sidebar) + var(--maxw) + 96px);
    margin: 0 auto; padding: 0 24px 120px;
    display: grid; grid-template-columns: var(--sidebar) minmax(0, 1fr); gap: 48px;
  }
  nav {
    position: sticky; top: 72px; align-self: start;
    max-height: calc(100vh - 96px); overflow-y: auto; padding: 24px 0; font-size: 13.5px;
  }
  nav a {
    display: flex; gap: 10px; align-items: baseline;
    padding: 5px 8px; margin-left: -8px;
    border-radius: 6px; text-decoration: none; color: var(--fg2);
  }
  nav a:hover { background: var(--bg2); color: var(--fg); }
  nav a.on { color: var(--fg); font-weight: 560; background: var(--bg2); }
  nav a .n { color: var(--fg3); font-variant-numeric: tabular-nums; font-size: 12px; min-width: 16px; }
  nav a .f { margin-left: auto; color: var(--fg3); font-variant-numeric: tabular-nums; font-size: 11.5px; white-space: nowrap; }
  nav a.full .f { color: var(--done); }
  nav .navhead { color: var(--fg3); text-transform: uppercase; letter-spacing: .08em; font-size: 11px; margin: 0 0 10px; }

  main { padding: 24px 0; min-width: 0; }
  .lede { color: var(--fg2); margin: 0 0 40px; max-width: 60ch; }

  section { margin: 0 0 52px; scroll-margin-top: 84px; }
  section > h2 {
    font-size: 21px; letter-spacing: -0.015em; font-weight: 640;
    margin: 0 0 2px; display: flex; align-items: baseline; gap: 10px;
  }
  section > h2 .num { color: var(--fg3); font-size: 13px; font-weight: 500; font-variant-numeric: tabular-nums; }
  section > h2 .f { margin-left: auto; font-size: 12px; font-weight: 500; color: var(--fg3); font-variant-numeric: tabular-nums; }
  section.full > h2 .f { color: var(--done); }
  .tagline { color: var(--fg2); margin: 0 0 18px; max-width: 62ch; }
  h3 {
    font-size: 11.5px; text-transform: uppercase; letter-spacing: .09em;
    color: var(--fg3); font-weight: 620; margin: 22px 0 8px;
  }

  ul.items { list-style: none; margin: 0; padding: 0; }
  li.item { border-top: 1px solid var(--line); scroll-margin-top: 90px; }
  li.item:last-child { border-bottom: 1px solid var(--line); }
  li.item:target { background: var(--accent-bg); }
  label.row {
    display: flex; gap: 12px; align-items: flex-start;
    padding: 9px 8px 9px 4px; cursor: pointer;
  }
  label.row:hover { background: var(--bg2); }
  label.row input {
    appearance: none; -webkit-appearance: none;
    flex: 0 0 auto; width: 16px; height: 16px; margin: 3px 0 0;
    border: 1.5px solid var(--line2); border-radius: 4px;
    background: transparent; cursor: pointer;
  }
  label.row input:checked { background: var(--done); border-color: var(--done); }
  label.row input:checked::after {
    content: ""; display: block; width: 4px; height: 8px; margin: 1px 0 0 4.5px;
    border: solid #fff; border-width: 0 1.8px 1.8px 0; transform: rotate(42deg);
  }
  label.row input:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }
  .txt { min-width: 0; }
  .t { font-weight: 570; }
  .d { color: var(--fg2); }
  li.item.done .txt { color: var(--fg3); }
  li.item.done .t { color: var(--fg3); font-weight: 500; }
  li.item.done .d { color: var(--fg3); }
  mark { background: var(--accent-bg); color: inherit; border-radius: 3px; padding: 0 1px; }

  .where {
    margin: 16px 0 0; padding: 10px 12px;
    background: var(--bg2); border-radius: var(--radius);
    font-size: 12.5px; color: var(--fg3); line-height: 1.5;
  }
  .where b { color: var(--fg2); font-weight: 600; }
  code { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: .92em; }

  .empty { color: var(--fg3); padding: 40px 0; }
  [hidden] { display: none !important; }

  /* ---- concept chips, shared by all three pages ---- */
  .links { margin: 2px 0 0; display: flex; flex-wrap: wrap; gap: 4px; align-items: baseline; }
  .chip {
    font-size: 11px; padding: 1px 7px; border-radius: 999px;
    border: 1px solid var(--line2); color: var(--fg3);
    text-decoration: none; white-space: nowrap;
    font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
  }
  a.chip:hover { border-color: var(--accent); color: var(--accent); }
  .chip.def { border-color: var(--accent); color: var(--accent); }
  .chip.scr { border-style: dashed; }
  .chip.pts { border-style: dashed; border-color: var(--accent); color: var(--accent); }
  .chip.man { border-color: var(--warn); color: var(--warn); }

  /* ---- concepts page ---- */
  .concept { border-top: 1px solid var(--line); padding: 16px 0; scroll-margin-top: 90px; }
  .concept:target { background: var(--accent-bg); }
  .concept h4 {
    margin: 0 0 3px; font-size: 14px; font-weight: 620;
    font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
  }
  .concept .what { color: var(--fg2); margin: 0 0 10px; max-width: 62ch; }
  .side { font-size: 13px; margin: 0 0 6px; }
  .side > b { font-weight: 600; color: var(--fg3); font-size: 11px;
    text-transform: uppercase; letter-spacing: .08em; display: block; margin-bottom: 3px; }
  .side ul { list-style: none; margin: 0; padding: 0; }
  .side li { padding: 2px 0; color: var(--fg2); }
  .side li a { text-decoration: none; }
  .side li a:hover { text-decoration: underline; }
  .side li .sec { color: var(--fg3); font-size: 11.5px; font-variant-numeric: tabular-nums; }

  /* ---- walkthrough ---- */
  .screen { margin: 0 0 44px; scroll-margin-top: 84px; }
  .reach {
    margin: 0 0 4px; padding: 9px 12px; background: var(--bg2);
    border-radius: var(--radius); font-size: 13.5px; color: var(--fg2);
  }
  .reach b { color: var(--fg); font-weight: 600; }
  .setup { color: var(--warn); }
  .step { border-top: 1px solid var(--line); padding: 10px 4px; }
  .step:last-child { border-bottom: 1px solid var(--line); }
  .step .head { display: flex; gap: 12px; align-items: flex-start; }
  .step .txt { flex: 1 1 auto; }
  .marks { display: flex; gap: 3px; flex: 0 0 auto; }
  .marks button {
    font: inherit; font-size: 12px; width: 30px; padding: 3px 0; cursor: pointer;
    border: 1px solid var(--line2); border-radius: 6px;
    background: var(--bg2); color: var(--fg3);
  }
  .marks button:hover { border-color: var(--fg3); color: var(--fg); }
  .step[data-v="pass"] .marks button[data-v="pass"] { background: var(--done); border-color: var(--done); color: #fff; }
  .step[data-v="fail"] .marks button[data-v="fail"] { background: var(--warn); border-color: var(--warn); color: #fff; }
  .step[data-v="skip"] .marks button[data-v="skip"] { background: var(--fg3); border-color: var(--fg3); color: var(--bg); }
  .step[data-v="pass"] .txt { color: var(--fg3); }
  .step[data-v="pass"] .t { font-weight: 500; }
  .step textarea {
    display: none; width: 100%; margin: 8px 0 0; padding: 7px 9px;
    font: inherit; font-size: 13px; resize: vertical; min-height: 52px;
    border: 1px solid var(--warn); border-radius: var(--radius);
    background: var(--warn-bg); color: var(--fg);
  }
  .step[data-v="fail"] textarea { display: block; }
  .out {
    width: 100%; min-height: 220px; margin: 12px 0 0; padding: 10px 12px;
    font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: 12.5px;
    border: 1px solid var(--line2); border-radius: var(--radius);
    background: var(--bg2); color: var(--fg);
  }
  dialog {
    border: 1px solid var(--line2); border-radius: var(--radius);
    background: var(--bg); color: var(--fg); max-width: 720px; width: 92vw; padding: 18px;
  }
  dialog::backdrop { background: rgba(0,0,0,.4); }

  @media (max-width: 900px) {
    .layout { grid-template-columns: 1fr; gap: 0; }
    nav { position: static; max-height: none; padding: 20px 0 0; border-bottom: 1px solid var(--line); }
    nav a { display: inline-flex; margin: 0 4px 4px 0; border: 1px solid var(--line); }
    nav a .f { margin-left: 4px; }
  }
  @media print {
    .topbar, nav { display: none; }
    .layout { display: block; }
  }
''';

const _pages = [
  ['index.html', 'Catalogue'],
  ['concepts.html', 'Concepts'],
  ['walkthrough.html', 'Walkthrough'],
];

String _nav(String current) {
  final links = _pages
      .map((p) => '<a href="${p[0]}"${p[0] == current ? ' class="on"' : ''}>${p[1]}</a>')
      .join('');
  return '<div class="pages">$links</div>';
}

/// The one page skeleton. Three pages, one set of chrome — a change to the
/// header or the palette lands on all of them at once.
String _shell({
  required String file,
  required String title,
  required String subtitle,
  required String toolbar,
  required String body,
  required String data,
  required String script,
}) {
  return '''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>$title</title>
<!-- GENERATED by tool/features.dart from features/*.yaml — do not edit. -->
<style>$_css</style>
</head>
<body>

<header class="topbar">
  <div class="topbar-in">
    <div class="brand">FossLift <span>· $subtitle</span></div>
    ${_nav(file)}
    <div class="grow"></div>
$toolbar
  </div>
  <div class="bar"><i id="barfill"></i></div>
</header>

$body

<script type="application/json" id="data">
$data
</script>

<script>
$script
</script>
</body>
</html>
''';
}

String _json(Object o) {
  final s = const JsonEncoder.withIndent(' ').convert(o);
  if (s.contains('</script')) throw StateError('catalogue text would close the data block');
  return s;
}

// ------------------------------------------------------------ the catalogue

String buildIndex(Catalogue cat) {
  final data = _json([
    for (final s in cat.sections)
      {
        'id': s.id,
        'title': s.title,
        'tagline': s.tagline,
        'where': s.where,
        'test': s.test,
        'groups': [
          for (final g in s.groups)
            {
              'name': g.name,
              'items': [
                for (final i in g.items)
                  {
                    'id': i.id,
                    't': i.title,
                    if (i.detail != null) 'd': i.detail,
                    'screen': i.screen,
                    if (i.points.isNotEmpty) 'points': i.points,
                    'defines': i.defines,
                    'uses': i.uses,
                    if (i.manual) 'manual': true,
                  }
              ],
            }
        ],
      }
  ]);

  return _shell(
    file: 'index.html',
    title: 'FossLift — Feature Catalogue',
    subtitle: 'feature catalogue',
    toolbar: '''    <input class="search" id="q" type="search" placeholder="Filter features…  (/)" autocomplete="off">
    <button class="btn" id="links" aria-pressed="false">Show links</button>
    <button class="btn" id="hide" aria-pressed="false">Hide checked</button>
    <button class="btn" id="expandAll">Check all</button>
    <button class="btn" id="reset">Reset</button>
    <div class="count" id="count"></div>''',
    body: '''<div class="layout">
  <nav id="nav"></nav>
  <main id="main">
    <p class="lede">Everything the app does today, one checkbox per behaviour. Tick as you walk through it; the ticks are kept in this browser. For a pass ordered by screen rather than by feature, use the <a href="walkthrough.html">walkthrough</a>.</p>
    <div id="sections"></div>
    <p class="empty" id="empty" hidden>Nothing matches that filter.</p>
  </main>
</div>''',
    data: data,
    script: _indexJs,
  );
}

const _indexJs = r'''
(function () {
  const DATA = JSON.parse(document.getElementById('data').textContent);
  const KEY = 'fosslift.features.v2';
  const state = JSON.parse(localStorage.getItem(KEY) || '{}');

  const secEl = document.getElementById('sections');
  const navEl = document.getElementById('nav');
  const items = [];
  const secs  = [];

  navEl.insertAdjacentHTML('beforeend', '<p class="navhead">Contents</p>');

  const chip = (t, cls, href) => href
    ? '<a class="chip ' + cls + '" href="' + href + '">' + t + '</a>'
    : '<span class="chip ' + cls + '">' + t + '</span>';

  DATA.forEach(sec => {
    const ids = [];
    let html = '<h2 id="s' + sec.id + '"><span class="num">' + sec.id + '</span>' + sec.title + '<span class="f"></span></h2>';
    html += '<p class="tagline">' + sec.tagline + '</p>';
    sec.groups.forEach(g => {
      html += '<h3>' + g.name + '</h3><ul class="items">';
      g.items.forEach(it => {
        ids.push(it.id);
        const on = !!state[it.id];
        let links = chip(it.screen, 'scr', 'walkthrough.html#scr-' + it.screen);
        (it.points || []).forEach(s => links += chip('→ ' + s, 'pts', 'walkthrough.html#scr-' + s));
        it.defines.forEach(c => links += chip(c, 'def', 'concepts.html#c-' + c));
        it.uses.forEach(c => links += chip(c, '', 'concepts.html#c-' + c));
        if (it.manual) links += chip('manual only', 'man');
        html += '<li class="item' + (on ? ' done' : '') + '" id="i-' + it.id + '" data-id="' + it.id + '">' +
          '<label class="row"><input type="checkbox"' + (on ? ' checked' : '') + '>' +
          '<span class="txt"><span class="t">' + it.t + '</span>' +
          (it.d ? ' <span class="d">' + it.d + '</span>' : '') +
          '<span class="links" hidden>' + links + '</span>' +
          '</span></label></li>';
      });
      html += '</ul>';
    });
    if (sec.where) html += '<p class="where">' + sec.where + '</p>';

    const el = document.createElement('section');
    el.id = 'sec' + sec.id;
    el.innerHTML = html;
    secEl.appendChild(el);

    const a = document.createElement('a');
    a.href = '#sec' + sec.id;
    a.innerHTML = '<span class="n">' + sec.id + '</span><span>' + sec.title + '</span><span class="f"></span>';
    navEl.appendChild(a);

    secs.push({ data: sec, el, navA: a, ids });
    el.querySelectorAll('li.item').forEach(li => {
      items.push({ id: li.dataset.id, li, sec, text: li.textContent.toLowerCase() });
    });
  });

  const countEl = document.getElementById('count');
  const fill = document.getElementById('barfill');

  function tally() {
    let done = 0;
    secs.forEach(s => {
      const d = s.ids.filter(i => state[i]).length;
      done += d;
      const label = d + '/' + s.ids.length;
      s.navA.querySelector('.f').textContent = label;
      s.el.querySelector('h2 .f').textContent = label;
      const full = d === s.ids.length;
      s.navA.classList.toggle('full', full);
      s.el.classList.toggle('full', full);
    });
    const total = items.length;
    countEl.innerHTML = '<b>' + done + '</b> / ' + total;
    fill.style.width = (total ? (done / total * 100) : 0) + '%';
  }

  secEl.addEventListener('change', e => {
    const box = e.target;
    if (box.type !== 'checkbox') return;
    const li = box.closest('li.item');
    if (box.checked) state[li.dataset.id] = 1; else delete state[li.dataset.id];
    li.classList.toggle('done', box.checked);
    localStorage.setItem(KEY, JSON.stringify(state));
    tally();
    applyFilter();
  });

  // a chip is a link, not part of the label's click target
  secEl.addEventListener('click', e => {
    if (e.target.closest('a.chip')) e.stopPropagation();
  });

  const q = document.getElementById('q');
  const hideBtn = document.getElementById('hide');
  const linksBtn = document.getElementById('links');
  const emptyEl = document.getElementById('empty');
  let hideChecked = false;

  function applyFilter() {
    const term = q.value.trim().toLowerCase();
    let shown = 0;
    items.forEach(it => {
      const matches = (!term || it.text.includes(term)) && (!hideChecked || !state[it.id]);
      it.li.hidden = !matches;
      if (matches) shown++;
    });
    secs.forEach(s => {
      const any = [...s.el.querySelectorAll('li.item')].some(li => !li.hidden);
      s.el.hidden = !any;
      s.navA.hidden = !any;
      s.el.querySelectorAll('h3').forEach(h3 => {
        const ul = h3.nextElementSibling;
        h3.hidden = ![...ul.querySelectorAll('li.item')].some(li => !li.hidden);
        ul.hidden = h3.hidden;
      });
      const where = s.el.querySelector('.where');
      if (where) where.hidden = !!term || hideChecked;
    });
    emptyEl.hidden = shown > 0;
  }

  q.addEventListener('input', applyFilter);
  hideBtn.addEventListener('click', () => {
    hideChecked = !hideChecked;
    hideBtn.setAttribute('aria-pressed', String(hideChecked));
    hideBtn.textContent = hideChecked ? 'Show all' : 'Hide checked';
    applyFilter();
  });

  let showLinks = false;
  linksBtn.addEventListener('click', () => {
    showLinks = !showLinks;
    linksBtn.setAttribute('aria-pressed', String(showLinks));
    linksBtn.textContent = showLinks ? 'Hide links' : 'Show links';
    secEl.querySelectorAll('.links').forEach(l => { l.hidden = !showLinks; });
  });

  document.getElementById('reset').addEventListener('click', () => {
    if (!confirm('Clear every tick?')) return;
    Object.keys(state).forEach(k => delete state[k]);
    localStorage.setItem(KEY, JSON.stringify(state));
    secEl.querySelectorAll('input[type=checkbox]').forEach(b => { b.checked = false; b.closest('li').classList.remove('done'); });
    tally(); applyFilter();
  });

  document.getElementById('expandAll').addEventListener('click', () => {
    const visible = items.filter(it => !it.li.hidden);
    const allOn = visible.every(it => state[it.id]);
    visible.forEach(it => {
      if (allOn) delete state[it.id]; else state[it.id] = 1;
      it.li.querySelector('input').checked = !allOn;
      it.li.classList.toggle('done', !allOn);
    });
    localStorage.setItem(KEY, JSON.stringify(state));
    tally(); applyFilter();
  });

  document.addEventListener('keydown', e => {
    if (e.key === '/' && document.activeElement !== q) { e.preventDefault(); q.focus(); q.select(); }
    if (e.key === 'Escape' && document.activeElement === q) { q.value = ''; applyFilter(); q.blur(); }
  });

  const spy = new IntersectionObserver(entries => {
    entries.forEach(en => {
      if (en.isIntersecting) {
        navEl.querySelectorAll('a.on').forEach(a => a.classList.remove('on'));
        const s = secs.find(x => x.el === en.target);
        if (s) s.navA.classList.add('on');
      }
    });
  }, { rootMargin: '-80px 0px -70% 0px' });
  secs.forEach(s => spy.observe(s.el));

  // a deep link from another page should reveal what it points at
  if (location.hash.startsWith('#i-')) {
    const li = document.getElementById(location.hash.slice(1));
    if (li) li.scrollIntoView({ block: 'center' });
  }

  tally();
  applyFilter();
})();
''';

// -------------------------------------------------------------- the concepts

String buildConcepts(Catalogue cat) {
  final areas = <String, String>{};
  final cdoc = loadYaml(File('features/concepts.yaml').readAsStringSync()) as YamlMap;
  for (final a in cdoc['areas'] as YamlList) {
    areas[a['id'] as String] = a['title'] as String;
  }

  Map<String, Object?> ref(Item i) => {
        'id': i.id,
        't': i.title,
        'sec': i.sectionId,
        'secTitle': i.sectionTitle,
        'screen': i.screen,
      };

  final data = _json({
    'areas': [
      for (final e in areas.entries) {'id': e.key, 'title': e.value}
    ],
    'concepts': [
      for (final c in cat.concepts)
        {
          'id': c.id,
          'area': c.area,
          'what': c.what,
          'code': c.code,
          'definedBy': [for (final i in cat.items.where((i) => i.defines.contains(c.id))) ref(i)],
          'usedBy': [for (final i in cat.items.where((i) => i.uses.contains(c.id))) ref(i)],
        }
    ],
  });

  return _shell(
    file: 'concepts.html',
    title: 'FossLift — Concepts',
    subtitle: 'concepts',
    toolbar: '''    <input class="search" id="q" type="search" placeholder="Filter concepts…  (/)" autocomplete="off">
    <div class="count" id="count"></div>''',
    body: '''<div class="layout">
  <nav id="nav"></nav>
  <main id="main">
    <p class="lede">What changes together. <b>Defined by</b> lists the entries you edit to change a concept. <b>Used by</b> is the blast radius: everything that has to be re-checked afterwards.</p>
    <div id="areas"></div>
    <p class="empty" id="empty" hidden>Nothing matches that filter.</p>
  </main>
</div>''',
    data: data,
    script: _conceptsJs,
  );
}

const _conceptsJs = r'''
(function () {
  const DATA = JSON.parse(document.getElementById('data').textContent);
  const wrap = document.getElementById('areas');
  const navEl = document.getElementById('nav');
  navEl.insertAdjacentHTML('beforeend', '<p class="navhead">Areas</p>');

  const list = (label, refs) => {
    if (!refs.length) return '';
    return '<div class="side"><b>' + label + ' · ' + refs.length + '</b><ul>' +
      refs.map(r => '<li><a href="index.html#i-' + r.id + '">' + r.t + '</a> ' +
        '<span class="sec">' + r.sec + ' ' + r.secTitle + '</span></li>').join('') +
      '</ul></div>';
  };

  const blocks = [];
  DATA.areas.forEach(area => {
    const mine = DATA.concepts.filter(c => c.area === area.id);
    if (!mine.length) return;
    const el = document.createElement('section');
    el.id = 'a-' + area.id;
    el.innerHTML = '<h2>' + area.title + '<span class="f">' + mine.length + '</span></h2>' +
      mine.map(c =>
        '<div class="concept" id="c-' + c.id + '">' +
        '<h4>' + c.id + '</h4>' +
        '<p class="what">' + c.what + '</p>' +
        '<p class="links">' + c.code.map(p => '<span class="chip">' + p + '</span>').join('') + '</p>' +
        list('Defined by', c.definedBy) +
        list('Used by', c.usedBy) +
        '</div>').join('');
    wrap.appendChild(el);

    const a = document.createElement('a');
    a.href = '#a-' + area.id;
    a.innerHTML = '<span>' + area.title + '</span><span class="f">' + mine.length + '</span>';
    navEl.appendChild(a);
    blocks.push({ el, navA: a });
  });

  document.getElementById('count').innerHTML =
    '<b>' + DATA.concepts.length + '</b> concepts';

  const q = document.getElementById('q');
  const emptyEl = document.getElementById('empty');
  const cards = [...wrap.querySelectorAll('.concept')].map(el => ({
    el, text: el.textContent.toLowerCase()
  }));

  function applyFilter() {
    const term = q.value.trim().toLowerCase();
    let shown = 0;
    cards.forEach(c => {
      const m = !term || c.text.includes(term);
      c.el.hidden = !m;
      if (m) shown++;
    });
    blocks.forEach(b => {
      const any = [...b.el.querySelectorAll('.concept')].some(c => !c.hidden);
      b.el.hidden = !any;
      b.navA.hidden = !any;
    });
    emptyEl.hidden = shown > 0;
  }
  q.addEventListener('input', applyFilter);
  document.addEventListener('keydown', e => {
    if (e.key === '/' && document.activeElement !== q) { e.preventDefault(); q.focus(); q.select(); }
    if (e.key === 'Escape' && document.activeElement === q) { q.value = ''; applyFilter(); q.blur(); }
  });
  applyFilter();
})();
''';

// ----------------------------------------------------------- the walkthrough

String buildWalkthrough(Catalogue cat) {
  final byScreen = <String, List<Item>>{};
  for (final i in cat.items) {
    byScreen.putIfAbsent(i.screen, () => []).add(i);
  }

  final ordered = [
    for (final s in cat.screens)
      if (s.id != 'none' &&
          ((byScreen[s.id]?.isNotEmpty ?? false) ||
              cat.items.any((i) => i.points.contains(s.id))))
        {
          'id': s.id,
          'title': s.title,
          'route': s.route,
          'reach': s.reach,
          'setup': s.setup,
          // Entries that live elsewhere but describe this screen — the tour.
          // Printed at the top of the block so a pass over a screen also
          // re-reads what the app promises to say about it.
          'describedBy': [
            for (final i in cat.items.where((i) => i.points.contains(s.id)))
              {'id': i.id, 't': i.title, 'sec': i.sectionId, 'secTitle': i.sectionTitle}
          ],
          'items': [
            for (final i in byScreen[s.id]!)
              {
                'id': i.id,
                't': i.title,
                if (i.detail != null) 'd': i.detail,
                'sec': i.sectionId,
                'secTitle': i.sectionTitle,
                'group': i.group,
                'manual': i.manual,
              }
          ],
        }
  ];

  final ruleCount = byScreen['none']?.length ?? 0;
  final data = _json({'screens': ordered, 'rulesWithNoScreen': ruleCount});

  return _shell(
    file: 'walkthrough.html',
    title: 'FossLift — Walkthrough',
    subtitle: 'walkthrough',
    toolbar: '''    <input class="search" id="q" type="search" placeholder="Filter steps…  (/)" autocomplete="off">
    <button class="btn" id="hide" aria-pressed="false">Hide passed</button>
    <button class="btn" id="report">Report</button>
    <button class="btn" id="reset">Reset</button>
    <div class="count" id="count"></div>''',
    body: '''<div class="layout">
  <nav id="nav"></nav>
  <main id="main">
    <p class="lede">The same behaviours as the <a href="index.html">catalogue</a>, ordered by where you look rather than by which feature they belong to — so a pass visits each screen once. Mark each step <b>✓</b> pass, <b>✗</b> fail or <b>–</b> skip; a fail opens a note. <b>Report</b> collects the failures as markdown to paste into an issue.</p>
    <div id="screens"></div>
    <p class="empty" id="empty" hidden>Nothing matches that filter.</p>
    <p class="where" id="footnote"></p>
  </main>
</div>

<dialog id="reportDlg">
  <p style="margin:0 0 4px"><b>Failures and skips</b></p>
  <textarea class="out" id="reportOut" readonly></textarea>
  <p style="margin:12px 0 0; display:flex; gap:8px">
    <button class="btn" id="copyReport">Copy</button>
    <button class="btn" id="closeReport">Close</button>
  </p>
</dialog>''',
    data: data,
    script: _walkthroughJs,
  );
}

const _walkthroughJs = r'''
(function () {
  const DATA = JSON.parse(document.getElementById('data').textContent);
  const KEY = 'fosslift.walkthrough.v1';
  const store = JSON.parse(localStorage.getItem(KEY) || '{}');   // id -> {v, note}
  const save = () => localStorage.setItem(KEY, JSON.stringify(store));

  const wrap = document.getElementById('screens');
  const navEl = document.getElementById('nav');
  navEl.insertAdjacentHTML('beforeend', '<p class="navhead">Screens</p>');

  const steps = [];
  const blocks = [];

  DATA.screens.forEach(scr => {
    const el = document.createElement('section');
    el.className = 'screen';
    el.id = 'scr-' + scr.id;

    let html = '<h2>' + scr.title +
      (scr.route ? ' <span class="num">' + scr.route + '</span>' : '') +
      '<span class="f"></span></h2>';
    if (scr.reach) html += '<p class="reach"><b>Get there:</b> ' + scr.reach + '</p>';
    if (scr.setup) html += '<p class="reach setup"><b>Needs first:</b> ' + scr.setup + '</p>';
    if (scr.describedBy && scr.describedBy.length) {
      html += '<p class="reach"><b>The tour says:</b> ' + scr.describedBy.map(d =>
        '<a href="index.html#i-' + d.id + '">' + d.t + '</a>').join(' · ') + '</p>';
    }

    scr.items.forEach(it => {
      const st = store[it.id] || {};
      html += '<div class="step" id="w-' + it.id + '" data-id="' + it.id + '"' +
        (st.v ? ' data-v="' + st.v + '"' : '') + '>' +
        '<div class="head"><div class="txt">' +
        '<span class="t">' + it.t + '</span>' +
        (it.d ? ' <span class="d">' + it.d + '</span>' : '') +
        '<span class="links">' +
        '<a class="chip" href="index.html#i-' + it.id + '">' + it.sec + ' ' + it.secTitle + '</a>' +
        (it.manual ? '<span class="chip man">manual only</span>' : '') +
        '</span></div>' +
        '<div class="marks">' +
        '<button data-v="pass" title="Pass">✓</button>' +
        '<button data-v="fail" title="Fail">✗</button>' +
        '<button data-v="skip" title="Skip">–</button>' +
        '</div></div>' +
        '<textarea placeholder="What went wrong?">' + (st.note || '') + '</textarea>' +
        '</div>';
    });

    el.innerHTML = html;
    wrap.appendChild(el);

    const a = document.createElement('a');
    a.href = '#scr-' + scr.id;
    a.innerHTML = '<span>' + scr.title + '</span><span class="f"></span>';
    navEl.appendChild(a);

    const mine = [...el.querySelectorAll('.step')];
    mine.forEach(s => steps.push({
      id: s.dataset.id, el: s, scr, text: s.textContent.toLowerCase()
    }));
    blocks.push({ scr, el, navA: a, ids: scr.items.map(i => i.id) });
  });

  document.getElementById('footnote').innerHTML =
    '<b>' + DATA.rulesWithNoScreen + ' behaviours are not on this list.</b> ' +
    'They are rules with no screen to look at — a solver\'s tie-breaking, a wire ' +
    'format, a policy. They are covered by the unit tests, and they stay in the ' +
    '<a href="index.html">catalogue</a>.';

  const countEl = document.getElementById('count');
  const fill = document.getElementById('barfill');

  function tally() {
    let done = 0, total = 0;
    blocks.forEach(b => {
      const marked = b.ids.filter(i => store[i] && store[i].v).length;
      const failed = b.ids.filter(i => store[i] && store[i].v === 'fail').length;
      done += marked; total += b.ids.length;
      const label = marked + '/' + b.ids.length + (failed ? ' · ' + failed + '✗' : '');
      b.navA.querySelector('.f').textContent = label;
      b.el.querySelector('h2 .f').textContent = label;
      const full = marked === b.ids.length;
      b.navA.classList.toggle('full', full && !failed);
      b.el.classList.toggle('full', full && !failed);
    });
    const failed = Object.values(store).filter(s => s.v === 'fail').length;
    countEl.innerHTML = '<b>' + done + '</b> / ' + total + (failed ? ' · ' + failed + '✗' : '');
    fill.style.width = (total ? (done / total * 100) : 0) + '%';
  }

  wrap.addEventListener('click', e => {
    const btn = e.target.closest('.marks button');
    if (!btn) return;
    const step = btn.closest('.step');
    const id = step.dataset.id;
    const v = btn.dataset.v;
    const cur = (store[id] || {}).v;
    if (cur === v) {                       // tapping the current mark clears it
      delete store[id];
      step.removeAttribute('data-v');
    } else {
      store[id] = Object.assign({}, store[id], { v });
      step.dataset.v = v;
      if (v === 'fail') setTimeout(() => step.querySelector('textarea').focus(), 0);
    }
    save(); tally(); applyFilter();
  });

  wrap.addEventListener('input', e => {
    if (e.target.tagName !== 'TEXTAREA') return;
    const id = e.target.closest('.step').dataset.id;
    store[id] = Object.assign({}, store[id], { note: e.target.value });
    save();
  });

  const q = document.getElementById('q');
  const hideBtn = document.getElementById('hide');
  const emptyEl = document.getElementById('empty');
  let hidePassed = false;

  function applyFilter() {
    const term = q.value.trim().toLowerCase();
    let shown = 0;
    steps.forEach(s => {
      const passed = (store[s.id] || {}).v === 'pass';
      const m = (!term || s.text.includes(term)) && (!hidePassed || !passed);
      s.el.hidden = !m;
      if (m) shown++;
    });
    blocks.forEach(b => {
      const any = [...b.el.querySelectorAll('.step')].some(s => !s.hidden);
      b.el.hidden = !any;
      b.navA.hidden = !any;
    });
    emptyEl.hidden = shown > 0;
  }

  q.addEventListener('input', applyFilter);
  hideBtn.addEventListener('click', () => {
    hidePassed = !hidePassed;
    hideBtn.setAttribute('aria-pressed', String(hidePassed));
    hideBtn.textContent = hidePassed ? 'Show all' : 'Hide passed';
    applyFilter();
  });

  document.getElementById('reset').addEventListener('click', () => {
    if (!confirm('Clear every mark and note?')) return;
    Object.keys(store).forEach(k => delete store[k]);
    save();
    wrap.querySelectorAll('.step').forEach(s => { s.removeAttribute('data-v'); });
    wrap.querySelectorAll('textarea').forEach(t => { t.value = ''; });
    tally(); applyFilter();
  });

  const dlg = document.getElementById('reportDlg');
  const out = document.getElementById('reportOut');
  document.getElementById('report').addEventListener('click', () => {
    const lines = [];
    DATA.screens.forEach(scr => {
      const bad = scr.items.filter(i => {
        const v = (store[i.id] || {}).v;
        return v === 'fail' || v === 'skip';
      });
      if (!bad.length) return;
      lines.push('### ' + scr.title + (scr.route ? ' (`' + scr.route + '`)' : ''));
      lines.push('');
      bad.forEach(i => {
        const st = store[i.id];
        lines.push('- **' + (st.v === 'fail' ? 'FAIL' : 'skipped') + '** ' + i.t +
          ' — _' + i.sec + ' ' + i.secTitle + ' · ' + i.group + '_');
        if (st.note) {
          st.note.split('\n').forEach(l => lines.push('  ' + l));
        }
      });
      lines.push('');
    });
    out.value = lines.length ? lines.join('\n') : 'Nothing failed or skipped.';
    dlg.showModal();
  });
  document.getElementById('copyReport').addEventListener('click', () => {
    out.select();
    navigator.clipboard.writeText(out.value);
  });
  document.getElementById('closeReport').addEventListener('click', () => dlg.close());

  document.addEventListener('keydown', e => {
    if (e.key === '/' && document.activeElement !== q && document.activeElement.tagName !== 'TEXTAREA') {
      e.preventDefault(); q.focus(); q.select();
    }
    if (e.key === 'Escape' && document.activeElement === q) { q.value = ''; applyFilter(); q.blur(); }
  });

  const spy = new IntersectionObserver(entries => {
    entries.forEach(en => {
      if (en.isIntersecting) {
        navEl.querySelectorAll('a.on').forEach(a => a.classList.remove('on'));
        const b = blocks.find(x => x.el === en.target);
        if (b) b.navA.classList.add('on');
      }
    });
  }, { rootMargin: '-80px 0px -70% 0px' });
  blocks.forEach(b => spy.observe(b.el));

  tally();
  applyFilter();
})();
''';

// -------------------------------------------------------------------- main

void main(List<String> args) {
  final check = args.contains('--check');
  final root = Directory.current;

  if (!Directory('${root.path}/features/catalogue').existsSync()) {
    stderr.writeln('run this from the repository root');
    exit(2);
  }

  final cat = Catalogue.load(root);
  final findings = validate(cat, root);
  final problems = findings.problems;

  final outputs = {
    'features/index.html': buildIndex(cat),
    'features/concepts.html': buildConcepts(cat),
    'features/walkthrough.html': buildWalkthrough(cat),
  };

  void reportGaps() {
    if (findings.gaps.isEmpty) return;
    stdout.writeln('\n${findings.gaps.length} note(s):');
    for (final g in findings.gaps) {
      stdout.writeln('  $g');
    }
  }

  if (check) {
    // The pages are build artifacts and are not committed, so a fresh clone
    // has none — that is not a failure. A *stale* one is worth saying so
    // nobody reads yesterday's catalogue, but it cannot fail the build either:
    // building the outputs above already proved the source is sound.
    for (final e in outputs.entries) {
      final f = File('${root.path}/${e.key}');
      if (f.existsSync() && f.readAsStringSync() != e.value) {
        findings.gaps.add('${e.key} on disk is stale — run: dart run tool/features.dart');
      }
    }
    if (problems.isNotEmpty) {
      stderr.writeln('${problems.length} problem(s):');
      for (final p in problems) {
        stderr.writeln('  $p');
      }
      exit(1);
    }
    stdout.writeln('catalogue ok — ${cat.items.length} items, '
        '${cat.concepts.length} concepts, ${cat.sections.length} sections');
    reportGaps();
    return;
  }

  // The pages are still written when something is wrong — you want to look at
  // what you just wrote — but a problem is an error, so the exit code says so.
  for (final e in outputs.entries) {
    File('${root.path}/${e.key}').writeAsStringSync(e.value);
    stdout.writeln('wrote ${e.key}');
  }

  final noScreen = cat.items.where((i) => i.screen == 'none').length;
  stdout.writeln('${cat.items.length} items · ${cat.items.length - noScreen} in the '
      'walkthrough · $noScreen pure rules · ${cat.concepts.length} concepts');
  reportGaps();

  if (problems.isNotEmpty) {
    stderr.writeln('\n${problems.length} problem(s):');
    for (final p in problems) {
      stderr.writeln('  $p');
    }
    exit(1);
  }
}
