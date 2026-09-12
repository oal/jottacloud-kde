/* SPDX-License-Identifier: MPL-2.0 */

export const DEFAULT_EXECUTABLE = 'jotta-cli';
export const DEFAULT_TIMEOUT_MS = 12_000;

export const OPERATION = Object.freeze({
    STATUS: 'status',
    UPLOADS: 'uploads',
    DOWNLOADS: 'downloads',
    ACTIVITY: 'activity',
    GET_PAUSED: 'getPaused',
    SET_PAUSED: 'setPaused',
});

export class CliError extends Error {
    constructor(kind, message, details = {}) {
        super(message);
        this.name = 'CliError';
        this.kind = kind;
        Object.assign(this, details);
    }
}

function positiveInteger(value, fallback) {
    const number = Number(value);
    return Number.isInteger(number) && number > 0 ? number : fallback;
}

export function executableOrDefault(value) {
    const text = value === null || value === undefined ? '' : String(value).trim();
    return text || DEFAULT_EXECUTABLE;
}

/** Construct only the fixed, approved CLI argument lists. */
export function argsFor(operation, value = 5) {
    switch (operation) {
    case OPERATION.STATUS:
        return ['status', '--json'];
    case OPERATION.UPLOADS:
        return ['list', 'uploads', '--json'];
    case OPERATION.DOWNLOADS:
        return ['list', 'downloads', '--json'];
    case OPERATION.ACTIVITY:
        return ['sync', 'log', '-n', String(positiveInteger(value, 5))];
    case OPERATION.GET_PAUSED:
        return ['config', 'syncpaused'];
    case OPERATION.SET_PAUSED:
        if (typeof value !== 'boolean')
            throw new TypeError('setPaused requires a boolean');
        return ['config', 'syncpaused', value ? 'true' : 'false'];
    default:
        throw new RangeError(`Unsupported jotta-cli operation: ${operation}`);
    }
}

export const commandArgs = argsFor;

/**
 * Quote the complete command for Plasma's executable data engine. The engine
 * accepts one command string, so every executable and fixed argument is quoted
 * here before it crosses that boundary. No widget data is interpolated into a
 * shell fragment elsewhere.
 */
export function shellQuote(value) {
    const text = String(value);
    if (/^[A-Za-z0-9_./:@%+=,-]+$/.test(text))
        return text;
    return `'${text.replace(/'/g, "'\\''")}'`;
}

export function commandLine(executable, args) {
    if (!Array.isArray(args))
        throw new TypeError('CLI arguments must be an array');
    return [executableOrDefault(executable), ...args.map(String)].map(shellQuote).join(' ');
}

export const buildCommand = commandLine;

export function parseJson(stdout) {
    if (typeof stdout !== 'string' || !stdout.trim())
        throw new CliError('parse', 'jotta-cli returned no JSON output');
    try {
        return JSON.parse(stdout);
    } catch (error) {
        throw new CliError('parse', 'jotta-cli returned malformed JSON', { cause: error });
    }
}

/**
 * `sync log` is a text command in the supported CLI versions. Keep it
 * separate from JSON parsing while still presenting useful rows in the
 * dashboard. A future release returning JSON is accepted too.
 */
export function parseActivity(stdout) {
    if (typeof stdout !== 'string' || !stdout.trim())
        return [];
    const trimmed = stdout.trim();
    if (trimmed.startsWith('[') || trimmed.startsWith('{')) {
        const value = parseJson(trimmed);
        return Array.isArray(value) ? value : (Array.isArray(value.activity) ? value.activity : []);
    }
    return trimmed.split(/\r?\n/)
        .map((line) => line.trim())
        .filter((line) => line.length > 0)
        .map(parseActivityLine);
}

function parseActivityLine(line) {
    const match = line.match(/^(\d{4}-\d{2}-\d{2})\s+(\d{2}:\d{2}:\d{2}(?:\.\d+)?)\s+([+-]\d{4})?\s*(?:[A-Z]{2,5})?\s*::\s*(\S+)(?:\s+(.*))?$/);
    if (!match)
        return { message: line, at: null, state: 'unknown' };

    const action = match[4];
    const verbs = {
        delete: 'Deleted',
        download: 'Downloaded',
        move: 'Moved',
        remove: 'Removed',
        rename: 'Renamed',
        upload: 'Uploaded',
    };
    const message = `${verbs[action.toLowerCase()] || action}${match[5] ? ` ${match[5]}` : ''}`;
    const at = `${match[1]}T${match[2]}${match[3] || ''}`;
    return { message, at, state: action.toLowerCase() };
}

export function resultError({ exitCode, stderr = '', stdout = '' } = {}) {
    const code = Number(exitCode);
    const detail = String(stderr || stdout || '').trim();
    if (code === 127 || /not found|no such file|cannot execute/i.test(detail))
        return new CliError('unavailable', detail || 'jotta-cli executable was not found', { exitCode: code });
    if (/login|authenticat|token|unauthori[sz]ed/i.test(detail))
        return new CliError('auth', detail || 'Jottacloud authentication is required', { exitCode: code });
    if (/timed out|timeout|network|connection|daemon/i.test(detail))
        return new CliError('offline', detail || 'could not reach the Jottacloud daemon', { exitCode: code });
    return new CliError('command', detail || `jotta-cli exited with status ${code}`, { exitCode: code });
}

export function parseResult(result) {
    if (!result || Number(result.exitCode) !== 0)
        throw resultError(result || {});
    return parseJson(result.stdout);
}

export function isAllowedOperation(operation) {
    return Object.values(OPERATION).includes(operation);
}

/** Ignore a late callback from a command superseded by a newer request. */
export function isCurrentRequest(requestId, latestRequestId) {
    return Number(requestId) === Number(latestRequestId);
}
