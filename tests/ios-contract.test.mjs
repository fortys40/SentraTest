import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { before, after, test } from 'node:test';
import { readFile, readdir } from 'node:fs/promises';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { PGlite } from '@electric-sql/pglite';
import { parse } from 'yaml';

const root = fileURLToPath(new URL('../', import.meta.url));
const database = new PGlite();
let modelSource;

const tableModels = {
  match_formats: 'MatchFormat',
  profiles: 'Profile',
  groups: 'Group',
  group_members: 'GroupMember',
  group_invites: 'GroupInvite',
  guests: 'Guest',
  match_series: 'MatchSeries',
  series_skips: 'SeriesSkip',
  matches: 'Match',
  rsvps: 'RSVP',
  rsvp_history: 'RSVPHistoryEntry',
  web_responders: 'WebResponder',
  match_participants: 'MatchParticipant',
  goals: 'Goal',
  payments: 'Payment',
  mvp_eligible_voters: 'MVPEligibleVoter',
  mvp_votes: 'MVPVote',
  mvp_results: 'MVPResult',
  badge_definitions: 'BadgeDefinition',
  player_badges: 'PlayerBadge',
  device_tokens: 'DeviceToken',
};

const viewModels = {
  match_rsvp_counts: 'MatchRSVPCounts',
  outstanding_payments: 'OutstandingPayment',
  player_stats_view: 'PlayerStats',
  late_cancellations_view: 'LateCancellation',
};

const enumModels = {
  player_position: 'FootballPosition',
  member_role: 'GroupRole',
  match_status: 'MatchStatus',
  rsvp_status: 'RSVPStatus',
  team_side: 'TeamSide',
  match_winner: 'MatchWinner',
};

before(async () => {
  await database.exec(await readFile(join(root, 'tests/bootstrap.sql'), 'utf8'));
  const migrations = (await readdir(join(root, 'supabase/migrations')))
    .filter((name) => name.endsWith('.sql')).sort();
  for (const migration of migrations) {
    await database.exec(await readFile(join(root, 'supabase/migrations', migration), 'utf8'));
  }
  const directory = join(root, 'ios/Sentra/Models');
  const files = (await readdir(directory)).filter((name) => name.endsWith('.swift'));
  modelSource = (await Promise.all(files.map((name) => readFile(join(directory, name), 'utf8')))).join('\n');
});

after(() => database.close());

