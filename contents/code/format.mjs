/* SPDX-License-Identifier: MPL-2.0 */

const BINARY_UNITS = ['B', 'KiB', 'MiB', 'GiB', 'TiB', 'PiB'];
const DECIMAL_UNITS = ['B', 'kB', 'MB', 'GB', 'TB', 'PB'];

function finite(value) {
    const number = Number(value);
    return Number.isFinite(number) ? number : null;
}

/** Parse the byte values emitted by different jotta-cli releases. */
export function parseSize(value) {
    if (value === null || value === undefined || value === '')
        return null;
    if (typeof value === 'number')
        return Number.isFinite(value) && value >= 0 ? value : null;
    if (typeof value === 'object') {
        for (const key of ['bytes', 'byteCount', 'sizeBytes', 'value']) {
            if (value[key] !== undefined)
                return parseSize(value[key]);
        }
        return null;
    }

    const text = String(value).trim();
    if (/^(unlimited|infinite|infinity|none|n\/a)$/i.test(text))
        return null;
    const match = text.replace(',', '.').match(/^([0-9]+(?:\.[0-9]+)?)\s*([kmgtpe]?i?b)?(?:\/s)?$/i);
    if (!match)
        return null;
    const amount = finite(match[1]);
    if (amount === null)
        return null;
    const suffix = (match[2] || 'B').toLowerCase();
    const powers = {
        b: 0, kb: 1, mb: 2, gb: 3, tb: 4, pb: 5,
        kib: 1, mib: 2, gib: 3, tib: 4, pib: 5,
    };
    const power = powers[suffix];
    if (power === undefined)
        return null;
    const base = suffix.endsWith('ib') ? 1024 : 1000;
    return amount * Math.pow(base, power);
}

export function formatBytes(bytes, options = {}) {
    const value = finite(bytes);
    if (value === null || value < 0)
        return '-';
    const binary = options.binary !== false;
    const base = binary ? 1024 : 1000;
    const units = binary ? BINARY_UNITS : DECIMAL_UNITS;
    let index = 0;
    let scaled = value;
    while (scaled >= base && index < units.length - 1) {
        scaled /= base;
        index += 1;
    }
    const decimals = index === 0 ? 0 : (scaled >= 100 ? 0 : scaled >= 10 ? 1 : 2);
    return `${scaled.toFixed(decimals)} ${units[index]}`;
}

export function formatPercent(usedBytes, capacityBytes) {
    const used = finite(usedBytes);
    const capacity = finite(capacityBytes);
    if (used === null || capacity === null || capacity <= 0)
        return null;
    return Math.max(0, Math.min(1, used / capacity));
}

export function formatCount(value) {
    const count = finite(value);
    if (count === null)
        return '-';
    return Math.round(count).toLocaleString('en-US');
}

export function formatRate(bytesPerSecond) {
    const rate = finite(bytesPerSecond);
    return rate === null ? '' : `${formatBytes(rate)}/s`;
}

export function formatProgress(progress) {
    const value = finite(progress);
    if (value === null)
        return '';
    return `${Math.round(Math.max(0, Math.min(1, value)) * 100)}%`;
}

/** Encode each path component while retaining separators for a file URL. */
export function fileUrl(path) {
    if (typeof path !== 'string' || !path.trim())
        return '';
    const clean = path.trim();
    if (!clean.startsWith('/'))
        return '';
    return `file://${clean.split('/').map((part) => encodeURIComponent(part)).join('/')}`;
}

export function nonEmpty(value, fallback = '') {
    const text = value === null || value === undefined ? '' : String(value).trim();
    return text || fallback;
}
