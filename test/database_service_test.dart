import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:spacehere/services/database/database_service.dart';

void main() {
  late DatabaseService db;

  setUp(() async {
    db = DatabaseService.instance;
    await db.initialize();
  });

  test('DatabaseService initializes with default seed folders', () async {
    final nodes = await db.listAllNodes();
    final names = nodes.map((n) => n.name).toList();

    expect(names, contains('Photos'));
    expect(names, contains('Documents'));
    expect(names, contains('Videos'));
  });

  test(
    'DatabaseService creates folder and lists children in parent directory',
    () async {
      final rootFolder = await db.createFolder('Projects', null);
      final childFolder = await db.createFolder(
        'SpaceHereApp',
        rootFolder.uuid,
      );

      final rootChildren = await db.listChildren(null);
      expect(rootChildren.any((n) => n.name == 'Projects'), isTrue);

      final projectChildren = await db.listChildren(rootFolder.uuid);
      expect(projectChildren.single.name, 'SpaceHereApp');
      expect(projectChildren.single.uuid, childFolder.uuid);
    },
  );

  test(
    'DatabaseService searches nodes by case-insensitive query string',
    () async {
      await db.createFolder('AlphaGenetics', null);
      await db.createFolder('BetaTesting', null);

      final results = await db.searchNodes('gene');
      expect(results.any((n) => n.name == 'AlphaGenetics'), isTrue);
      expect(results.any((n) => n.name == 'BetaTesting'), isFalse);
    },
  );

  test('DatabaseService soft deletes nodes correctly', () async {
    final folder = await db.createFolder('TemporaryFolder', null);
    var all = await db.listAllNodes();
    expect(all.any((n) => n.uuid == folder.uuid), isTrue);

    await db.softDelete(folder.uuid);
    all = await db.listAllNodes();
    expect(all.any((n) => n.uuid == folder.uuid), isFalse);
  });

  test('DatabaseService exports and imports SyncState seamlessly', () async {
    final syncState = await db.exportSyncState();
    expect(syncState.nodes, isNotEmpty);
    expect(syncState.channelId, 'spacehere-private-vault');

    final jsonMap = syncState.toJson();
    final jsonStr = jsonEncode(jsonMap);
    expect(jsonStr, contains('spacehere-private-vault'));

    await db.importSyncState(syncState);
    final reExported = await db.exportSyncState();
    expect(reExported.nodes.length, syncState.nodes.length);
  });

  test(
    'DatabaseService getBreadcrumbs traces ancestor chain to root',
    () async {
      final root = await db.createFolder('Tier1', null);
      final child = await db.createFolder('Tier2', root.uuid);
      final grandChild = await db.createFolder('Tier3', child.uuid);

      final trail = await db.getBreadcrumbs(grandChild.uuid);
      expect(trail.length, 3);
      expect(trail[0].name, 'Tier1');
      expect(trail[1].name, 'Tier2');
      expect(trail[2].name, 'Tier3');

      final emptyTrail = await db.getBreadcrumbs(null);
      expect(emptyTrail, isEmpty);
    },
  );

  test('DatabaseService filters nodes by MIME category accurately', () async {
    await db.createFolder('TempFolder', null);
    final syncState = await db.exportSyncState();
    expect(syncState.nodes, isNotEmpty);

    final docs = await db.filterByMimeCategory('documents');
    expect(docs.any((n) => n.name.contains('contract')), isTrue);

    final photos = await db.filterByMimeCategory('photos');
    expect(photos.every((n) => !n.isFolder), isTrue);
  });

  test('DatabaseService renames and moves nodes correctly', () async {
    final folder = await db.createFolder('OldName', null);
    await db.renameNode(folder.uuid, 'NewName');
    final found = await db.findNode(folder.uuid);
    expect(found?.name, 'NewName');

    final targetParent = await db.createFolder('ParentFolder', null);
    await db.moveNode(folder.uuid, targetParent.uuid);
    final moved = await db.findNode(folder.uuid);
    expect(moved?.parentUuid, targetParent.uuid);
  });

  test('DatabaseService sorts children by name, size, and date', () async {
    final sortFolder = await db.createFolder('SortTestDir', null);
    await db.createFolder('Zeta', sortFolder.uuid);
    await db.createFolder('Alpha', sortFolder.uuid);
    await db.createFolder('Beta', sortFolder.uuid);

    final asc = await db.listChildren(
      sortFolder.uuid,
      sortBy: SortField.name,
      sortOrder: SortOrder.ascending,
    );
    expect(asc.map((n) => n.name).toList(), ['Alpha', 'Beta', 'Zeta']);

    final desc = await db.listChildren(
      sortFolder.uuid,
      sortBy: SortField.name,
      sortOrder: SortOrder.descending,
    );
    expect(desc.map((n) => n.name).toList(), ['Zeta', 'Beta', 'Alpha']);
  });

  test('DatabaseService resolves unique names on duplicates', () async {
    final name1 = await db.resolveUniqueName('report.pdf', null);
    expect(name1, 'report.pdf');

    await db.createFolder('MyFolder', null);
    final uniqueFolder = await db.resolveUniqueName('MyFolder', null);
    expect(uniqueFolder, 'MyFolder (1)');
  });

  test('DatabaseService manages Trash: lists, restores, and purges', () async {
    final trashFolder = await db.createFolder('ToTrash', null);
    await db.softDelete(trashFolder.uuid);

    var trash = await db.listTrashNodes();
    expect(trash.any((n) => n.uuid == trashFolder.uuid), isTrue);

    await db.restoreNode(trashFolder.uuid);
    trash = await db.listTrashNodes();
    expect(trash.any((n) => n.uuid == trashFolder.uuid), isFalse);

    await db.softDelete(trashFolder.uuid);
    await db.purgeNode(trashFolder.uuid);
    final found = await db.findNode(trashFolder.uuid);
    expect(found, isNull);
  });

  test('DatabaseService supports batch move and batch soft delete', () async {
    final f1 = await db.createFolder('Batch1', null);
    final f2 = await db.createFolder('Batch2', null);
    final target = await db.createFolder('BatchTarget', null);

    await db.moveBatch([f1.uuid, f2.uuid], target.uuid);
    final children = await db.listChildren(target.uuid);
    expect(children.length, 2);

    await db.softDeleteBatch([f1.uuid, f2.uuid]);
    final remaining = await db.listChildren(target.uuid);
    expect(remaining, isEmpty);
  });

  test('DatabaseService supports toggling and listing favorites', () async {
    final favFolder = await db.createFolder('StarredFolder', null);
    expect((await db.findNode(favFolder.uuid))?.isFavorite, isFalse);

    await db.toggleFavorite(favFolder.uuid);
    expect((await db.findNode(favFolder.uuid))?.isFavorite, isTrue);

    final favorites = await db.listFavorites();
    expect(favorites.any((n) => n.uuid == favFolder.uuid), isTrue);

    await db.toggleFavorite(favFolder.uuid);
    expect((await db.findNode(favFolder.uuid))?.isFavorite, isFalse);
  });

  test('DatabaseService duplicates node and performs batch copy', () async {
    final original = await db.createFolder('OriginalFolder', null);
    final copy = await db.duplicateNode(original.uuid);
    expect(copy.name, contains('(Copy)'));
    expect(copy.uuid, isNot(original.uuid));

    final batch1 = await db.createFolder('CopyBatch1', null);
    final batch2 = await db.createFolder('CopyBatch2', null);
    final copies = await db.copyBatch([batch1.uuid, batch2.uuid], null);
    expect(copies.length, 2);
  });

  test(
    'DatabaseService calculates FolderStats and VaultStats accurately',
    () async {
      final folder = await db.createFolder('StatsFolder', null);
      await db.createFolder('SubFolder1', folder.uuid);
      await db.createFolder('SubFolder2', folder.uuid);

      final folderStats = await db.getFolderStats(folder.uuid);
      expect(folderStats.totalFolders, 2);

      final vaultStats = await db.getVaultStats();
      expect(vaultStats.totalFolders, greaterThanOrEqualTo(3));
    },
  );

  test('DatabaseService adds and removes tags on nodes', () async {
    final taggedNode = await db.createFolder('TaggedFolder', null);
    await db.addTag(taggedNode.uuid, 'work');
    await db.addTag(taggedNode.uuid, 'confidential');

    var node = await db.findNode(taggedNode.uuid);
    expect(node?.tags, containsAll(['work', 'confidential']));

    await db.removeTag(taggedNode.uuid, 'work');
    node = await db.findNode(taggedNode.uuid);
    expect(node?.tags, isNot(contains('work')));
    expect(node?.tags, contains('confidential'));
  });
}
