/* SPDX-License-Identifier: MPL-2.0 */

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

import {
    STATE, dedupeErrors, deriveState, errorFingerprint, normalizeStatus,
} from '../contents/code/status.mjs';

const fixture = JSON.parse(await readFile(new URL('./fixtures/status.json', import.meta.url)));

test('normalizes the synthetic dashboard fixture', () => {
    const snapshot = normalizeStatus(fixture);
    assert.equal(snapshot.account.email, 'demo@example.invalid');
    assert.equal(snapshot.device.name, 'example-device');
    assert.equal(snapshot.storage.usedBytes, 3 * 1024 ** 3);
    assert.equal(snapshot.storage.capacityBytes, 8 * 1024 ** 3);
    assert.equal(snapshot.sync.rootPath, '/tmp/example/Cloud Sync');
    assert.equal(snapshot.sync.state, STATE.WORKING);
    assert.equal(snapshot.sync.localFiles, 12);
    assert.equal(snapshot.sync.remoteFiles, 14);
    assert.equal(snapshot.sync.upload.progress, 0.42);
    assert.equal(snapshot.backups[0].fileCount, 23);
    assert.equal(snapshot.transfers.uploads.length, 1);
    assert.equal(snapshot.activity[0].message, 'Uploaded example.txt');
});

test('normalizes nested usage and sync errors without treating missing capacity as unlimited', () => {
    const snapshot = normalizeStatus({
        usage: { used: '2 GiB', total: '8 GiB' },
        sync: { configured: true, path: '/sync', state: 'Idle', error: { code: 'daemon-error' } },
    });
    assert.equal(snapshot.storage.usedBytes, 2 * 1024 ** 3);
    assert.equal(snapshot.storage.capacityBytes, 8 * 1024 ** 3);
    assert.equal(snapshot.storage.unlimited, false);
    assert.equal(snapshot.currentError.kind, 'daemon-error');
    assert.equal(snapshot.currentError.message, 'daemon-error');
});

test('normalizes the capitalized nested fields used by current CLI status JSON', () => {
    const snapshot = normalizeStatus({
        User: {
            AccountInfo: {
                Email: 'demo@example.invalid',
                Usage: { Used: '3 GiB', Total: '12 GiB' },
            },
        },
        Device: { Name: 'example-device' },
        Sync: {
            Root: '/tmp/example/Sync',
            Count: { Files: 9, Bytes: '1 GiB' },
            RemoteCount: { Files: 11 },
            State: {
                State: 'Idle',
                Uploading: { Name: 'example-photo.jpg', Progress: 50 },
            },
        },
    });
    assert.equal(snapshot.account.email, 'demo@example.invalid');
    assert.equal(snapshot.device.name, 'example-device');
    assert.equal(snapshot.storage.usedBytes, 3 * 1024 ** 3);
    assert.equal(snapshot.storage.capacityBytes, 12 * 1024 ** 3);
    assert.equal(snapshot.sync.rootPath, '/tmp/example/Sync');
    assert.equal(snapshot.sync.localFiles, 9);
    assert.equal(snapshot.sync.remoteFiles, 11);
    assert.equal(snapshot.sync.state, STATE.WORKING);
    assert.equal(snapshot.sync.upload.name, 'example-photo.jpg');
});

test('normalizes the live CLI status shape with top-level state', () => {
    const snapshot = normalizeStatus({
        User: {
            Email: 'demo@example.invalid',
            AccountInfo: { Capacity: 12 * 1024 ** 3, Usage: 3 * 1024 ** 3 },
            device: { Name: 'example-device' },
        },
        Sync: {
            Enabled: true,
            Automatic: true,
            RootPath: '/tmp/example/Sync',
            Count: { Files: 9, Bytes: 1 * 1024 ** 3 },
            RemoteCount: { Files: 9 },
            LastUpdateMS: 1789209657883,
        },
        State: { RestoreWorking: true, Uploading: {}, Downloading: {} },
    });
    assert.equal(snapshot.device.name, 'example-device');
    assert.equal(snapshot.sync.state, STATE.UP_TO_DATE);
    assert.equal(snapshot.sync.upload, null);
    assert.equal(snapshot.sync.download, null);
    assert.equal(snapshot.updatedAt, 1789209657883);
});

