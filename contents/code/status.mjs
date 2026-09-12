/* SPDX-License-Identifier: MPL-2.0 */

import { parseSize } from './format.mjs';

export const STATE = Object.freeze({
    UNCONFIGURED: 'unconfigured',
    UNAVAILABLE: 'unavailable',
    OFFLINE: 'offline',
    ERROR: 'error',
    PAUSED: 'paused',
    WORKING: 'working',
    UP_TO_DATE: 'upToDate',
    STALE: 'stale',
    UNKNOWN: 'unknown',
});

export const STATUS = STATE;

function object(value) {
    return value && typeof value === 'object' && !Array.isArray(value) ? value : {};
}

function array(value) {
    return Array.isArray(value) ? value : [];
}

function read(source, names) {
    const value = object(source);
    for (const name of names) {
        if (value[name] !== undefined && value[name] !== null)
            return value[name];
    }
    const wanted = names.map((name) => name.toLowerCase());
    for (const key of Object.keys(value)) {
        if (wanted.includes(key.toLowerCase()) && value[key] !== null)
            return value[key];
    }
    return undefined;
}

function firstPath(source, paths) {
    for (const path of paths) {
        let current = source;
        for (const name of path) {
            current = read(current, [name]);
            if (current === undefined)
                break;
        }
        if (current !== undefined && current !== null)
            return current;
    }
    return undefined;
}

function text(value) {
    if (value === null || value === undefined)
        return '';
    return String(value).trim();
}

function present(value) {
    if (value === null || value === undefined)
        return false;
    if (typeof value === 'string')
        return value.trim().length > 0;
    if (Array.isArray(value))
        return value.length > 0;
    if (typeof value === 'object')
        return Object.keys(value).length > 0;
    return true;
}

function firstPresent(sourceValues, names) {
    for (const source of sourceValues) {
        const value = read(source, names);
        if (present(value))
            return value;
    }
    return undefined;
}

function number(value) {
    if (typeof value === 'number')
        return Number.isFinite(value) ? value : null;
    if (typeof value !== 'string' || !value.trim())
        return null;
    const result = Number(value.replace(/,/g, ''));
    return Number.isFinite(result) ? result : null;
}

function bool(value) {
    if (typeof value === 'boolean')
        return value;
    if (typeof value === 'number')
        return value !== 0;
    if (typeof value === 'string') {
        if (/^(true|yes|on|enabled|active)$/i.test(value.trim()))
            return true;
        if (/^(false|no|off|disabled|inactive)$/i.test(value.trim()))
            return false;
    }
    return null;
}

function timestamp(value) {
    const numeric = number(value);
    if (numeric !== null) {
        const milliseconds = numeric < 10_000_000_000 ? numeric * 1000 : numeric;
        return milliseconds > 0 ? milliseconds : null;
    }
    const parsed = Date.parse(text(value));
    return Number.isFinite(parsed) ? parsed : null;
}

function sizeField(source, names) {
    const value = read(source, names);
    if (value === undefined)
        return { found: false, value: null };
    return { found: true, value: parseSize(value) };
}

function files(source) {
    const root = object(source);
    const nested = object(read(root, ['files', 'fileStats', 'counts', 'Count']));
    const count = number(firstPath(root, [
        ['fileCount'], ['filesCount'], ['count'], ['files', 'count'], ['files', 'total'],
        ['Count', 'Files'], ['Count', 'FileCount'],
    ]));
    const size = parseSize(firstPath(root, [
        ['sizeBytes'], ['bytes'], ['size'], ['files', 'sizeBytes'], ['files', 'size'],
        ['Count', 'Bytes'], ['Count', 'Size'],
    ]));
    return {
        count: count === null ? number(read(nested, ['count', 'total'])) : count,
        sizeBytes: size === null ? parseSize(read(nested, ['sizeBytes', 'size', 'bytes'])) : size,
    };
}

function progress(value) {
    if (value === null || value === undefined)
        return null;
    if (typeof value === 'object') {
        const completed = number(read(value, ['completed', 'complete', 'current', 'done', 'transferred']));
        const total = number(read(value, ['total', 'totalBytes', 'size', 'expected']));
        if (completed !== null && total !== null && total > 0)
            return Math.max(0, Math.min(1, completed / total));
        return progress(read(value, ['progress', 'percent', 'percentage']));
    }
    const parsed = number(String(value).replace('%', ''));
    if (parsed === null)
        return null;
    return Math.max(0, Math.min(1, parsed > 1 ? parsed / 100 : parsed));
}

