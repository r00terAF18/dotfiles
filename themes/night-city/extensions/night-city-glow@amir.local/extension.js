// SPDX-License-Identifier: GPL-3.0-or-later
// Night City Glow: a neon border with a soft glow around the focused window.
//
// One St.Widget sits in global.window_group directly above the focused window's actor and
// follows its frame rectangle through window signals (no polling). The border and glow are
// drawn once in white; the colour comes from a Clutter.ColorizeEffect whose tint is the only
// thing the animation timer changes, so a tick costs a uniform update and a repaint, not a
// re-render of the blurred shadow. The timer runs only while a border is visible and the
// mode is animated.

import Clutter from 'gi://Clutter';
import Cogl from 'gi://Cogl';
import GLib from 'gi://GLib';
import Meta from 'gi://Meta';
import St from 'gi://St';

import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

import {PALETTE} from './palette.js';

const WINDOW_TYPES = [
    Meta.WindowType.NORMAL,
    Meta.WindowType.DIALOG,
    Meta.WindowType.MODAL_DIALOG,
];

const MOVE_OPS = [
    Meta.GrabOp.MOVING,
    Meta.GrabOp.MOVING_UNCONSTRAINED,
    Meta.GrabOp.KEYBOARD_MOVING,
];

function parseHex(hex) {
    const m = /^#?([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})$/i.exec(String(hex).trim());
    return m ? [parseInt(m[1], 16), parseInt(m[2], 16), parseInt(m[3], 16)] : null;
}

function hsvToRgb(h, s, v) {
    const c = v * s;
    const x = c * (1 - Math.abs(((h / 60) % 2) - 1));
    const m = v - c;
    const [r, g, b] =
        h < 60 ? [c, x, 0] : h < 120 ? [x, c, 0] : h < 180 ? [0, c, x]
            : h < 240 ? [0, x, c] : h < 300 ? [x, 0, c] : [c, 0, x];
    return [r, g, b].map(k => Math.round((k + m) * 255));
}

export default class NightCityGlowExtension extends Extension {
    enable() {
        this._settings = this.getSettings();
        this._window = null;
        this._windowSignals = [];
        this._timerId = 0;
        this._resizing = false;
        this._start = GLib.get_monotonic_time();

        this._tint = new Clutter.ColorizeEffect();
        this._border = new St.Widget({
            name: 'night-city-glow',
            reactive: false,
            can_focus: false,
            track_hover: false,
            visible: false,
        });
        this._border.add_effect(this._tint);
        global.window_group.add_child(this._border);

        this._displaySignals = [
            global.display.connect('notify::focus-window', () => this._trackFocus()),
            global.display.connect('restacked', () => this._restack()),
            global.display.connect('in-fullscreen-changed', () => this._refresh()),
            global.display.connect('grab-op-begin', (_d, win, op) => {
                // Moving just translates the border; resizing would re-render the glow every
                // frame, so it's hidden until the resize ends.
                if (win === this._window && !MOVE_OPS.includes(op)) {
                    this._resizing = true;
                    this._refresh();
                }
            }),
            global.display.connect('grab-op-end', () => {
                if (this._resizing) {
                    this._resizing = false;
                    this._refresh();
                }
            }),
        ];
        this._workspaceSignal = global.workspace_manager.connect(
            'active-workspace-changed', () => this._refresh());
        this._overviewSignals = [
            Main.overview.connect('showing', () => this._refresh()),
            Main.overview.connect('hidden', () => this._refresh()),
        ];
        this._settingsSignal = this._settings.connect('changed', () => this._loadSettings());

        this._loadSettings();
        this._trackFocus();
    }

    disable() {
        this._stopTimer();
        this._untrackWindow();
        for (const id of this._displaySignals)
            global.display.disconnect(id);
        this._displaySignals = [];
        global.workspace_manager.disconnect(this._workspaceSignal);
        for (const id of this._overviewSignals)
            Main.overview.disconnect(id);
        this._overviewSignals = [];
        this._settings.disconnect(this._settingsSignal);

        this._border.destroy();
        this._border = null;
        this._tint = null;
        this._settings = null;
        this._colors = null;
        this._lastRgb = null;
    }

