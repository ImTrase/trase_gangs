import { get } from 'svelte/store';
import { locales } from '../stores/localeStore';

export function t(key: string, fallback?: string): string {
  const current = get(locales);
  return current[key] || fallback || key;
}