function transfer(value) {
    const root = object(Array.isArray(value) ? value[0] : value);
    const file = object(read(root, ['file', 'item']));
    return {
        path: text(read(root, ['path', 'filePath', 'remotePath'])) || text(read(file, ['path', 'name'])),
        name: text(read(root, ['name', 'filename', 'fileName'])) || text(read(file, ['name', 'filename'])),
        state: text(read(root, ['state', 'status', 'action'])) || 'unknown',
        progress: progress(read(root, ['progress', 'completion'])),
        transferredBytes: parseSize(read(root, ['transferredBytes', 'transferred', 'uploaded', 'downloaded'])),
        totalBytes: parseSize(read(root, ['totalBytes', 'sizeBytes', 'size'])),
        rateBytesPerSecond: parseSize(read(root, ['rateBytesPerSecond', 'speed', 'rate'])),
        eta: text(read(root, ['eta', 'remaining'])),
    };
}

function list(value) {
    if (Array.isArray(value))
        return value;
    const root = object(value);
    for (const key of ['items', 'entries', 'transfers', 'uploads', 'downloads', 'data']) {
        if (Array.isArray(root[key]))
            return root[key];
    }
    return [];
}

function error(value) {
    if (typeof value === 'string')
        return value.trim() ? { kind: 'error', message: value.trim(), at: null } : null;
    const root = object(value);
    const code = text(read(root, ['kind', 'type', 'code']));
    const message = text(read(root, ['message', 'error', 'description', 'text'])) || code;
    if (!message)
        return null;
    return {
        kind: code || 'error',
        message,
        at: timestamp(read(root, ['at', 'time', 'timestamp', 'createdAt'])),
    };
}

function errors(value) {
    const values = Array.isArray(value) ? value : value ? [value] : [];
    return values.map(error).filter((item) => item && item.message);
}

function mapState(value) {
    const state = text(value).toLowerCase().replace(/[\s_-]+/g, '');
    if (!state)
        return 'unknown';
    if (['working', 'uploading', 'downloading', 'syncing', 'evaluating', 'scanning', 'pending', 'active', 'running', 'connecting'].some((item) => state.startsWith(item)))
        return 'working';
    if (['idle', 'uptodate', 'completed', 'complete', 'listeningtoevents', 'synced'].some((item) => state.startsWith(item)))
        return 'upToDate';
    if (['paused', 'syncpaused', 'pause'].some((item) => state.startsWith(item)))
        return 'paused';
    if (['error', 'failed', 'failure', 'offline', 'disconnected'].some((item) => state.startsWith(item)))
        return state.startsWith('offline') || state.startsWith('disconnected') ? 'offline' : 'error';
    return 'unknown';
}

function syncData(root) {
    const raw = read(root, ['sync', 'synchronization']);
    const sync = typeof raw === 'string' ? { state: raw } : object(raw);
    const systemState = object(read(root, ['state', 'State']));
    const rootPath = text(firstPath(sync, [['path'], ['root'], ['rootPath'], ['localPath']])) ||
        text(firstPath(root, [['syncRoot'], ['syncPath'], ['syncFolder']]));
    const pausedValue = firstPath(sync, [['paused'], ['syncPaused'], ['syncpaused']]) ??
        firstPath(root, [['syncPaused'], ['syncpaused']]);
    const enabledValue = read(sync, ['enabled', 'active']);
    const mode = text(read(sync, ['mode', 'reportingMode']));
    const configuredValue = read(sync, ['configured', 'setup']);
    const configured = bool(configuredValue) ?? Boolean(rootPath);
    const enabled = bool(enabledValue) ?? configured;
    const automatic = bool(read(sync, ['automatic', 'auto'])) ??
        (mode ? !/manual|trigger/i.test(mode) : null);
    const filesRoot = files(sync);
    const rawStateValue = read(sync, ['state', 'State']);
    const stateContainer = object(rawStateValue);
    const directState = read(sync, ['status', 'syncState']) ??
        ((typeof rawStateValue === 'string' || typeof rawStateValue === 'number') ? rawStateValue : undefined);
    const syncStateValue = (typeof directState === 'string' || typeof directState === 'number')
        ? directState
        : (read(stateContainer, ['state', 'status', 'name', 'value', 'State']) ??
           read(systemState, ['state', 'status', 'name', 'value']) ??
           read(root, ['syncState', 'syncStatus']));
    const normalizedState = mapState(syncStateValue);
    const uploadValue = firstPresent([sync, stateContainer, systemState],
        ['upload', 'currentUpload', 'uploading']);
    const downloadValue = firstPresent([sync, stateContainer, systemState],
        ['download', 'currentDownload', 'downloading']);
    const upload = uploadValue === undefined ? null : transfer(uploadValue);
    const download = downloadValue === undefined ? null : transfer(downloadValue);
    const lastUpdate = timestamp(read(sync, ['lastUpdateMs', 'lastUpdated', 'updatedAt']));
    const inferredState = (uploadValue !== undefined || downloadValue !== undefined) &&
        normalizedState !== 'paused' && normalizedState !== 'error'
        ? 'working'
        : normalizedState !== 'unknown' ? normalizedState
        : lastUpdate !== null ? 'upToDate' : normalizedState;
    return {
        configured,
        enabled,
        automatic,
        paused: bool(pausedValue) ?? inferredState === 'paused',
        rootPath,
        mode,
        rawState: text(syncStateValue),
        state: inferredState,
        localFiles: number(firstPath(sync, [
            ['localFiles'], ['files', 'local'], ['local', 'files'], ['Count', 'Files'],
        ])),
        remoteFiles: number(firstPath(sync, [
            ['remoteFiles'], ['files', 'remote'], ['remote', 'files'], ['RemoteCount', 'Files'],
        ])),
        totalFiles: filesRoot.count,
        sizeBytes: filesRoot.sizeBytes,
        progress: progress(read(sync, ['progress', 'completion'])) ??
            progress(read(uploadValue || {}, ['progress', 'completion'])) ??
            progress(read(downloadValue || {}, ['progress', 'completion'])),
        upload,
        download,
    };
}