test('top-level active transfer state makes the sync state working', () => {
    const snapshot = normalizeStatus({
        Sync: { RootPath: '/sync', LastUpdateMS: 1789209657883 },
        State: { Uploading: { Name: 'example-photo.jpg', Progress: 50 }, Downloading: {} },
    });
    assert.equal(snapshot.sync.state, STATE.WORKING);
    assert.equal(snapshot.sync.upload.name, 'example-photo.jpg');
});

test('missing and additional fields become safe defaults', () => {
    const snapshot = normalizeStatus({
        account: null,
        sync: { configured: false, state: 'FutureState' },
        storage: { capacity: 'Unlimited' },
        extra: { shouldNotMatter: true },
    });
    assert.equal(snapshot.account.email, '');
    assert.equal(snapshot.storage.capacityBytes, null);
    assert.equal(snapshot.storage.unlimited, true);
    assert.equal(snapshot.sync.state, 'unknown');
    assert.deepEqual(snapshot.backups, []);
});

test('known sync states are mapped and unknown future states stay unknown', () => {
    assert.equal(normalizeStatus({ sync: { path: '/sync', state: 'Idle' } }).sync.state,
        STATE.UP_TO_DATE);
    assert.equal(normalizeStatus({ sync: { path: '/sync', state: 'Paused' } }).sync.state,
        STATE.PAUSED);
    assert.equal(normalizeStatus({ sync: { path: '/sync', state: 'BrandNewState' } }).sync.state,
        STATE.UNKNOWN);
    assert.equal(normalizeStatus({ sync: { path: '/sync', state: 'Paused' } }).sync.paused, true);
    assert.equal(normalizeStatus({ sync: { path: '/sync', error: '' } }).currentError, null);
});

test('deriveState covers configuration, command, sync, and freshness outcomes', () => {
    const base = normalizeStatus({ sync: { configured: true, path: '/sync', state: 'Idle' } });
    assert.equal(deriveState({ snapshot: normalizeStatus({ sync: { configured: false } }) }),
        STATE.UNCONFIGURED);
    assert.equal(deriveState({ commandError: { kind: 'unavailable', message: 'missing' } }),
        STATE.UNAVAILABLE);
    assert.equal(deriveState({ commandError: { kind: 'network', message: 'offline' } }),
        STATE.OFFLINE);
    assert.equal(deriveState({ snapshot: normalizeStatus({ sync: { configured: false } }),
        commandError: { kind: 'unavailable', message: 'missing' } }), STATE.UNAVAILABLE);
    assert.equal(deriveState({ snapshot: base }), STATE.UP_TO_DATE);
    assert.equal(deriveState({ snapshot: { ...base, sync: { ...base.sync, paused: true } } }),
        STATE.PAUSED);
    assert.equal(deriveState({ snapshot: { ...base, sync: { ...base.sync, state: STATE.WORKING } } }),
        STATE.WORKING);
    assert.equal(deriveState({ snapshot: { ...base, receivedAt: 1 }, now: 100_000,
        pollMs: 30_000 }), STATE.STALE);
    assert.equal(deriveState({ snapshot: { ...base, sync: { ...base.sync, state: 'unknown' } } }),
        STATE.UNKNOWN);
});

test('errors have stable fingerprints and dedupe equivalent entries', () => {
    assert.equal(errorFingerprint({ kind: 'Auth', message: ' Login required ' }),
        'auth|login required');
    assert.deepEqual(dedupeErrors([
        { kind: 'network', message: 'Connection lost' },
        { kind: 'network', message: ' connection   lost ' },
        { kind: 'auth', message: 'Login required' },
    ]).map((item) => item.kind), ['network', 'auth']);
});
