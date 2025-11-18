import { writable } from 'svelte/store';

interface Locales {
    [key: string]: string;
}

// Create a writable store for locales
export const locales = writable<Locales>({});

// Helper function to get a locale with fallback
export function getLocaleSync(key: string, fallback?: string): string {
    let currentLocales: Locales = {};
    locales.subscribe(value => currentLocales = value)();
    return currentLocales[key] || fallback || key;
}