function backup(value) {
    const root = object(value);
    const fileInfo = files(root);
    return {
        path: text(read(root, ['path', 'root', 'folder', 'localPath'])),
        state: text(read(root, ['state', 'status'])) || 'unknown',
        fileCount: fileInfo.count,
        sizeBytes: fileInfo.sizeBytes,
        error: error(read(root, ['error', 'currentError'])),
    };
}

function unwrap(payload) {
    const root = object(payload);
    if (root.data && typeof root.data === 'object' && !Array.isArray(root.data)) {
        if (root.data.status && typeof root.data.status === 'object')
            return root.data.status;
        return root.data;
    }
    if (root.status && typeof root.status === 'object')
        return root.status;
    return root;
}

export function emptySnapshot() {
    return {
        account: { email: '', name: '' },
        device: { name: '', id: '' },
        storage: { usedBytes: null, capacityBytes: null, unlimited: false },
        sync: {
            configured: false, enabled: false, automatic: null, paused: false,
            rootPath: '', mode: '', rawState: '', state: 'unknown', localFiles: null,
            remoteFiles: null, totalFiles: null, sizeBytes: null, progress: null,
            upload: null, download: null,
        },
        backups: [],
        transfers: { uploads: [], downloads: [] },
        activity: [],
        errors: [],
        currentError: null,
        updatedAt: null,
        receivedAt: null,
        raw: {},
    };
}

export function normalizeStatus(payload) {
    const root = unwrap(payload);
    const userRoot = object(read(root, ['user', 'User']));
    const accountInfo = read(userRoot, ['accountInfo', 'account', 'AccountInfo']);
    const accountValue = accountInfo ?? read(root, ['account', 'user']);
    const accountRoot = object(accountValue);
    const deviceValue = read(root, ['device']) ?? read(userRoot, ['device', 'Device']);
    const deviceRoot = object(deviceValue);
    const storageRoot = object(read(root, ['storage', 'capacity']));
    const usageRoot = object(read(root, ['usage']));
    const accountUsageRoot = object(read(accountRoot, ['usage', 'storage', 'Usage', 'Storage']));
    const usedCandidates = [storageRoot, usageRoot, accountUsageRoot, accountRoot, root];
    const capacityCandidates = [storageRoot, usageRoot, accountUsageRoot, accountRoot, root];
    const usedField = usedCandidates.map((item) => sizeField(item,
        ['usedBytes', 'used', 'usage', 'consumed', 'storageUsed'])).find((item) => item.found) ||
        { found: false, value: null };
    const capacityField = capacityCandidates.map((item) => sizeField(item,
        ['capacityBytes', 'capacity', 'total', 'quota', 'limit', 'storageLimit'])).find((item) => item.found) ||
        { found: false, value: null };
    const rootUsed = sizeField(root, ['usedBytes', 'used', 'usage', 'consumed']);
    const rootCapacity = sizeField(root, ['capacityBytes', 'capacity', 'quota', 'limit', 'total']);
    const backupsValue = read(root, ['backups', 'backup', 'backupFolders', 'folders']);
    const syncRoot = object(read(root, ['sync', 'synchronization']));
    const currentError = error(read(root, ['currentError', 'error', 'lastError'])) ||
        error(read(syncRoot, ['currentError', 'error', 'lastError']));
    return {
        account: {
            email: text(read(accountRoot, ['email', 'username', 'user', 'Email', 'Username'])) ||
                (typeof accountValue === 'string' ? text(accountValue) : '') ||
                text(read(root, ['email', 'username', 'Email', 'Username'])),
            name: text(read(accountRoot, ['name', 'displayName', 'Name'])),
        },
        device: {
            name: text(read(deviceRoot, ['name', 'hostname', 'deviceName', 'Name'])) ||
                (typeof deviceValue === 'string' ? text(deviceValue) : '') ||
                text(read(root, ['deviceName', 'DeviceName'])),
            id: text(read(deviceRoot, ['id', 'deviceId', 'Id', 'DeviceId'])),
        },
        storage: {
            usedBytes: usedField.found ? usedField.value : rootUsed.value,
            capacityBytes: capacityField.found ? capacityField.value : rootCapacity.value,
            unlimited: /unlimited|infinite|infinity/i.test(text(read(storageRoot, ['capacity', 'quota', 'limit']))) ||
                /unlimited|infinite|infinity/i.test(text(read(usageRoot, ['capacity', 'quota', 'limit']))) ||
                /unlimited|infinite|infinity/i.test(text(read(accountUsageRoot, ['capacity', 'quota', 'limit', 'total', 'storageLimit']))) ||
                /unlimited|infinite|infinity/i.test(text(read(accountRoot, ['capacity', 'quota', 'limit', 'total', 'storageLimit']))) ||
                /unlimited|infinite|infinity/i.test(text(read(root, ['capacity', 'quota', 'limit', 'total']))),
        },
        sync: syncData(root),
        backups: list(backupsValue).map(backup).filter((item) => item.path || item.state !== 'unknown'),
        transfers: {
            uploads: list(read(root, ['uploads', 'uploadTransfers', 'transfers']))
                .map(transfer),
            downloads: list(read(root, ['downloads', 'downloadTransfers', 'transfers']))
                .map(transfer),
        },
        activity: list(read(root, ['activity', 'recentActivity', 'syncLog', 'log']))
            .map((item) => typeof item === 'string' ? { message: item, at: null, state: 'unknown' } : {
                message: text(read(item, ['message', 'path', 'file', 'description'])),
                at: timestamp(read(item, ['at', 'time', 'timestamp', 'createdAt'])),
                state: text(read(item, ['state', 'status', 'action'])) || 'unknown',
            }).filter((item) => item.message),
        errors: dedupeErrors(errors(read(root, ['errors', 'recentErrors', 'errorLog']))),
        currentError,
        updatedAt: timestamp(read(root, ['updatedAt', 'lastUpdated', 'timestamp', 'time'])) ??
            timestamp(read(syncRoot, ['lastUpdateMs'])),
        receivedAt: null,
        raw: root,
    };
}