    _loadSettings() {
        const s = this._settings;
        this._mode = s.get_string('mode');
        this._period = Math.max(0.5, s.get_double('cycle-seconds'));
        this._fps = Math.min(60, Math.max(5, s.get_int('fps')));
        this._onMaximized = s.get_boolean('show-on-maximized');
        this._width = s.get_int('border-width');

        const custom = s.get_strv('colors').map(parseHex).filter(c => c);
        this._colors = custom.length ? custom : PALETTE.cycle.map(parseHex);

        const glow = s.get_int('glow-size');
        // Drawn in white; the ColorizeEffect tints it.
        this._border.set_style(
            `border: ${this._width}px solid #ffffff;` +
            ` border-radius: ${s.get_int('border-radius')}px;` +
            (glow > 0 ? ` box-shadow: 0 0 ${glow}px ${Math.round(glow / 4)}px rgba(255, 255, 255, 0.6);` : ''));

        this._lastRgb = null;
        this._stopTimer();
        this._refresh();
    }

    _trackFocus() {
        const win = global.display.focus_window;
        if (win !== this._window) {
            this._untrackWindow();
            if (win && WINDOW_TYPES.includes(win.get_window_type())) {
                this._window = win;
                const refresh = () => this._refresh();
                this._windowSignals = [
                    win.connect('position-changed', () => this._updateGeometry()),
                    win.connect('size-changed', refresh),
                    win.connect('notify::minimized', refresh),
                    win.connect('notify::fullscreen', refresh),
                    win.connect('notify::maximized-horizontally', refresh),
                    win.connect('notify::maximized-vertically', refresh),
                    win.connect('workspace-changed', refresh),
                    win.connect('unmanaging', () => {
                        this._untrackWindow();
                        this._refresh();
                    }),
                ];
            }
        }
        this._refresh();
    }

    _untrackWindow() {
        if (this._window) {
            for (const id of this._windowSignals)
                this._window.disconnect(id);
        }
        this._window = null;
        this._windowSignals = [];
    }

    _shouldShow() {
        const w = this._window;
        if (!w || this._resizing || Main.overview.visible)
            return false;
        if (w.minimized || w.is_fullscreen())
            return false;
        if (!this._onMaximized && w.is_maximized())
            return false;
        if (!w.located_on_workspace(global.workspace_manager.get_active_workspace()))
            return false;
        return !!w.get_compositor_private();
    }

    _refresh() {
        if (!this._border)
            return;
        if (!this._shouldShow()) {
            this._border.hide();
            this._stopTimer();
            return;
        }
        this._updateGeometry();
        this._restack();
        this._paint();
        this._border.show();
        if (this._mode === 'static')
            this._stopTimer();
        else
            this._startTimer();
    }

    _updateGeometry() {
        if (!this._window || !this._border)
            return;
        const r = this._window.get_frame_rect();
        const w = this._width;
        this._border.set_position(r.x - w, r.y - w);
        this._border.set_size(r.width + 2 * w, r.height + 2 * w);
    }

    _restack() {
        const actor = this._window?.get_compositor_private();
        if (!actor || !this._border || actor.get_parent() !== global.window_group)
            return;
        global.window_group.set_child_above_sibling(this._border, actor);
    }

    _colorAt(t) {
        const cols = this._colors;
        if (this._mode === 'rainbow')
            return hsvToRgb((t % 1) * 360, 0.9, 1);
        if (this._mode !== 'palette' || cols.length < 2)
            return cols[0];
        const pos = (t % 1) * cols.length;
        const i = Math.floor(pos);
        const f = pos - i;
        const e = f * f * (3 - 2 * f); // smoothstep: linger on each colour a little
        const a = cols[i];
        const b = cols[(i + 1) % cols.length];
        return a.map((v, k) => Math.round(v + (b[k] - v) * e));
    }

    _paint() {
        const t = (GLib.get_monotonic_time() - this._start) / 1e6 / this._period;
        const [r, g, b] = this._colorAt(t);
        if (!this._lastRgb || this._lastRgb[0] !== r || this._lastRgb[1] !== g || this._lastRgb[2] !== b) {
            this._tint.set_tint(new Cogl.Color({red: r, green: g, blue: b, alpha: 255}));
            this._lastRgb = [r, g, b];
        }
        // pulse: the whole border breathes between 35% and 100%
        this._border.opacity = this._mode === 'pulse'
            ? Math.round(255 * (0.35 + 0.65 * (0.5 - 0.5 * Math.cos(2 * Math.PI * t))))
            : 255;
    }

    _startTimer() {
        if (this._timerId)
            return;
        this._timerId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, Math.round(1000 / this._fps), () => {
            this._paint();
            return GLib.SOURCE_CONTINUE;
        });
        GLib.Source.set_name_by_id(this._timerId, '[night-city-glow] colour cycle');
    }

    _stopTimer() {
        if (this._timerId) {
            GLib.source_remove(this._timerId);
            this._timerId = 0;
        }
    }
}
