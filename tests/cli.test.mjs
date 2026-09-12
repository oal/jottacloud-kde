/* SPDX-License-Identifier: MPL-2.0 */

import { test } from 'node:test';
import assert from 'node:assert/strict';

import {
    CliError, OPERATION, argsFor, commandLine, parseActivity, parseResult, resultError,
    isAllowedOperation, isCurrentRequest,
} from '../contents/code/cli.mjs';

test('approved read and control commands have fixed argument shapes', () => {
    assert.deepEqual(argsFor(OPERATION.STATUS), ['status', '--json']);
    assert.deepEqual(argsFor(OPERATION.UPLOADS), ['list', 'uploads', '--json']);
    assert.deepEqual(argsFor(OPERATION.DOWNLOADS), ['list', 'downloads', '--json']);
    assert.deepEqual(argsFor(OPERATION.ACTIVITY, 3), ['sync', 'log', '-n', '3']);
    assert.deepEqual(argsFor(OPERATION.SET_PAUSED, true), ['config', 'syncpaused', 'true']);
    assert.deepEqual(argsFor(OPERATION.SET_PAUSED, false), ['config', 'syncpaused', 'false']);
    assert.throws(() => argsFor(OPERATION.SET_PAUSED, 'true'), TypeError);
});

test('commandLine quotes an executable and every argument', () => {
    const command = commandLine('/tmp/jotta cli', ['status', '--json', "x'y"]);
    assert.equal(command, "'/tmp/jotta cli' status --json 'x'\\''y'");
    assert.ok(!command.includes('; rm'));
});

test('parseResult validates exit status before parsing JSON', () => {
    assert.deepEqual(parseResult({ exitCode: 0, stdout: '{"ok":true}' }), { ok: true });
    assert.throws(() => parseResult({ exitCode: 2, stderr: 'login required' }),
        (error) => error instanceof CliError && error.kind === 'auth');
    assert.throws(() => parseResult({ exitCode: 0, stdout: '<not json>' }),
        (error) => error instanceof CliError && error.kind === 'parse');
});

test('parseActivity accepts the text output of sync log', () => {
    assert.deepEqual(parseActivity('first event\nsecond event\n').map((item) => item.message),
        ['first event', 'second event']);
    assert.deepEqual(parseActivity('[{"message":"json event"}]')[0], { message: 'json event' });
});

test('parseActivity makes sync log rows readable', () => {
    const [item] = parseActivity(
        '2026-09-12 12:28:06.795 +0200 CEST :: Download /3D printing/photo.blend\n');
    assert.equal(item.message, 'Downloaded /3D printing/photo.blend');
    assert.equal(item.at, '2026-09-12T12:28:06.795+0200');
    assert.equal(item.state, 'download');
});

test('command failures are classified for user-facing state', () => {
    assert.equal(resultError({ exitCode: 127, stderr: 'not found' }).kind, 'unavailable');
    assert.equal(resultError({ exitCode: 1, stderr: 'connection refused' }).kind, 'offline');
    assert.equal(resultError({ exitCode: 1, stderr: 'unexpected failure' }).kind, 'command');
});

test('only approved operations and current request ids are accepted', () => {
    assert.equal(isAllowedOperation(OPERATION.STATUS), true);
    assert.equal(isAllowedOperation('sync reset'), false);
    assert.equal(isCurrentRequest(4, 4), true);
    assert.equal(isCurrentRequest(3, 4), false);
});
