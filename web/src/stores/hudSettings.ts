// src/stores/hudSettings.ts
import { writable } from 'svelte/store';

export type HudVariant = 'square' | 'circle' | 'rectangle' | 'half';
type Vec2 = { x: number; y: number };
type HudPositions = { player: Vec2; money: Vec2 };

const POS_KEY = 'trase_hud_positions_v1';

function getScreenDefaults(): HudPositions {
    return {
    player: { x: 24, y: 24 },
    money:  { x: typeof window !== 'undefined' ? window.innerWidth - 260 : 24, y: 24 },
    };
}

function loadHudPositions(): HudPositions {
  try {
    const raw = localStorage.getItem(POS_KEY);
    if (!raw) return getScreenDefaults();
    return { ...getScreenDefaults(), ...JSON.parse(raw) };
  } catch {
    return getScreenDefaults();
  }
}

function saveHudPositions(p: HudPositions) {
  localStorage.setItem(POS_KEY, JSON.stringify(p));
}

export function resetHudPositions() {
  const p = getScreenDefaults();
  saveHudPositions(p);
  hudSettings.update(s => ({ ...s, positions: p }));
}

// If you want a full settings reset (colors/toggles/etc.), edit here:
function getDefaultSettings() {
    return {
        // player values
        health: 75,
        armor: 40,
        hunger: 90,
        thirst: 60,

        // HUD colors
        healthColor: '#E51D35',
        armorColor: '#5D2DC2',
        hungerColor: '#E9A021',
        thirstColor: '#19C1E5',

        // money / misc
        displayCash: true,
        displayBank: true,
        displayDirty: true,
        displayAmmo: true,
        displayId: true,
        displayJob: true,
        money: 1000,
        dirtyMoney: 500,
        ammo: 30,

        // toggles: player UI
        displayHealth: true,
        displayArmor: true,
        displayHunger: true,
        displayThirst: true,
        displayPostal: true,
        displayStreet: true,

        // branding
        logo: 'Trappin Southside',
        logoSmall: 'by Trappin Team',
        logoColor: '#8A2BE2',
        logoSmallColor: '#ddd',

        // layout
        variant: 'square' as HudVariant,

        moveMode: false as boolean,
        positions: loadHudPositions() as HudPositions,
    };
}

export const hudSettings = writable(getDefaultSettings());

export function setMoveMode(v: boolean) {
  hudSettings.update(s => ({ ...s, moveMode: v }));
}

export function updateHudPosition(slot: keyof HudPositions, pos: Vec2) {
  hudSettings.update(s => {
    const positions = { ...s.positions, [slot]: pos };
    saveHudPositions(positions);
    return { ...s, positions };
  });
}

// Optional: full reset, not just positions
export function resetAllHud() {
  localStorage.removeItem(POS_KEY);
  hudSettings.set(getDefaultSettings());
}