export const normalizeDashboard = normalizeStatus;

export function errorFingerprint(value) {
    const item = error(value) || value;
    if (!item || !item.message)
        return '';
    return `${text(item.kind).toLowerCase()}|${text(item.message).replace(/\s+/g, ' ').toLowerCase()}`;
}

export function dedupeErrors(values, limit = 20) {
    const result = [];
    const seen = new Set();
    for (const item of array(values)) {
        const normalized = error(item);
        const key = errorFingerprint(normalized);
        if (!key || seen.has(key))
            continue;
        seen.add(key);
        result.push(normalized);
        if (result.length >= limit)
            break;
    }
    return result;
}

function errorState(commandError) {
    if (!commandError)
        return null;
    const kind = text(commandError.kind).toLowerCase();
    if (['unavailable', 'not-found', 'spawn'].includes(kind))
        return STATE.UNAVAILABLE;
    if (['offline', 'network', 'timeout'].includes(kind))
        return STATE.OFFLINE;
    return STATE.ERROR;
}

export function deriveState({
    snapshot = null,
    commandError = null,
    offline = false,
    now = Date.now(),
    pollMs = 30_000,
} = {}) {
    const failure = errorState(commandError);
    if (failure)
        return failure;
    if (!snapshot || !snapshot.sync) {
        return offline ? STATE.OFFLINE : STATE.UNKNOWN;
    }
    if (offline)
        return STATE.OFFLINE;
    if (snapshot.currentError)
        return STATE.ERROR;
    if (!snapshot.sync.configured)
        return STATE.UNCONFIGURED;

    const received = Number(snapshot.receivedAt || snapshot.updatedAt || 0);
    if (received > 0 && now - received > Math.max(30_000, Math.round(pollMs * 2.5)))
        return STATE.STALE;
    const syncState = mapState(snapshot.sync.state);
    if (snapshot.sync.paused || syncState === STATE.PAUSED)
        return STATE.PAUSED;
    if (syncState === STATE.WORKING)
        return STATE.WORKING;
    if (syncState === STATE.UP_TO_DATE)
        return STATE.UP_TO_DATE;
    if (syncState === STATE.OFFLINE)
        return STATE.OFFLINE;
    if (syncState === STATE.ERROR)
        return STATE.ERROR;
    return STATE.UNKNOWN;
}

export const stateFor = deriveState;
export const isErrorState = (state) => [STATE.UNAVAILABLE, STATE.OFFLINE, STATE.ERROR].includes(state);
export const isKnownState = (state) => Object.values(STATE).includes(state);