function storedProperties(model) {
  const body = modelSource.match(new RegExp(
    '^struct ' + model + ': Codable, Identifiable, Hashable, Sendable \\{([\\s\\S]*?)^}', 'm',
  ))?.[1];
  assert.ok(body, `${model}: expected explicit wire model declaration`);
  const properties = new Map([...body.matchAll(/^    let (\w+): ([^\n{=]+)$/gm)]
    .map((match) => [match[1], match[2].trim()]));
  const keys = [...body.matchAll(/^        case (\w+)(?: = "([^"]+)")?$/gm)];
  assert.equal(keys.length, properties.size, `${model}: each stored property needs a CodingKey`);
  return new Map(keys.map((match) => {
    assert.ok(properties.has(match[1]), `${model}.${match[1]}: missing property`);
    return [match[2] ?? match[1], properties.get(match[1])];
  }));
}

test('Swift wire properties match actual PostgreSQL columns, types and nullability', async () => {
  const swiftTypes = {
    uuid: ['UUID'], text: ['String'], bool: ['Bool'], int2: ['Int'], int4: ['Int'],
    int8: ['Int64'], numeric: ['Decimal'], timestamptz: ['Date'], date: ['String'],
    time: ['String'], jsonb: ['JSONValue', '[String: JSONValue]'], _uuid: ['[UUID]'],
    ...Object.fromEntries(Object.entries(enumModels).map(([name, model]) => [name, [model]])),
  };
  for (const [table, model] of Object.entries(tableModels)) {
    const { rows } = await database.query(`select column_name, udt_name, is_nullable, generation_expression
      from information_schema.columns where table_schema = 'public' and table_name = $1
      order by ordinal_position`, [table]);
    assert.ok(rows.length, `${table}: deployed table missing`);
    const properties = storedProperties(model);
    assert.deepEqual([...properties.keys()].sort(), rows.map((row) => row.column_name).sort(), model);
    for (const column of rows) {
      const propertyType = properties.get(column.column_name);
      const generatedCapacity = table === 'matches' && column.column_name === 'capacity';
      if (generatedCapacity) assert.equal(column.generation_expression, '(players_per_team * 2)');
      assert.equal(propertyType.endsWith('?'), !generatedCapacity && column.is_nullable === 'YES', `${model}.${column.column_name}: nullability`);
      assert.ok(swiftTypes[column.udt_name]?.includes(propertyType.replace(/\?$/, '')),
        `${model}.${column.column_name}: ${column.udt_name} must not become ${propertyType}`);
    }
  }
});

test('all deployed public tables and view columns have mappings', async () => {
  const tables = await database.query("select tablename from pg_tables where schemaname = 'public'");
  assert.deepEqual(Object.keys(tableModels).sort(), tables.rows.map((row) => row.tablename).sort());
  const views = await database.query("select viewname from pg_views where schemaname = 'public'");
  assert.deepEqual([...Object.keys(viewModels), 'rsvps_with_waitlist_position'].sort(), views.rows.map((row) => row.viewname).sort());
  for (const [view, model] of Object.entries(viewModels)) {
    const { rows } = await database.query(`select column_name from information_schema.columns
      where table_schema = 'public' and table_name = $1`, [view]);
    assert.deepEqual([...storedProperties(model).keys()].sort(), rows.map((row) => row.column_name).sort(), model);
  }
  const waitlist = await database.query(`select column_name from information_schema.columns
    where table_schema = 'public' and table_name = 'rsvps_with_waitlist_position'`);
  assert.deepEqual(waitlist.rows.map((row) => row.column_name).sort(), [...storedProperties('RSVP').keys(), 'position_in_waitlist'].sort());
});

test('Swift enum raw values match the six PostgreSQL enums exactly', async () => {
  for (const [name, model] of Object.entries(enumModels)) {
    const { rows } = await database.query(`select enumlabel from pg_enum
      join pg_type on pg_type.oid = enumtypid where typname = $1 order by enumsortorder`, [name]);
    const body = modelSource.match(new RegExp('^enum ' + model + ': String,[\\s\\S]*?^}', 'm'))?.[0];
    assert.ok(body, model);
    const values = [...body.matchAll(/^    case (\w+)(?: = "([^"]+)")?$/gm)]
      .map((match) => match[2] ?? match[1]);
    assert.deepEqual(values, rows.map((row) => row.enumlabel), model);
  }
});

test('XcodeGen declares iOS 17 targets, pinned Supabase and optional local configuration', async () => {
  const project = parse(await readFile(join(root, 'ios/project.yml'), 'utf8'));
  assert.equal(project.name, 'Sentra');
  assert.equal(project.targets.Sentra.deploymentTarget, '17.0');
  assert.equal(project.targets.SentraTests.deploymentTarget, '17.0');
  assert.equal(project.targets.Sentra.settings.base.PRODUCT_BUNDLE_IDENTIFIER, 'com.sarantos.sentra');
  assert.equal(project.packages.Supabase.exactVersion, '2.20.0');
  assert.deepEqual(project.schemes.Sentra.test.targets, ['SentraTests']);
  const base = await readFile(join(root, 'ios/Config/Base.xcconfig'), 'utf8');
  assert.match(base, /#include\? "Config.xcconfig"/);
  for (const key of ['SUPABASE_URL', 'SUPABASE_ANON_KEY', 'UNIVERSAL_LINK_DOMAIN', 'REVENUECAT_PUBLIC_SDK_KEY']) {
    assert.match(base, new RegExp('^' + key + ' =', 'm'));
  }
});

test('live service writes use only deployed CRUD RPC signatures and the profile allowlist', async () => {
  const requests = await readFile(join(root, 'ios/Sentra/Services/Protocols/ServiceRequests.swift'), 'utf8');
  const operations = {
    create_group: 'GroupCreation', update_group: 'GroupUpdate',
    create_match: 'MatchCreation', update_match: 'MatchUpdate', cancel_match: 'MatchIdentifier',
  };
  for (const [rpc, model] of Object.entries(operations)) {
    const { rows } = await database.query(`select proargnames from pg_proc
      where pronamespace = 'public'::regnamespace and proname = $1`, [rpc]);
    assert.equal(rows.length, 1, rpc);
    const body = requests.match(new RegExp('^struct ' + model + ':[\\s\\S]*?^}', 'm'))?.[0];
    assert.ok(body, model);
    const keys = [...body.matchAll(/^        case \w+ = "([^"]+)"$/gm)].map((match) => match[1]);
    assert.deepEqual(keys, rows[0].proargnames, rpc);
  }
  const directory = join(root, 'ios/Sentra/Services/Live');
  const files = (await readdir(directory)).filter((name) => name.endsWith('.swift'));
  const source = (await Promise.all(files.map((name) => readFile(join(directory, name), 'utf8')))).join('\n');
  const calls = [...source.matchAll(/\.rpc\("([^"]+)"/g)].map((match) => match[1]);
  assert.deepEqual(calls.sort(), Object.keys(operations).sort());
  assert.doesNotMatch(source, /\.from\("(?:mvp_votes|mvp_eligible_voters|web_responders|rating_history|card_designs|user_card_designs)"/);
  assert.doesNotMatch(source, /\.(?:insert|upsert|delete)\(/);
  const profile = requests.match(/^struct ProfileUpdate:[\s\S]*?^}/m)[0];
  const profileKeys = [...profile.matchAll(/^        case (\w+)(?: = "([^"]+)")?$/gm)]
    .map((match) => match[2] ?? match[1]);
  assert.deepEqual(profileKeys.sort(), ['avatar_url', 'display_name', 'onboarding_completed', 'position']);
  assert.match(profile, /encodeNil\(forKey: \.avatarURL\)/);
});

test('offline fixture source uses stable time and identities and has Greek/English catalog data', async () => {
  const factory = await readFile(join(root, 'ios/Sentra/Services/Mock/MockDataFactory.swift'), 'utf8');
  assert.doesNotMatch(factory, /\b(?:Date|UUID)\(\)|\b(?:random|randomElement)\(/);
  assert.match(factory, /Date\(timeIntervalSince1970: 1_791_374_400\)/);
  assert.doesNotMatch(factory, /import Supabase|SupabaseClient\(/);
  const catalog = JSON.parse(await readFile(join(root, 'ios/Sentra/Resources/Localizable.xcstrings'), 'utf8'));
  assert.equal(catalog.sourceLanguage, 'el');
  for (const [key, value] of Object.entries(catalog.strings)) {
    for (const locale of ['el', 'en']) {
      assert.equal(value.localizations[locale].stringUnit.state, 'translated', `${key}/${locale}`);
      assert.ok(value.localizations[locale].stringUnit.value.length, `${key}/${locale}`);
    }
  }
  for (let index = 1; index <= 12; index++) {
    const name = catalog.strings[`mock.player.${String(index).padStart(2, '0')}`].localizations.el.stringUnit.value;
    assert.match(name, /\p{Script=Greek}/u);
  }
});

test('core text and RSVP colors meet normal-text contrast on both theme surfaces', async () => {
  const theme = await readFile(join(root, 'ios/Sentra/Core/Theme/SentraTheme.swift'), 'utf8');
  const colors = Object.fromEntries([...theme.matchAll(/static let (\w+) = (?:adaptive|solid)\(0x([A-F0-9]+)(?:, 0x([A-F0-9]+))?\)/g)]
    .map((match) => [match[1], [match[2], match[3] ?? match[2]].map((hex) => Number.parseInt(hex, 16))]));
  const luminance = (color) => {
    const channels = [16, 8, 0].map((shift) => ((color >> shift) & 255) / 255)
      .map((value) => value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4);
    return channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722;
  };
  const dashboard = await readFile(join(root, 'ios/Sentra/Features/Preview/StepTwoDashboardPreview.swift'), 'utf8');
  const heroOpacity = Number(dashboard.match(/background\(SentraTheme\.Colors\.mvpSurface\.opacity\(([\d.]+)\)\)/)[1]);
  const brightestHeroBackground = [16, 8, 0].reduce((color, shift) => color |
    Math.round(((colors.mvpSurface[0] >> shift) & 255) * heroOpacity + 255 * (1 - heroOpacity)) << shift, 0);
  assert.ok((luminance(colors.onMVP[0]) + 0.05) / (luminance(brightestHeroBackground) + 0.05) >= 4.5,
    'Hero text must remain readable even over a pure-white photo pixel.');
  for (const mode of [0, 1]) {
    for (const [foreground, background] of [
      ['ink', 'background'], ['mutedInk', 'surface'], ['primary', 'surface'],
      ['warning', 'surface'], ['danger', 'surface'], ['waitlist', 'surface'],
      ['onPrimary', 'primary'], ['onPrimary', 'danger'],
      ['onBrand', 'brand'], ['onBrand', 'noFill'], ['onMaybe', 'maybeFill'],
      ['primary', 'yesSurface'], ['warning', 'maybeSurface'],
      ['danger', 'noSurface'], ['waitlist', 'waitlistSurface'],
      ['onMVP', 'mvpSurface'], ['mutedMVP', 'mvpSurface'], ['mvpAccent', 'mvpRaised'],
      ['onPremium', 'premiumSurface'], ['bronze', 'premiumSurface'],
      ['silver', 'premiumSurface'], ['gold', 'premiumSurface'], ['elite', 'premiumSurface'],
    ]) {
      const values = [luminance(colors[foreground][mode]), luminance(colors[background][mode])].sort((left, right) => right - left);
      const ratio = (values[0] + 0.05) / (values[1] + 0.05);
      assert.ok(ratio >= 4.5, `${foreground}/${background}, mode ${mode}: ${ratio.toFixed(2)}`);
    }
  }
});

test('app launch is offline and all requested routes remain placeholders', async () => {
  const app = await readFile(join(root, 'ios/Sentra/App/SentraApp.swift'), 'utf8');
  assert.match(app, /AppEnvironment\.preview\(data: MockDataFactory\.make\(referenceDate: Date\(\)\)\)/);
  assert.doesNotMatch(app, /AppEnvironment\.live|AppConfiguration\.load/);
  const routes = await readFile(join(root, 'ios/Sentra/App/AppRoute.swift'), 'utf8');
  const cases = [...routes.matchAll(/^    case (\w+)/gm)].map((match) => match[1]);
  assert.deepEqual(cases, ['welcome', 'profileSetup', 'groups', 'groupDetail', 'createGroup',
    'matchDetail', 'createMatch', 'invite', 'finishMatch', 'mvpVoting', 'mvpResult', 'playerCard', 'profile', 'settings']);
  const router = await readFile(join(root, 'ios/Sentra/App/AppRouter.swift'), 'utf8');
  assert.match(router, /NavigationStack\(path:/);
  assert.match(router, /navigationDestination\(for: AppRoute\.self\)/);
  const links = await readFile(join(root, 'ios/Sentra/App/DeepLinkHandler.swift'), 'utf8');
  assert.match(links, /func route\(for _: URL\) -> AppRoute\? \{ nil \}/);
});

test('reference-aligned controls use filled RSVP roles and a numbered adaptive progress header', async () => {
  const buttons = await readFile(join(root, 'ios/Sentra/Core/Components/SentraButtons.swift'), 'utf8');
  assert.match(buttons, /foregroundStyle\(status\.buttonForeground\)/);
  assert.match(buttons, /background\(status\.buttonBackground/);
  assert.match(buttons, /disabled\(status == \.waitlist\)/);
  assert.match(buttons, /accessibilityAddTraits\(isSelected \? \.isSelected/);
  const primitives = await readFile(join(root, 'ios/Sentra/Core/Components/SentraPrimitives.swift'), 'utf8');
  assert.match(primitives, /background: status\.chipBackground/);
  assert.match(primitives, /stepTitles: \[LocalizedStringResource\]/);
  assert.match(primitives, /dynamicTypeSize\.isAccessibilitySize/);
  assert.match(primitives, /ForEach\(1\.\.\.total/);
  assert.match(primitives, /let current = min\(max\(currentStep, 0\), total\)/);
  const card = await readFile(join(root, 'ios/Sentra/Core/Components/PlayerCardShell.swift'), 'utf8');
  assert.match(card, /SentraCardSilhouette: InsettableShape/);
  assert.match(card, /Colors\.premiumSurface/);
  assert.match(card, /example\.profile\.position\.shortLabel/);
  assert.match(card, /statistic\("card\.goals"/);
  assert.doesNotMatch(card, /design: \.rounded|CardPalette/);
});

test('design dashboard has all requested visual samples without authentication or voting commands', async () => {
  const dashboard = await readFile(join(root, 'ios/Sentra/Features/Preview/StepTwoDashboardPreview.swift'), 'utf8');
  for (const marker of ['welcomeHero', 'Image("WelcomePitch")', 'MatchSummaryCard(', 'RSVPButton(',
    'PlayerRow(', 'SentraSegmentedTabs(', 'SentraProgressHeader(', 'mvpSample(', 'PlayerCardShell(']) {
    assert.ok(dashboard.includes(marker), marker);
  }
  assert.match(dashboard, /ForEach\(\[RSVPStatus\.yes, \.maybe, \.no\]\)/);
  assert.match(dashboard, /sampleMVP = sampleMVP == id \? nil : id/);
  assert.match(dashboard, /stepTitles: \["progress\.players", "progress\.result", "progress\.cost"\]/);
  assert.doesNotMatch(dashboard, /Supabase|cast_vote|set_rsvp|finish_match|signIn|signOut|\.rpc\(/);
  const catalog = JSON.parse(await readFile(join(root, 'ios/Sentra/Resources/Localizable.xcstrings'), 'utf8'));
  const greek = (key) => catalog.strings[key].localizations.el.stringUnit.value;
  assert.deepEqual(['goalkeeper', 'defender', 'midfielder', 'forward'].map((position) => greek(`position.${position}.short`)),
    ['ΤΕΡ', 'ΑΜΥ', 'ΜΕΣ', 'ΕΠΙ']);
  assert.equal(greek('card.goals'), 'ΓΚΟΛ');
});

test('original mockup and offline hero artwork are present with matching resource metadata', async () => {
  const reference = await readFile(join(root, 'docs/mockups/sentra-flow.png'));
  assert.equal(createHash('sha256').update(reference).digest('hex'), '6d30be1471aee7f2b1878219129cf099175b9760c3b03329f2243ebd125d1160');
  const assetPath = join(root, 'ios/Sentra/Resources/Assets.xcassets/WelcomePitch.imageset');
  const catalog = JSON.parse(await readFile(join(assetPath, 'Contents.json'), 'utf8'));
  const hero = await readFile(join(assetPath, catalog.images[0].filename));
  assert.deepEqual([...hero.subarray(0, 8)], [137, 80, 78, 71, 13, 10, 26, 10]);
  assert.equal(hero.readUInt32BE(16), 134);
  assert.equal(hero.readUInt32BE(20), 136);
  const backgrounds = JSON.parse(await readFile(join(root, 'ios/Sentra/Resources/Assets.xcassets/Background.colorset/Contents.json'), 'utf8'));
  assert.deepEqual(backgrounds.colors.map(({ color }) => ['red', 'green', 'blue']
    .map((channel) => Math.round(Number(color.components[channel]) * 255))), [[245, 247, 245], [16, 26, 21]]);
});

test('Swift test JSON contains exact columns for all public-table and view models', async () => {
  const fixture = JSON.parse(await readFile(join(root, 'ios/SentraTests/Fixtures/supabase-rows.json'), 'utf8'));
  const mapping = {
    format: 'match_formats', profile: 'profiles', group: 'groups', member: 'group_members',
    invite: 'group_invites', guest: 'guests', series: 'match_series', skip: 'series_skips',
    match: 'matches', rsvp: 'rsvps', history: 'rsvp_history', participant: 'match_participants',
    goal: 'goals', payment: 'payments', eligibleVoter: 'mvp_eligible_voters', vote: 'mvp_votes',
    mvpResult: 'mvp_results', badgeDefinition: 'badge_definitions', playerBadge: 'player_badges',
    deviceToken: 'device_tokens', webResponder: 'web_responders',
    waitlistResponse: 'rsvps_with_waitlist_position', counts: 'match_rsvp_counts',
    outstandingPayment: 'outstanding_payments', stats: 'player_stats_view', lateCancellation: 'late_cancellations_view',
  };
  for (const [key, table] of Object.entries(mapping)) {
    const { rows } = await database.query(`select column_name, is_nullable, data_type from information_schema.columns
      where table_schema = 'public' and table_name = $1`, [table]);
    assert.deepEqual(Object.keys(fixture[key]).sort(), rows.map((row) => row.column_name).sort(), key);
    for (const column of rows) {
      const value = fixture[key][column.column_name];
      if (column.is_nullable === 'NO') assert.notEqual(value, null, `${key}.${column.column_name}`);
      if (value !== null && column.data_type === 'timestamp with time zone') {
        assert.match(value, /(?:Z|[+-]\d{2}:\d{2})$/);
      }
    }
  }
});

async function sourceFiles(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  const nested = await Promise.all(entries.map((entry) => entry.isDirectory()
    ? sourceFiles(join(directory, entry.name)) : [join(directory, entry.name)]));
  return nested.flat();
}

test('all UI localization keys exist in the Greek and English string catalog', async () => {
  const catalogText = await readFile(join(root, 'ios/Sentra/Resources/Localizable.xcstrings'), 'utf8');
  assert.doesNotThrow(() => parse(catalogText));
  const catalog = JSON.parse(catalogText);
  const files = (await sourceFiles(join(root, 'ios/Sentra'))).filter((path) => path.endsWith('.swift'));
  const source = (await Promise.all(files.map((path) => readFile(path, 'utf8')))).join('\n');
  const literals = [...source.matchAll(/"((?:\\.|[^"\\])*)"/g)].map((match) => match[1]);
  const prefixes = /^(?:app|error|rsvp|position|match|player|waitlist|card|tier|title|progress|preview|action|appearance|state|empty|route)\./;
  for (const literal of literals.filter((value) => prefixes.test(value))) {
    if (literal.includes('\\(') && !literal.includes(' ')) continue;
    const key = literal.replace(/\\\([^)]*\)/g, '%lld');
    assert.ok(catalog.strings[key], `Missing string catalog key: ${key}`);
    for (const locale of ['el', 'en']) assert.ok(catalog.strings[key].localizations[locale], `${key}/${locale}`);
  }
  for (const value of Object.values(catalog.strings)) {
    const placeholders = (locale) => (value.localizations[locale].stringUnit.value.match(/%(?:\d+\$)?(?:lld|@)/g) ?? [])
      .map((placeholder) => placeholder.replace(/\d+\$/, '')).sort();
    assert.deepEqual(placeholders('el'), placeholders('en'));
  }
});

test('requested components, one client constructor and only preview features are present', async () => {
  const files = (await sourceFiles(join(root, 'ios/Sentra'))).filter((path) => path.endsWith('.swift'));
  const source = (await Promise.all(files.map((path) => readFile(path, 'utf8')))).join('\n');
  for (const name of ['SentraPrimaryButton', 'SentraSecondaryButton', 'SentraDestructiveButton',
    'SentraCard', 'SentraSectionHeader', 'SentraChip', 'SentraStatusBadge', 'SentraAvatar',
    'SentraEmptyState', 'RSVPButton', 'PlayerRow', 'MatchSummaryCard', 'LoadingOverlay',
    'ErrorStateView', 'SentraProgressHeader', 'PlayerCardShell']) {
    assert.match(source, new RegExp('struct ' + name + '(?:<|:)'), name);
  }
  assert.equal([...source.matchAll(/\bSupabaseClient\(/g)].length, 1);
  assert.doesNotMatch(source, /\.(?:signInWithOTP|signInWithIdToken|exchangeCodeForSession|requestAuthorization)\(/);
  assert.deepEqual(await readdir(join(root, 'ios/Sentra/Features')), ['Preview']);
  const resources = (await sourceFiles(join(root, 'ios/Sentra/Resources'))).filter((path) => path.endsWith('.json'));
  for (const path of resources) {
    const contents = await readFile(path, 'utf8');
    assert.doesNotThrow(() => JSON.parse(contents));
  }
});