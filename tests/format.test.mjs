/* SPDX-License-Identifier: MPL-2.0 */

import { test } from 'node:test';
import assert from 'node:assert/strict';

import {
    parseSize, formatBytes, formatPercent, formatProgress, fileUrl,
} from '../contents/code/format.mjs';

test('parseSize accepts binary and decimal CLI values', () => {
    assert.equal(parseSize('1.5 GiB'), 1.5 * 1024 ** 3);
    assert.equal(parseSize('2 MiB/s'), 2 * 1024 ** 2);
    assert.equal(parseSize('10 MB'), 10 * 1000 ** 2);
    assert.equal(parseSize({ bytes: 123 }), 123);
    assert.equal(parseSize('unlimited'), null);
    assert.equal(parseSize('not a size'), null);
});

test('formatBytes selects readable binary units', () => {
    assert.equal(formatBytes(0), '0 B');
    assert.equal(formatBytes(1024), '1.00 KiB');
    assert.equal(formatBytes(10 * 1024 ** 2), '10.0 MiB');
    assert.equal(formatBytes(null), '-');
});

test('formatPercent clamps and treats unlimited capacity as absent', () => {
    assert.equal(formatPercent(5, 10), 0.5);
    assert.equal(formatPercent(20, 10), 1);
    assert.equal(formatPercent(1, null), null);
});

test('formatProgress accepts both fractions and percentages', () => {
    assert.equal(formatProgress(0.42), '42%');
    assert.equal(formatProgress(42), '42%');
    assert.equal(formatProgress(null), '');
});

test('fileUrl only accepts absolute paths and encodes path components', () => {
    assert.equal(fileUrl('/tmp/example/My Files'), 'file:///tmp/example/My%20Files');
    assert.equal(fileUrl('relative/file'), '');
});
