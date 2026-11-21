/* Rhythm — calm daily routine tracker. Plain JS, no build step. */
(function () {
  'use strict';

  // ---------- storage ----------
  var KEY = 'rhythm.v1';
  var store = { activities: [], logs: {}, settings: { reactions: 'on', notify: true }, created: null };
  function load() {
    try {
      var raw = localStorage.getItem(KEY);
      if (raw) { var d = JSON.parse(raw); store = Object.assign(store, d); store.settings = Object.assign({ reactions: 'on', notify: true }, d.settings || {}); }
    } catch (e) { /* first run or storage unavailable */ }
  }
  function save() {
    try { localStorage.setItem(KEY, JSON.stringify(store)); } catch (e) {}
    scheduleNotifications();
  }

  // ---------- time helpers ----------
  var DAY_SHORT = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  var DAY_NAMES = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  var MONTHS = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  function pad(n) { return (n < 10 ? '0' : '') + n; }
  function dkey(d) { return d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate()); }
  function mon0(d) { return (d.getDay() + 6) % 7; }
  function toMin(hhmm) { var p = hhmm.split(':'); return (+p[0]) * 60 + (+p[1]); }
  function nowMin(d) { return d.getHours() * 60 + d.getMinutes() + d.getSeconds() / 60; }
  function fmt12(m) { m = Math.round(m) % 1440; var h = Math.floor(m / 60), mm = m % 60; var ap = h < 12 ? 'AM' : 'PM'; var hh = h % 12 || 12; return hh + ':' + pad(mm) + ' ' + ap; }
  function fmtParts(m) { var s = fmt12(m).split(' '); return { t: s[0], ap: s[1] }; }
  function fmtRange(a) { var s = fmtParts(toMin(a.start)), e = fmtParts(toMin(a.end)); return s.ap === e.ap ? s.t + ' – ' + e.t + ' ' + e.ap : s.t + ' ' + s.ap + ' – ' + e.t + ' ' + e.ap; }
  function dur(mins) { mins = Math.round(mins); if (mins < 60) return mins + ' min'; var h = Math.floor(mins / 60), m = mins % 60; return h + ' hr' + (m ? ' ' + m + ' min' : ''); }
  function addDays(d, n) { var x = new Date(d); x.setDate(x.getDate() + n); return x; }
  function startOfDay(d) { var x = new Date(d); x.setHours(0, 0, 0, 0); return x; }
  function esc(s) { return String(s).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); }
  function uid() { return Math.random().toString(36).slice(2, 9); }
  function hash(s) { var h = 0; for (var i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) | 0; return Math.abs(h); }
  function repeatLabel(days) {
    var s = days.slice().sort().join('');
    if (s === '0123456') return 'Daily';
    if (s === '01234') return 'Mon–Fri';
    if (s === '56') return 'Weekends';
    return days.slice().sort().map(function (i) { return DAY_NAMES[i].slice(0, 3); }).join(', ');
  }

  // ---------- icons ----------
  var ICONS = {
    sun: '<path d="M3 18h18M6 18a6 6 0 0 1 12 0M12 5v3M5.6 9.6 7 11M18.4 9.6 17 11"/>',
    water: '<path d="M12 3s6 6.5 6 11a6 6 0 0 1-12 0c0-4.5 6-11 6-11z"/>',
    yoga: '<circle cx="12" cy="5" r="2"/><path d="M12 8v5M6.5 10.5 12 13l5.5-2.5M5 19c2.2-2 4.6-3 7-3s4.8 1 7 3"/>',
    shirt: '<path d="M8 4 3 7l2 4 2-1v10h10V10l2 1 2-4-5-3c-.5 1.5-2 2.5-4 2.5S8.5 5.5 8 4z"/>',
    coffee: '<path d="M4 9h13v5a5 5 0 0 1-5 5H9a5 5 0 0 1-5-5zM17 11h1.5a2.5 2.5 0 0 1 0 5H17M8 3v3M12 3v3"/>',
    focus: '<circle cx="12" cy="12" r="8"/><circle cx="12" cy="12" r="3"/>',
    pause: '<circle cx="12" cy="12" r="8.5"/><path d="M10 9v6M14 9v6"/>',
    book: '<path d="M4 5.5A1.5 1.5 0 0 1 5.5 4H11v16H5.5A1.5 1.5 0 0 1 4 18.5zM20 5.5A1.5 1.5 0 0 0 18.5 4H13v16h5.5a1.5 1.5 0 0 0 1.5-1.5z"/>',
    bowl: '<path d="M3 11h18a9 9 0 0 1-18 0zM8 7c0-1 1-1.5 1-2.5M12 7c0-1 1-1.5 1-2.5M16 7c0-1 1-1.5 1-2.5"/>',
    bookmark: '<path d="M6 4h12v16l-6-4-6 4z"/>',
    moon: '<path d="M20 14.5A8 8 0 1 1 9.5 4a6.5 6.5 0 0 0 10.5 10.5z"/>',
    walk: '<circle cx="13" cy="4.5" r="1.8"/><path d="M10 21l2-6 3 3v3M8 12l3-4 3 2 3 1M12 15l-1-5"/>'
  };
  var ICON_KEYS = Object.keys(ICONS);
  function icon(k) { return '<svg viewBox="0 0 24 24" aria-hidden="true">' + (ICONS[k] || ICONS.focus) + '</svg>'; }
  var I = {
    plus: '<svg class="ic" viewBox="0 0 24 24"><path d="M12 5v14M5 12h14"/></svg>',
    gear: '<svg class="ic" viewBox="0 0 24 24"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z"/></svg>',
    check: '<svg viewBox="0 0 24 24"><path d="M5 12.5l4.5 4.5L19 7.5"/></svg>',
    minus: '<svg viewBox="0 0 24 24"><path d="M6 12h12"/></svg>',
    x: '<svg viewBox="0 0 24 24"><path d="M7 7l10 10M17 7 7 17"/></svg>',
    dotsH: '<svg class="dots" viewBox="0 0 24 24"><circle cx="5.5" cy="12" r="1.6"/><circle cx="12" cy="12" r="1.6"/><circle cx="18.5" cy="12" r="1.6"/></svg>',
    dotsV: '<svg class="dots" viewBox="0 0 24 24"><circle cx="12" cy="5.5" r="1.6"/><circle cx="12" cy="12" r="1.6"/><circle cx="12" cy="18.5" r="1.6"/></svg>',
    clock: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3 2"/></svg>',
    half: '<svg viewBox="0 0 20 20"><circle cx="10" cy="10" r="8" fill="none" stroke="currentColor" stroke-width="2.5"/><path d="M10 4a6 6 0 0 0 0 12z" fill="currentColor"/></svg>',
    partialNode: '<svg width="20" height="20" viewBox="0 0 20 20" style="position:relative"><circle cx="10" cy="10" r="9" fill="#fff" stroke="#DFA247" stroke-width="2"/><path d="M10 3a7 7 0 0 0 0 14z" fill="#DFA247"/></svg>',
    up: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M12 19V5M6 11l6-6 6 6"/></svg>',
    down: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M12 5v14M6 13l6 6 6-6"/></svg>'
  };

  // ---------- buddy faces ----------
  var MOOD = {
    now: { fill: '#EDF3FF', stroke: '#3D6BE0', anim: 'a-bob' },
    done: { fill: '#EAF6EF', stroke: '#34A36F', anim: 'a-jump' },
    partial: { fill: '#FCF3E3', stroke: '#DFA247', anim: 'a-tilt' },
    skipped: { fill: '#F1F4F8', stroke: '#98A2B3', anim: 'a-sway' },
    missed: { fill: '#FBEDEE', stroke: '#D9646A', anim: 'a-droop' }
  };
  function face(mood, size, opts) {
    opts = opts || {};
    if (store.settings.reactions === 'off') return '';
    var m = MOOD[mood], small = size <= 36, sw = small ? 3.2 : 2.3, talk = opts.talk ? ' class="a-talk"' : '';
    var f = '<circle cx="28" cy="28" r="25" fill="' + m.fill + '" stroke="' + m.stroke + '" stroke-width="' + (small ? 2.4 : 1.5) + '"/>';
    var line = function (d) { return '<path d="' + d + '" fill="none" stroke="#172033" stroke-width="' + sw + '" stroke-linecap="round"/>'; };
    var eyes = function (cy, ry, l, r) { return '<g class="a-eyes"><ellipse cx="21" cy="' + (l || cy) + '" rx="' + (small ? 3.2 : 2.6) + '" ry="' + ry + '" fill="#172033"/><ellipse cx="35" cy="' + (r || cy) + '" rx="' + (small ? 3.2 : 2.6) + '" ry="' + ry + '" fill="#172033"/></g>'; };
    if (mood === 'now') f += '<g class="a-look">' + eyes(25, small ? 4 : 3.4) + '</g><path' + talk + ' d="M22 35 Q28 40 34 35" fill="none" stroke="#172033" stroke-width="' + sw + '" stroke-linecap="round"/>';
    if (mood === 'done') f += line('M16.5 26 Q20.5 20.5 24.5 26') + line('M31.5 26 Q35.5 20.5 39.5 26') + '<circle cx="14.5" cy="32.5" r="3" fill="#F4B4B8" opacity=".8"/><circle cx="41.5" cy="32.5" r="3" fill="#F4B4B8" opacity=".8"/><g' + talk + '><path d="M19 32 Q28 45 37 32 Z" fill="#172033"/>' + (small ? '' : '<path d="M23.5 38 Q28 35.5 32.5 38 Q28 41.5 23.5 38 Z" fill="#E8838A"/>') + '</g>';
    if (mood === 'partial') f += line('M32 18.5 Q35.5 16.5 39 18.5') + eyes(25, small ? 3.8 : 3.3, 25.5, 24.5) + '<path' + talk + ' d="M21 35 Q28 38.5 35 33" fill="none" stroke="#172033" stroke-width="' + sw + '" stroke-linecap="round"/>';
    if (mood === 'skipped') f += line('M17.5 26.5 Q21 28.8 24.5 26.5') + line('M31.5 26.5 Q35 28.8 38.5 26.5') + '<path' + talk + ' d="M23 36 Q28 37.5 33 36" fill="none" stroke="#172033" stroke-width="' + sw + '" stroke-linecap="round"/>' + (small ? '' : '<text x="42" y="14" font-size="9" font-weight="700" fill="#98A2B3" font-family="sans-serif">z</text>');
    if (mood === 'missed') f += line('M16.5 23 L23.5 20') + line('M39.5 23 L32.5 20') + eyes(27, small ? 3.6 : 3) + '<path' + talk + ' d="M21.5 38.5 Q28 33 34.5 38.5" fill="none" stroke="#172033" stroke-width="' + sw + '" stroke-linecap="round"/><path class="a-tear" d="M37 30.5 Q39.2 33.9 37 35.5 Q34.8 33.9 37 30.5 Z" fill="#7FA3EE"/>';
    var anim = opts.still ? '' : (mood === 'done' && small ? '' : m.anim);
    var sparks = '';
    if (mood === 'done' && opts.sparkle) {
      var st = function (pos, w, c, delay) { return '<svg class="spark" style="' + pos + ';animation-delay:' + delay + 's" width="' + w + '" height="' + w + '" viewBox="0 0 12 12" aria-hidden="true"><path d="M6 0 7.4 4.6 12 6 7.4 7.4 6 12 4.6 7.4 0 6 4.6 4.6Z" fill="' + c + '"/></svg>'; };
      sparks = st('top:-6px;left:-6px', 12, '#DFA247', 0) + st('top:-2px;right:-8px', 10, '#34A36F', .45) + st('bottom:2px;right:-10px', 8, '#3D6BE0', .9);
    }
    return '<span class="buddy' + (small ? ' face-mini' : '') + '" style="width:' + size + 'px;height:' + size + 'px" aria-hidden="true"><span class="body ' + anim + '"><svg width="' + size + '" height="' + size + '" viewBox="0 0 56 56">' + f + '</svg></span>' + sparks + '</span>';
  }
  var LINES = {
    now: ['{m} min in. Keep breathing — you’ve got this.', 'Nice and steady. {r} to go.', 'You’re in it. Just this, for now.', 'Settled in? {r} left — no rush.'],
    done: ['{n} done! Lovely work.', 'That’s one for the books. Nicely done.', '{n} — complete. You’re on a roll.', 'Done and dusted. Proud of you.'],
    partial: ['Some {n} beats none. Proud of you.', 'Showing up counts. Well done.', 'A bit is still progress.'],
    skipped: ['Rest is part of the plan too.', 'No worries — tomorrow’s a fresh start.', 'Skipped is fine. Onwards.'],
    free: ['Free time. Breathe — {next} starts in {in}.', 'A little gap. {next} is up in {in}.'],
    wrapGood: ['That’s a wrap! {d} of {t} done today.', 'What a day — {d} of {t} done.'],
    wrapMeh: ['Day’s done. {d} of {t} — tomorrow’s a fresh page.', 'Every day counts. {d} of {t} today.']
  };
  function pickLine(kind, seed, vars) {
    var arr = LINES[kind], s = arr[hash(seed) % arr.length];
    return s.replace(/\{(\w+)\}/g, function (_, k) { return vars[k] != null ? vars[k] : ''; });
  }
  function buddyRow(mood, size, text, extra) {
    var r = store.settings.reactions;
    if (r === 'off') return '';
    var f = face(mood, size, Object.assign({ talk: r === 'on' }, extra || {}));
    return '<div class="buddy-row">' + f + (r === 'on' ? '<div class="bubble" role="status">' + esc(text) + '</div>' : '') + '</div>';
  }

  // ---------- domain ----------
  function scheduledOn(a, d) {
    if (a.days.indexOf(mon0(d)) < 0) return false;
    if (a.createdAt && dkey(d) < a.createdAt) return false;
    return true;
  }
  function logOf(d, id) { var l = store.logs[dkey(d)]; return l ? l[id] : null; }
  function setLog(d, id, entry) {
    var k = dkey(d); store.logs[k] = store.logs[k] || {};
    if (entry) store.logs[k][id] = entry; else delete store.logs[k][id];
    save();
  }
  function todayItems(now) {
    var nm = nowMin(now);
    return store.activities.filter(function (a) { return scheduledOn(a, now); })
      .sort(function (a, b) { return toMin(a.start) - toMin(b.start); })
      .map(function (a) {
        var s = toMin(a.start), e = toMin(a.end), log = logOf(now, a.id), st;
        if (log) st = log.status;
        else if (a.createdAt === dkey(now) && a.createdMin != null && e <= a.createdMin) st = 'na';
        else if (nm >= s && nm < e) st = 'now';
        else if (state.early === a.id && nm < s) st = 'now';
        else if (nm < s) st = 'upcoming';
        else st = 'missed';
        return { a: a, s: s, e: e, st: st, log: log, inWindow: nm >= s && nm < e };
      });
  }

  // ---------- app state ----------
  var state = { tab: 'today', range: 'week', early: null, snooze: {}, sheet: null, editor: null, lastToday: '' };

  // ---------- rendering ----------
  var $screen = document.getElementById('screen');
  var $layer = document.getElementById('layer');

  function render(animate) {
    var html = state.tab === 'today' ? renderToday() : state.tab === 'routine' ? renderRoutine() : renderInsights();
    var scroll = $screen.scrollTop;
    var prev = {};
    if (!animate) $screen.querySelectorAll('[data-k]').forEach(function (n) { prev[n.dataset.k] = 1; });
    $screen.innerHTML = html;
    $screen.querySelectorAll('[data-k]').forEach(function (n) { if (prev[n.dataset.k]) n.classList.add('settled'); });
    if (animate) { $screen.classList.remove('fade'); void $screen.offsetWidth; $screen.classList.add('fade'); $screen.scrollTop = 0; }
    else $screen.scrollTop = scroll;
    document.querySelectorAll('.tab').forEach(function (t) { if (t.dataset.tab === state.tab) t.setAttribute('aria-current', 'page'); else t.removeAttribute('aria-current'); });
  }

  function greeting(d) { var h = d.getHours(); return h < 5 ? 'Good night' : h < 12 ? 'Good morning' : h < 17 ? 'Good afternoon' : 'Good evening'; }

  function header(title, sub, eyebrow, actions) {
    return '<header class="hdr"><div style="display:flex;flex-direction:column;gap:2px">' + (eyebrow ? '<div class="eyebrow">' + eyebrow + '</div>' : '') +
      '<h1>' + title + '</h1>' + (sub ? '<div class="eyebrow">' + sub + '</div>' : '') + '</div><div class="hdr-actions">' + (actions || '') + '</div></header>';
  }

  function renderToday() {
    var now = new Date();
    var dateStr = DAY_NAMES[mon0(now)] + ', ' + now.getDate() + ' ' + MONTHS[now.getMonth()];
    var actions = '<button type="button" class="icon-btn" data-action="settings" aria-label="Settings">' + I.gear + '</button><button type="button" class="icon-btn" data-action="add" aria-label="Add activity">' + I.plus + '</button>';
    var head = header('Today', dateStr, greeting(now), actions);
    if (!store.activities.length) {
      return head + '<div class="empty">' +
        '<div style="position:relative;width:88px;height:88px;display:flex;align-items:center;justify-content:center"><div style="position:absolute;inset:0;border-radius:50%;border:1px dashed var(--border-strong)"></div><div class="tile active" style="width:56px;height:56px;border-radius:16px">' + icon('sun') + '</div></div>' +
        '<div style="display:flex;flex-direction:column;gap:8px;align-items:center"><h2>Your day is empty.</h2><p>Add your first activity and we’ll help you stay on track.</p></div>' +
        '<button type="button" class="btn btn-primary" data-action="add">' + I.plus.replace('class="ic"', '') + 'Add activity</button>' +
        '<div style="display:flex;flex-direction:column;gap:8px;align-items:center;padding-top:8px"><span class="meta">Or start from a template</span><div class="chips"><button type="button" class="pill" data-action="template" data-t="morning">Morning routine</button><button type="button" class="pill" data-action="template" data-t="workday">Workday</button></div></div></div>';
    }
    var items = todayItems(now);
    var nm = nowMin(now);
    var resolvedCount = items.filter(function (i) { return i.st === 'done' || i.st === 'partial' || i.st === 'skipped'; }).length;
    var focus = items.filter(function (i) { return i.inWindow; })[0] || items.filter(function (i) { return i.st === 'now'; })[0];
    var next = items.filter(function (i) { return i.s > nm && i !== focus; })[0];
    var card;

    if (!items.length) {
      card = '<div class="card">' + buddyRow('skipped', 52, 'Nothing planned for ' + DAY_NAMES[mon0(now)] + '. Enjoy the day.') +
        '<div><div class="act-title">A free day</div><div class="act-sub">No activities repeat on ' + DAY_NAMES[mon0(now)] + 's.</div></div>' +
        '<button type="button" class="btn btn-secondary" data-action="tab" data-tab="routine">View routine</button></div>';
    } else if (focus && focus.st === 'now') {
      var a = focus.a, total = focus.e - focus.s, elapsed = Math.max(0, nm - focus.s), left = Math.max(0, focus.e - nm);
      var pct = focus.inWindow ? Math.min(100, elapsed / total * 100) : 0;
      var msg = focus.inWindow ? pickLine('now', a.id + dkey(now), { m: Math.max(1, Math.floor(elapsed)), r: dur(Math.ceil(left)), n: a.name }) : 'Starting early? Love that. Tap complete when you’re done.';
      card = '<div class="card" data-k="now-' + a.id + '">' + buddyRow('now', 52, msg) +
        '<div class="act-head"><div class="tile active">' + icon(a.icon) + '</div><div style="flex:1;min-width:0"><div class="act-title">' + esc(a.name) + '</div><div class="act-sub num">' + fmtRange(a) + '</div></div></div>' +
        (focus.inWindow ? '<div><div class="bar"><i style="width:' + pct.toFixed(1) + '%"></i></div><div class="bar-meta num"><span><b>' + dur(Math.ceil(left)) + '</b> remaining</span><span>Ends ' + fmtParts(focus.e).t + '</span></div></div>'
          : '<div class="bar-meta num" style="margin:0"><span>Scheduled ' + fmtRange(a) + '</span></div>') +
        '<div class="btn-row"><button type="button" class="btn btn-primary grow" data-action="complete" data-id="' + a.id + '">' + I.check + 'Mark complete</button>' +
        '<button type="button" class="btn btn-secondary" data-action="checkin" data-id="' + a.id + '">' + I.dotsH + 'More</button></div></div>';
    } else if (focus) {
      var st = focus.st, chipTxt = { done: 'Completed', partial: 'Partially done', skipped: 'Skipped' }[st] || 'Missed';
      var line = pickLine(st === 'missed' ? 'skipped' : st, focus.a.id + dkey(now) + st, { n: focus.a.name });
      card = '<div class="card" data-k="res-' + focus.a.id + st + '">' + buddyRow(st === 'missed' ? 'missed' : st, 56, line, { sparkle: st === 'done' }) +
        '<div style="display:flex;align-items:center;justify-content:space-between;gap:8px"><div style="min-width:0"><div class="act-title">' + esc(focus.a.name) + '</div><div class="act-sub">' + (focus.log && focus.log.at ? 'Logged at ' + fmt12(focus.log.at) : fmtRange(focus.a)) + '</div></div>' +
        '<span class="chip ' + st + '">' + chipIcon(st) + chipTxt + '</span></div>' +
        (next ? '<div class="divider"></div>' + upNextRow(next, nm, false) : '') +
        '<div class="btn-row" style="justify-content:flex-end;margin:-8px -8px -8px 0"><button type="button" class="btn btn-text" data-action="undo" data-id="' + focus.a.id + '">Undo</button></div></div>';
    } else if (next) {
      var inMin = next.s - nm;
      card = '<div class="card" data-k="free">' + buddyRow('now', 52, pickLine('free', dkey(now) + next.a.id, { next: next.a.name, 'in': dur(Math.ceil(inMin)) }), { still: false }) +
        '<div style="display:flex;flex-direction:column;gap:10px"><span class="chip free" style="align-self:flex-start">' + I.clock + 'Free time</span>' +
        '<div><div class="act-title">Nothing scheduled right now</div><div class="act-sub" style="font-size:15px;line-height:22px">Your next activity starts in ' + dur(Math.ceil(inMin)) + '.</div></div></div>' +
        '<div class="divider"></div>' + upNextRow(next, nm, true) + '</div>';
    } else {
      var doneN = items.filter(function (i) { return i.st === 'done' || i.st === 'partial'; }).length;
      var good = doneN / items.length >= .6;
      card = '<div class="card" data-k="wrap">' + buddyRow(good ? 'done' : 'partial', 56, pickLine(good ? 'wrapGood' : 'wrapMeh', dkey(now), { d: doneN, t: items.length }), { sparkle: good }) +
        '<div><div class="act-title">That’s today</div><div class="act-sub">Rest well. Tomorrow starts with ' + esc(firstTomorrow(now)) + '.</div></div>' +
        '<button type="button" class="btn btn-secondary" data-action="tab" data-tab="insights">See this week</button></div>';
    }

    var counts = { done: 0, partial: 0, missed: 0, skipped: 0 };
    items.forEach(function (i) { if (counts[i.st] != null) counts[i.st]++; });
    var chips = '';
    if (counts.done || counts.partial || counts.missed) {
      chips = '<div class="chips">' + (counts.done ? '<span class="chip done">' + chipIcon('done') + counts.done + ' completed</span>' : '') +
        (counts.partial ? '<span class="chip partial">' + chipIcon('partial') + counts.partial + ' partial</span>' : '') +
        (counts.missed ? '<span class="chip missed">' + chipIcon('missed') + counts.missed + ' to check in</span>' : '') + '</div>';
    }
    var tl = items.map(function (i, idx) { return tlRow(i, idx, items.length, nm); }).join('');
    return head +
      '<section class="section" aria-label="Current activity"><div class="sec-label">Now' + (focus && focus.st === 'now' ? '' : ' · ' + fmt12(nm)) + '</div>' + card + '</section>' +
      (items.length ? '<section class="section" aria-label="Today’s timeline" style="gap:8px"><div class="sec-row"><div class="sec-label">Today</div><div class="meta num">' + resolvedCount + ' of ' + items.length + ' done</div></div>' + chips + '<ol class="tl">' + tl + '</ol></section>' : '');
  }

  function firstTomorrow(now) {
    var t = addDays(now, 1);
    var f = store.activities.filter(function (a) { return scheduledOn(a, t); }).sort(function (a, b) { return toMin(a.start) - toMin(b.start); })[0];
    return f ? f.name + ' at ' + fmt12(toMin(f.start)) : 'a free day';
  }
  function upNextRow(next, nm, startEarly) {
    return '<div style="display:flex;align-items:center;gap:12px"><div class="tile sm">' + icon(next.a.icon) + '</div>' +
      '<div style="flex:1;min-width:0;display:flex;flex-direction:column"><span class="meta">Up next · in ' + dur(Math.ceil(next.s - nm)) + '</span>' +
      '<span style="font-size:16px;line-height:22px;font-weight:500;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">' + esc(next.a.name) + ' <span class="num" style="color:var(--text-2);font-weight:400;font-size:14px">· ' + fmt12(next.s) + '</span></span></div>' +
      (startEarly ? '<button type="button" class="btn btn-secondary" style="height:44px;font-size:14px;padding:0 14px" data-action="early" data-id="' + next.a.id + '">Start early</button>' : '') + '</div>';
  }
  function chipIcon(st) {
    if (st === 'done') return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12.5l4.5 4.5L19 7.5"/></svg>';
    if (st === 'partial') return I.half;
    if (st === 'skipped') return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round"><path d="M6 12h12"/></svg>';
    if (st === 'missed') return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round"><path d="M7 7l10 10M17 7 7 17"/></svg>';
    return '<span class="chip-dot"></span>';
  }
  function tlRow(i, idx, n, nm) {
    var st = i.st, node, text, cls = '';
    if (st === 'done') { node = '<span class="node done">' + I.check + '</span>'; text = '<span class="tl-status st-done">Completed</span>'; }
    else if (st === 'partial') { node = '<span class="node partial">' + I.partialNode + '</span>'; text = '<span class="tl-status st-partial">Partially done' + (i.log && i.log.amount ? ' · ' + i.log.amount + '%' : '') + '</span>'; }
    else if (st === 'skipped') { node = '<span class="node skipped">' + I.minus + '</span>'; text = '<span class="tl-status">Skipped</span>'; }
    else if (st === 'missed') { node = '<span class="node missed">' + I.x + '</span>'; text = '<span class="tl-status st-missed">Missed · no check-in</span>'; }
    else if (st === 'now') { node = '<span class="node now"></span>'; text = '<span class="tl-status st-now">Now' + (i.inWindow ? ' · ' + dur(Math.ceil(i.e - nm)) + ' left' : ' · started early') + '</span>'; cls = ' now'; }
    else if (st === 'na') { node = '<span class="node upcoming"></span>'; text = '<span class="tl-status">Added after this window</span>'; }
    else { node = '<span class="node upcoming"></span>'; text = '<span class="tl-status">' + (idx > 0 ? 'Upcoming' : 'Up first') + ' · ' + dur(i.e - i.s) + '</span>'; }
    var muted = st === 'done' || st === 'partial' || st === 'skipped' || st === 'na';
    var p = fmtParts(i.s);
    var trailing = '';
    if (st === 'done') trailing = face('done', 28, { still: true });
    else if (st === 'partial') trailing = face('partial', 28);
    else if (st === 'skipped') trailing = face('skipped', 28, { still: true });
    else if (st === 'missed') trailing = face('missed', 28) + '<span class="update-link">Update</span>';
    var action = (st === 'upcoming' || st === 'na') ? 'data-action="edit" data-id="' + i.a.id + '"' : 'data-action="checkin" data-id="' + i.a.id + '"';
    var label = esc(i.a.name) + ', ' + fmt12(i.s) + ', ' + st;
    return '<li data-k="row-' + i.a.id + st + '"><button type="button" class="tl-row' + cls + (idx === 0 ? ' first' : '') + (idx === n - 1 ? ' last' : '') + '" ' + action + ' aria-label="' + label + '">' +
      '<span class="tl-time">' + p.t + '<small>' + p.ap + '</small></span><span class="tl-node"><span class="tl-line"></span>' + node + '</span>' +
      '<span class="tl-body"><span class="tl-name' + (muted ? ' muted' : '') + '">' + esc(i.a.name) + '</span>' + text + '</span>' + trailing + '</button></li>';
  }

  function renderRoutine() {
    var acts = store.activities.slice().sort(function (a, b) { return toMin(a.start) - toMin(b.start); });
    var actions = '<button type="button" class="icon-btn" data-action="add" aria-label="Add activity">' + I.plus + '</button>';
    var head = header('Routine', acts.length ? acts.length + ' ' + (acts.length === 1 ? 'activity' : 'activities') + ' · repeats automatically' : 'Build the shape of your day', '', actions);
    if (!acts.length) return head + '<div class="empty"><div class="tile active" style="width:56px;height:56px;border-radius:16px">' + icon('focus') + '</div><div style="display:flex;flex-direction:column;gap:8px;align-items:center"><h2>No routines yet</h2><p>Activities you add here repeat on the days you choose.</p></div><button type="button" class="btn btn-primary" data-action="add">Add activity</button></div>';
    var groups = [['Morning', 0, 720], ['Afternoon', 720, 1020], ['Evening', 1020, 1440]];
    return head + groups.map(function (g) {
      var list = acts.filter(function (a) { var s = toMin(a.start); return s >= g[1] && s < g[2]; });
      if (!list.length) return '';
      return '<section class="section" style="gap:8px"><div class="sec-row" style="padding:0 4px"><h2 class="sec-label">' + g[0] + '</h2><span class="meta">' + list.length + (list.length === 1 ? ' activity' : ' activities') + '</span></div><ul class="group">' +
        list.map(function (a) {
          return '<li class="r-row"><span class="r-time">' + fmt12(toMin(a.start)) + '</span><button type="button" class="r-main" data-action="edit" data-id="' + a.id + '"><span class="tile">' + icon(a.icon) + '</span><span style="min-width:0"><span class="r-name">' + esc(a.name) + '</span><span class="r-sub">' + repeatLabel(a.days) + ' · ' + dur(toMin(a.end) - toMin(a.start)) + '</span></span></button>' +
            '<button type="button" class="ghost-icon" data-action="rowmenu" data-id="' + a.id + '" aria-label="Options for ' + esc(a.name) + '">' + I.dotsV + '</button></li>';
        }).join('') + '</ul></section>';
    }).join('');
  }

  function stats(from, to, now) {
    // inclusive from, exclusive to (dates). Only counts windows that have ended or been logged.
    var per = {}, tot = { sched: 0, done: 0, partial: 0 };
    for (var d = startOfDay(from); d < to; d = addDays(d, 1)) {
      if (d > now) break;
      var isToday = dkey(d) === dkey(now), nm = nowMin(now);
      store.activities.forEach(function (a) {
        if (!scheduledOn(a, d)) return;
        var log = logOf(d, a.id);
        if (!log && isToday && nm < toMin(a.end)) return; // not over yet
        if (!log && a.createdAt === dkey(d) && a.createdMin != null && toMin(a.end) <= a.createdMin) return; // added after the window
        var p = per[a.id] = per[a.id] || { a: a, sched: 0, done: 0, partial: 0 };
        p.sched++; tot.sched++;
        if (log && log.status === 'done') { p.done++; tot.done++; }
        if (log && log.status === 'partial') { p.partial++; tot.partial++; }
      });
    }
    var rows = Object.keys(per).map(function (k) { var p = per[k]; p.pct = p.sched ? Math.round((p.done + p.partial * .5) / p.sched * 100) : 0; return p; });
    tot.pct = tot.sched ? Math.round((tot.done + tot.partial * .5) / tot.sched * 100) : null;
    return { rows: rows, tot: tot };
  }

  function renderInsights() {
    var now = new Date(), from, to, prevFrom, label;
    if (state.range === 'week') {
      from = addDays(startOfDay(now), -mon0(now)); to = addDays(from, 7); prevFrom = addDays(from, -7);
      var end = addDays(to, -1);
      label = from.getDate() + ' ' + MONTHS[from.getMonth()].slice(0, 3) + ' – ' + end.getDate() + ' ' + MONTHS[end.getMonth()].slice(0, 3);
    } else {
      from = new Date(now.getFullYear(), now.getMonth(), 1); to = new Date(now.getFullYear(), now.getMonth() + 1, 1); prevFrom = new Date(now.getFullYear(), now.getMonth() - 1, 1);
      label = MONTHS[now.getMonth()] + ' ' + now.getFullYear();
    }
    var cur = stats(from, to, now), prev = stats(prevFrom, from, now);
    var seg = '<div class="seg" role="group" aria-label="Range"><button type="button" data-action="range" data-r="week" aria-pressed="' + (state.range === 'week') + '">Week</button><button type="button" data-action="range" data-r="month" aria-pressed="' + (state.range === 'month') + '">Month</button></div>';
    var head = header('Insights', label, '', seg);
    if (cur.tot.pct == null) {
      return head + '<div class="empty">' + (face('now', 64) || '<div class="tile active" style="width:56px;height:56px;border-radius:16px">' + icon('focus') + '</div>') + '<div style="display:flex;flex-direction:column;gap:8px;align-items:center"><h2>Nothing to show yet</h2><p>Insights appear once your first activity window has passed.</p></div></div>';
    }
    var delta = prev.tot.pct != null ? cur.tot.pct - prev.tot.pct : null;
    var deltaChip = delta == null ? '' : '<span class="chip ' + (delta >= 0 ? 'done' : 'skipped') + '" style="margin-bottom:4px">' + '<span style="width:12px;height:12px;display:inline-flex">' + (delta >= 0 ? I.up : I.down) + '</span>' + Math.abs(delta) + '% vs last ' + state.range + '</span>';
    var rows = cur.rows.slice().sort(function (a, b) { return b.pct - a.pct || toMin(a.a.start) - toMin(b.a.start); });
    var best = rows[0], worst = rows.slice().sort(function (a, b) { return a.pct - b.pct; })[0];
    var units = state.range === 'week' ? 'this week' : 'this month';
    return head +
      '<section class="section"><h2 class="sec-label">This ' + state.range + '</h2><div style="display:flex;align-items:flex-end;justify-content:space-between;gap:12px"><div style="display:flex;flex-direction:column;gap:2px"><span class="stat">' + cur.tot.pct + '%</span><span class="act-sub">Overall completion · ' + (cur.tot.done + cur.tot.partial) + ' of ' + cur.tot.sched + '</span></div>' + deltaChip + '</div>' +
      '<div class="bar b8"><i style="width:' + cur.tot.pct + '%"></i></div></section>' +
      '<section class="section"><h2 class="sec-label">By activity</h2><ul class="group">' + rows.map(function (p) {
        return '<li class="i-row"><div class="i-top"><span class="i-name">' + esc(p.a.name) + '</span><span class="i-val">' + (p.done + p.partial) + ' / ' + p.sched + ' <b>' + p.pct + '%</b></span></div><div class="bar b6"><i' + (p.pct < 50 ? ' class="muted"' : '') + ' style="width:' + p.pct + '%"></i></div></li>';
      }).join('') + '</ul></section>' +
      (rows.length > 1 ? '<section class="grid2" aria-label="Highlights">' +
        '<div class="card-sm"><div style="display:flex;justify-content:space-between;align-items:flex-start"><span class="mini-ic" style="background:var(--success-soft);color:var(--success-ink)">' + I.check + '</span>' + face('done', 32, { still: true }) + '</div><div style="display:flex;flex-direction:column;gap:2px"><span class="meta">Most consistent</span><span style="font-size:17px;line-height:24px;font-weight:600">' + esc(best.a.name) + '</span><span class="meta num" style="color:var(--label)">' + best.pct + '% ' + units + '</span></div></div>' +
        '<div class="card-sm"><div style="display:flex;justify-content:space-between;align-items:flex-start"><span class="mini-ic" style="background:var(--subtle);color:var(--label)">' + I.clock + '</span>' + face(worst.pct < 50 ? 'missed' : 'partial', 32) + '</div><div style="display:flex;flex-direction:column;gap:2px"><span class="meta">Most missed</span><span style="font-size:17px;line-height:24px;font-weight:600">' + esc(worst.a.name) + '</span><span class="meta num" style="color:var(--label)">' + worst.pct + '%' + (worst.pct < 60 ? ' · try another time?' : ' · still solid') + '</span></div></div>' +
        '</section>' : '');
  }

  // ---------- sheets ----------
  function openLayer(html, kind) {
    $layer.innerHTML = (kind === 'full' ? '' : '<button type="button" class="scrim" data-action="close" aria-label="Close"></button>') + html;
    $layer.hidden = false; $layer.classList.remove('closing');
    document.getElementById('toast').classList.remove('show');
    state.sheet = kind || 'sheet';
    var f = $layer.querySelector('[autofocus]'); if (f) setTimeout(function () { f.focus(); }, 280);
  }
  function closeLayer(cb) {
    if ($layer.hidden) { if (cb) cb(); return; }
    $layer.classList.add('closing');
    setTimeout(function () { $layer.hidden = true; $layer.innerHTML = ''; $layer.classList.remove('closing'); state.sheet = null; state.editor = null; if (cb) cb(); }, 180);
  }
  function findAct(id) { return store.activities.filter(function (a) { return a.id === id; })[0]; }

  function checkinSheet(id, selected) {
    var a = findAct(id); if (!a) return;
    var now = new Date(), log = logOf(now, id), useFace = store.settings.reactions !== 'off';
    var sel = selected || null;
    var ic = function (mood, fallback, bg, col) { return useFace ? face(mood, 36, { still: mood !== 'partial' }) : '<span class="mini-ic" style="width:32px;height:32px;border-radius:50%;background:' + bg + ';color:' + col + '">' + fallback + '</span>'; };
    var head = useFace ? face(sel === 'partial' ? 'partial' : 'now', 52, { talk: store.settings.reactions === 'on' }) : '<div class="tile active">' + icon(a.icon) + '</div>';
    var amount = state.amount || 50;
    openLayer('<div class="sheet" role="dialog" aria-label="How did ' + esc(a.name) + ' go?"><div class="grabber"></div>' +
      '<div class="act-head">' + head + '<div style="min-width:0"><h2>How did ' + esc(a.name) + ' go?</h2><div class="act-sub num">' + (sel === 'partial' ? 'Some is better than none — how much?' : fmtRange(a) + ' · One tap saves it') + '</div></div></div>' +
      '<div class="opt-list" role="radiogroup" aria-label="Outcome">' +
      '<button type="button" class="opt" data-action="log" data-id="' + id + '" data-st="done">' + ic('done', I.check, 'var(--success-soft)', 'var(--success-ink)') + '<span><span class="opt-t">Completed</span><span class="opt-d">Finished as planned</span></span></button>' +
      '<button type="button" class="opt' + (sel === 'partial' ? ' sel' : '') + '" data-action="partial" data-id="' + id + '" aria-pressed="' + (sel === 'partial') + '">' + ic('partial', I.half, 'var(--warning-soft)', 'var(--warning-ink)') + '<span><span class="opt-t">Partially completed</span><span class="opt-d">Did some of it — that counts</span></span></button>' +
      '<button type="button" class="opt" data-action="log" data-id="' + id + '" data-st="skipped">' + ic('skipped', I.minus, 'var(--subtle)', 'var(--label)') + '<span><span class="opt-t">Skipped</span><span class="opt-d">Not today</span></span></button></div>' +
      (sel === 'partial' ? '<div class="field"><span class="flabel">How much did you do? <span style="color:var(--text-2);font-weight:400">Optional</span></span><div class="amt">' + [25, 50, 75].map(function (v) { return '<button type="button" data-action="amount" data-v="' + v + '" aria-pressed="' + (amount === v) + '">' + v + '%</button>'; }).join('') + '</div>' +
        '<input class="input" id="note" type="text" aria-label="Note" placeholder="Add a note" style="height:48px;background:#F9FAFC" value="' + esc((log && log.note) || '') + '"></div>' +
        '<div class="btn-row"><button type="button" class="btn btn-text muted" data-action="close">Cancel</button><button type="button" class="btn btn-primary grow" data-action="log" data-id="' + id + '" data-st="partial">Save as partial</button></div>'
        : '<div class="btn-row" style="justify-content:space-between">' + (log ? '<button type="button" class="btn btn-text danger" data-action="undo" data-id="' + id + '">Clear check-in</button>' : '<span></span>') + '<button type="button" class="btn btn-text muted" data-action="close">Cancel</button></div>') +
      '</div>');
  }

  function missedSheet(id) {
    var a = findAct(id); if (!a) return;
    var useFace = store.settings.reactions !== 'off';
    openLayer('<div class="sheet" role="dialog" aria-labelledby="mq"><div class="grabber"></div><div class="center" style="padding-top:4px">' +
      (useFace ? face('missed', 72, { talk: store.settings.reactions === 'on' }) : '<div class="tile" style="width:56px;height:56px;border-radius:16px">' + icon(a.icon) + '</div>') +
      '<div style="display:flex;flex-direction:column;gap:6px"><h2 id="mq" style="font-size:22px;line-height:28px">Did you complete ' + esc(a.name) + '?</h2><p class="act-sub" style="font-size:15px;line-height:22px">The ' + fmtRange(a) + ' window ended.<br>A quick answer keeps your week accurate.</p></div></div>' +
      '<div style="display:flex;flex-direction:column;gap:8px"><button type="button" class="btn btn-primary btn-lg" data-action="log" data-id="' + id + '" data-st="done">' + I.check + 'Yes, done</button>' +
      '<div class="grid2" style="gap:8px"><button type="button" class="btn btn-secondary btn-lg" data-action="partial" data-id="' + id + '"><span style="width:16px;height:16px;display:inline-flex;color:var(--warning-ink)">' + I.half + '</span>Partially</button>' +
      '<button type="button" class="btn btn-secondary btn-lg" data-action="log" data-id="' + id + '" data-st="skipped">No</button></div></div>' +
      '<button type="button" class="btn btn-text muted" style="align-self:center" data-action="later" data-id="' + id + '">Ask me later</button></div>');
  }

  function rowMenu(id) {
    var a = findAct(id); if (!a) return;
    openLayer('<div class="sheet" role="dialog" aria-label="' + esc(a.name) + ' options"><div class="grabber"></div><div><h2>' + esc(a.name) + '</h2><div class="act-sub">' + fmtRange(a) + ' · ' + repeatLabel(a.days) + '</div></div><div>' +
      '<button type="button" class="menu-btn" data-action="edit" data-id="' + id + '">Edit</button>' +
      '<button type="button" class="menu-btn" data-action="duplicate" data-id="' + id + '">Duplicate</button>' +
      '<button type="button" class="menu-btn danger" data-action="delete" data-id="' + id + '">Delete</button></div>' +
      '<button type="button" class="btn btn-text muted" data-action="close">Cancel</button></div>');
  }

  function settingsSheet() {
    var s = store.settings;
    openLayer('<div class="sheet" role="dialog" aria-label="Settings"><div class="grabber"></div><h2>Settings</h2>' +
      '<div class="field"><span class="flabel">Reactions</span><div class="seg seg3" role="group" aria-label="Reactions">' +
      [['on', 'On'], ['quiet', 'Quiet'], ['off', 'Off']].map(function (o) { return '<button type="button" data-action="reactions" data-v="' + o[0] + '" aria-pressed="' + (s.reactions === o[0]) + '">' + o[1] + '</button>'; }).join('') +
      '</div><span class="hint">On: animated face that talks. Quiet: face only. Off: classic icons.</span></div>' +
      '<div class="group"><div class="sw-row"><span><span class="sw-t">Reminders</span><span class="hint">Start, 10 min before end, and check-ins</span></span><button type="button" class="switch" role="switch" data-action="notify" aria-checked="' + !!s.notify + '" aria-label="Reminders"><span></span></button></div></div>' +
      '<div class="group"><button type="button" class="menu-btn" style="padding:0 16px" data-action="demo">Load sample routine</button><button type="button" class="menu-btn danger" style="padding:0 16px" data-action="reset">Erase all data</button></div>' +
      '<button type="button" class="btn btn-text muted" data-action="close">Done</button></div>');
  }

  // ---------- editor ----------
  function openEditor(id) {
    var a = id ? findAct(id) : null;
    var base = a ? JSON.parse(JSON.stringify(a)) : { id: null, name: '', icon: 'walk', start: suggestStart(), end: '', days: [0, 1, 2, 3, 4, 5, 6], remindStart: true, remindEnd: true, askMissed: true };
    if (!base.end) base.end = minToHHMM(toMin(base.start) + 30);
    state.editor = { draft: base, errors: {}, isNew: !a };
    renderEditor(true);
  }
  function suggestStart() {
    var acts = store.activities.slice().sort(function (a, b) { return toMin(a.end) - toMin(b.end); });
    var last = acts[acts.length - 1];
    var m = last ? toMin(last.end) : Math.ceil(nowMin(new Date()) / 30) * 30;
    return minToHHMM(Math.min(m, 1410));
  }
  function minToHHMM(m) { m = Math.max(0, Math.min(1439, Math.round(m))); return pad(Math.floor(m / 60)) + ':' + pad(m % 60); }
  function repeatMode(days) { var s = days.slice().sort().join(''); return s === '0123456' ? 'daily' : s === '01234' ? 'weekdays' : 'custom'; }
  function renderEditor(first) {
    var e = state.editor, d = e.draft;
    var len = toMin(d.end) - toMin(d.start);
    var hint = len > 0 ? dur(len) + neighbourHint(d) : '';
    var mode = repeatMode(d.days);
    var sw = function (key, title, sub) { return '<div class="sw-row"><span><span class="sw-t">' + title + '</span>' + (sub ? '<span class="hint">' + sub + '</span>' : '') + '</span><button type="button" class="switch" role="switch" data-action="toggle" data-k="' + key + '" aria-checked="' + !!d[key] + '" aria-label="' + title + '"><span></span></button></div>'; };
    var html = '<div class="full" role="dialog" aria-label="' + (e.isNew ? 'New activity' : 'Edit activity') + '"' + (first ? '' : ' style="animation:none"') + '>' +
      '<div class="full-top"><button type="button" class="btn btn-text" style="justify-self:start;font-weight:400;font-size:16px" data-action="close">Cancel</button><h1>' + (e.isNew ? 'New activity' : 'Edit activity') + '</h1><span></span></div>' +
      '<div class="full-body">' +
      '<div class="field"><label for="f-name">Activity name</label><input id="f-name" class="input' + (e.errors.name ? ' err' : '') + '" data-field="name" type="text" maxlength="40" placeholder="e.g. Evening walk" value="' + esc(d.name) + '"' + (e.isNew && first ? ' autofocus' : '') + ' autocomplete="off">' + (e.errors.name ? '<span class="err-msg">Give it a short name</span>' : '') + '</div>' +
      '<fieldset style="border:0;margin:0;padding:0" class="field"><legend class="flabel" style="padding:0;margin-bottom:8px">Icon</legend><div class="icons">' + ICON_KEYS.map(function (k) { return '<button type="button" data-action="icon" data-k="' + k + '" aria-label="' + k + '" aria-pressed="' + (d.icon === k) + '">' + icon(k) + '</button>'; }).join('') + '</div></fieldset>' +
      '<div class="field"><div class="grid2"><div class="field"><label for="f-start">Start time</label><input id="f-start" class="input num" data-field="start" type="time" value="' + d.start + '"></div><div class="field"><label for="f-end">End time</label><input id="f-end" class="input num' + (e.errors.time ? ' err' : '') + '" data-field="end" type="time" value="' + d.end + '"></div></div>' +
      (e.errors.time ? '<span class="err-msg">End time needs to be after ' + fmt12(toMin(d.start)) + '</span>' : '<span class="hint" id="dur-hint">' + hint + '</span>') + '</div>' +
      '<fieldset style="border:0;margin:0;padding:0;gap:12px" class="field"><legend class="flabel" style="padding:0;margin-bottom:8px">Repeat</legend><div class="seg seg3">' +
      [['daily', 'Daily'], ['weekdays', 'Weekdays'], ['custom', 'Custom']].map(function (o) { return '<button type="button" data-action="repeat" data-v="' + o[0] + '" aria-pressed="' + (mode === o[0]) + '">' + o[1] + '</button>'; }).join('') + '</div>' +
      '<div class="days">' + DAY_SHORT.map(function (l, i) { return '<button type="button" data-action="day" data-i="' + i + '" aria-label="' + DAY_NAMES[i] + '" aria-pressed="' + (d.days.indexOf(i) >= 0) + '">' + l + '</button>'; }).join('') + '</div>' + (e.errors.days ? '<span class="err-msg">Pick at least one day</span>' : '') + '</fieldset>' +
      '<fieldset style="border:0;margin:0;padding:0" class="field"><legend class="flabel" style="padding:0;margin-bottom:8px">Reminders</legend><div class="group">' + sw('remindStart', 'Notify at start') + sw('remindEnd', 'Notify before end', '10 min before') + sw('askMissed', 'Ask if missed', 'A quick check-in when it ends') + '</div></fieldset>' +
      (e.isNew ? '' : '<div class="center" style="gap:4px"><button type="button" class="btn btn-text danger" data-action="delete" data-id="' + d.id + '">Delete activity</button><span class="hint">Past history is kept either way.</span></div>') +
      '</div><div class="full-foot"><button type="button" class="btn btn-primary btn-lg" style="width:100%" data-action="saveAct">' + (e.isNew ? 'Create activity' : 'Save changes') + '</button></div></div>';
    if (first) openLayer(html, 'full'); else { var sc = $layer.querySelector('.full-body').scrollTop; $layer.innerHTML = html; $layer.querySelector('.full-body').scrollTop = sc; }
  }
  function neighbourHint(d) {
    var s = toMin(d.start), e = toMin(d.end);
    var clash = store.activities.filter(function (a) { return a.id !== d.id && a.days.some(function (x) { return d.days.indexOf(x) >= 0; }) && toMin(a.start) < e && toMin(a.end) > s; })[0];
    if (clash) return ' · overlaps ' + clash.name;
    var after = store.activities.filter(function (a) { return a.id !== d.id && toMin(a.start) >= e; }).sort(function (a, b) { return toMin(a.start) - toMin(b.start); })[0];
    return after ? ' · ' + after.name + ' follows at ' + fmt12(toMin(after.start)) : '';
  }
  function saveEditor() {
    var e = state.editor, d = e.draft; e.errors = {};
    d.name = d.name.trim();
    if (!d.name) e.errors.name = 1;
    if (!(toMin(d.end) > toMin(d.start))) e.errors.time = 1;
    if (!d.days.length) e.errors.days = 1;
    if (Object.keys(e.errors).length) { renderEditor(false); return; }
    if (e.isNew) { d.id = uid(); d.createdAt = dkey(new Date()); d.createdMin = Math.round(nowMin(new Date())); store.activities.push(d); }
    else store.activities = store.activities.map(function (a) { return a.id === d.id ? d : a; });
    save();
    var name = d.name, isNew = e.isNew;
    closeLayer(function () { render(); toast(isNew ? name + ' added' : 'Changes saved'); });
  }

  // ---------- templates ----------
  var TEMPLATES = {
    morning: [['Wake up', 'sun', '05:45', '05:50'], ['Drink water', 'water', '05:50', '06:00'], ['Yoga', 'yoga', '06:00', '07:00'], ['Get ready', 'shirt', '07:00', '07:30'], ['Breakfast', 'coffee', '07:30', '08:00']],
    workday: [['Deep work', 'focus', '08:00', '10:00', [0, 1, 2, 3, 4]], ['Break', 'pause', '10:00', '10:15', [0, 1, 2, 3, 4]], ['Study', 'book', '10:15', '12:00', [0, 1, 2, 3, 4]], ['Lunch', 'bowl', '13:00', '13:45'], ['Reading', 'bookmark', '15:00', '15:45'], ['Meditation', 'moon', '21:00', '21:15']]
  };
  function addTemplate(key) {
    var today = dkey(new Date());
    TEMPLATES[key].forEach(function (t) {
      if (store.activities.some(function (a) { return a.name === t[0] && a.start === t[2]; })) return;
      store.activities.push({ id: uid(), name: t[0], icon: t[1], start: t[2], end: t[3], days: t[4] || [0, 1, 2, 3, 4, 5, 6], remindStart: true, remindEnd: true, askMissed: true, createdAt: today, createdMin: Math.round(nowMin(new Date())) });
    });
    save();
  }
  function loadDemo() {
    store.activities = []; store.logs = {};
    addTemplate('morning'); addTemplate('workday');
    // backdate creation and fill a realistic past week so Insights has data
    var start = dkey(addDays(new Date(), -13));
    store.activities.forEach(function (a) { a.createdAt = start; delete a.createdMin; });
    var rates = { 'Yoga': .86, 'Deep work': .86, 'Reading': .71, 'Meditation': .43 };
    for (var i = 13; i >= 1; i--) {
      var d = addDays(new Date(), -i), k = dkey(d);
      store.logs[k] = {};
      store.activities.forEach(function (a, j) {
        if (!scheduledOn(a, d)) return;
        var r = rates[a.name] || .8, x = (hash(k + a.name) % 100) / 100;
        if (x < r) store.logs[k][a.id] = { status: x < r - .08 ? 'done' : 'partial', amount: 50, at: toMin(a.end) - 5 };
        else if (x < r + .08) store.logs[k][a.id] = { status: 'skipped', at: toMin(a.end) };
      });
    }
    save();
  }

  // ---------- actions ----------
  function logStatus(id, st) {
    var now = new Date(), a = findAct(id);
    var entry = { status: st, at: Math.round(nowMin(now)) };
    if (st === 'partial') { entry.amount = state.amount || 50; var n = document.getElementById('note'); if (n && n.value.trim()) entry.note = n.value.trim().slice(0, 120); }
    setLog(now, id, entry);
    if (state.early === id) state.early = null;
    delete state.snooze[id];
    state.amount = null;
    if (st === 'done' && navigator.vibrate) { try { navigator.vibrate(12); } catch (e) {} }
    closeLayer(function () {
      render();
      var words = { done: 'Nice — ' + a.name + ' complete', partial: a.name + ' saved as partial', skipped: a.name + ' skipped' };
      toast(words[st], function () { setLog(new Date(), id, null); render(); });
    });
  }

  var toastTimer;
  function toast(msg, undo) {
    var t = document.getElementById('toast');
    t.innerHTML = '<span>' + esc(msg) + '</span>' + (undo ? '<button type="button" data-action="toastUndo">Undo</button>' : '');
    t._undo = undo || null;
    t.classList.add('show');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(function () { t.classList.remove('show'); t._undo = null; }, 3200);
  }

  document.addEventListener('click', function (ev) {
    var el = ev.target.closest('[data-action]'); if (!el) return;
    var act = el.dataset.action, id = el.dataset.id;
    switch (act) {
      case 'tab': closeLayer(); if (state.tab !== el.dataset.tab) { state.tab = el.dataset.tab; render(true); } break;
      case 'add': closeLayer(function () { openEditor(null); }); break;
      case 'edit': closeLayer(function () { openEditor(id); }); break;
      case 'close': closeLayer(); break;
      case 'complete': logStatus(id, 'done'); break;
      case 'checkin': {
        var nowD = new Date(), it = todayItems(nowD).filter(function (i) { return i.a.id === id; })[0];
        if (it && it.st === 'missed' && !it.log) missedSheet(id); else checkinSheet(id);
        break;
      }
      case 'partial': state.amount = state.amount || 50; checkinSheet(id, 'partial'); break;
      case 'amount': state.amount = +el.dataset.v; $layer.querySelectorAll('.amt button').forEach(function (b) { b.setAttribute('aria-pressed', String(b === el)); }); break;
      case 'log': logStatus(id, el.dataset.st); break;
      case 'undo': setLog(new Date(), id, null); closeLayer(function () { render(); toast('Check-in cleared'); }); break;
      case 'later': state.snooze[id] = Date.now() + 15 * 60000; closeLayer(); break;
      case 'early': state.early = id; render(); toast('Started early — enjoy'); break;
      case 'template': addTemplate(el.dataset.t); render(true); toast('Template added'); break;
      case 'range': state.range = el.dataset.r; render(); break;
      case 'rowmenu': rowMenu(id); break;
      case 'duplicate': {
        var src = findAct(id), copy = JSON.parse(JSON.stringify(src)); copy.id = uid(); copy.name = src.name + ' (copy)'; copy.createdAt = dkey(new Date()); copy.createdMin = Math.round(nowMin(new Date()));
        store.activities.push(copy); save(); closeLayer(function () { render(); toast('Duplicated'); }); break;
      }
      case 'delete': {
        var victim = findAct(id); if (!victim) break;
        store.activities = store.activities.filter(function (a) { return a.id !== id; }); save();
        closeLayer(function () { render(); toast(victim.name + ' deleted', function () { store.activities.push(victim); save(); render(); }); });
        break;
      }
      case 'settings': settingsSheet(); break;
      case 'reactions': store.settings.reactions = el.dataset.v; save(); settingsSheet(); render(); break;
      case 'notify': store.settings.notify = !store.settings.notify; save(); if (store.settings.notify) requestNotifyPermission(); el.setAttribute('aria-checked', String(store.settings.notify)); break;
      case 'demo': loadDemo(); closeLayer(function () { state.tab = 'today'; render(true); toast('Sample routine loaded'); }); break;
      case 'reset': store.activities = []; store.logs = {}; save(); closeLayer(function () { state.tab = 'today'; render(true); toast('All data erased'); }); break;
      case 'toastUndo': { var t = document.getElementById('toast'); if (t._undo) t._undo(); t.classList.remove('show'); break; }
      // editor
      case 'icon': state.editor.draft.icon = el.dataset.k; renderEditor(false); break;
      case 'repeat': { var v = el.dataset.v; state.editor.draft.days = v === 'daily' ? [0, 1, 2, 3, 4, 5, 6] : v === 'weekdays' ? [0, 1, 2, 3, 4] : state.editor.draft.days.length === 7 ? [0, 2, 4] : state.editor.draft.days; renderEditor(false); break; }
      case 'day': { var i = +el.dataset.i, ds = state.editor.draft.days, p = ds.indexOf(i); if (p >= 0) ds.splice(p, 1); else ds.push(i); renderEditor(false); break; }
      case 'toggle': { var k = el.dataset.k; state.editor.draft[k] = !state.editor.draft[k]; el.setAttribute('aria-checked', String(state.editor.draft[k])); break; }
      case 'saveAct': saveEditor(); break;
    }
  });
  document.addEventListener('input', function (ev) {
    var f = ev.target.dataset && ev.target.dataset.field; if (!f || !state.editor) return;
    state.editor.draft[f] = ev.target.value;
    if (f === 'start' || f === 'end') {
      var d = state.editor.draft, len = toMin(d.end || '00:00') - toMin(d.start || '00:00'), h = document.getElementById('dur-hint');
      if (h) h.textContent = len > 0 ? dur(len) + neighbourHint(d) : 'End time needs to be after the start';
    }
  });
  document.addEventListener('change', function (ev) {
    var f = ev.target.dataset && ev.target.dataset.field;
    if (f === 'start' && state.editor) { var d = state.editor.draft; if (toMin(d.end) <= toMin(d.start)) { d.end = minToHHMM(toMin(d.start) + 30); renderEditor(false); } }
  });
  document.addEventListener('keydown', function (ev) { if (ev.key === 'Escape' && state.sheet) closeLayer(); });

  // ---------- missed prompts ----------
  function maybePromptMissed() {
    if (state.sheet || state.tab !== 'today') return;
    var now = new Date(), nm = nowMin(now);
    var cand = todayItems(now).filter(function (i) {
      return i.st === 'missed' && i.a.askMissed && nm - i.e < 180 && !(state.snooze[i.a.id] > Date.now());
    }).sort(function (x, y) { return y.e - x.e; })[0];
    if (cand) missedSheet(cand.a.id);
  }

  // ---------- notifications ----------
  var Cap = window.Capacitor, isNative = !!(Cap && Cap.isNativePlatform && Cap.isNativePlatform());
  var LN = isNative && window.capacitorLocalNotifications ? window.capacitorLocalNotifications.LocalNotifications : null;
  var AppPlugin = isNative && window.capacitorApp ? window.capacitorApp.App : null;
  var notifyReady = false, schedTimer = null;
  function requestNotifyPermission() {
    if (LN) { LN.requestPermissions().then(function () { scheduleNotifications(); }); }
    else if ('Notification' in window && Notification.permission === 'default') { try { Notification.requestPermission(); } catch (e) {} }
  }
  function scheduleNotifications() {
    if (!LN || !notifyReady) return;
    clearTimeout(schedTimer);
    schedTimer = setTimeout(function () {
      LN.getPending().then(function (p) {
        var cancel = p && p.notifications && p.notifications.length ? LN.cancel({ notifications: p.notifications.map(function (n) { return { id: n.id }; }) }) : Promise.resolve();
        return cancel;
      }).then(function () {
        if (!store.settings.notify) return;
        var list = [], now = new Date(), nid = 1;
        for (var day = 0; day < 3; day++) {
          var d = addDays(startOfDay(now), day);
          store.activities.forEach(function (a) {
            if (!scheduledOn(a, d) || logOf(d, a.id)) return;
            var s = new Date(d.getTime() + toMin(a.start) * 60000), e = new Date(d.getTime() + toMin(a.end) * 60000), pre = new Date(e.getTime() - 10 * 60000);
            var extra = { actId: a.id, date: dkey(d) };
            if (a.remindStart && s > now) list.push({ id: nid++, title: a.name + ' starts now', body: fmtRange(a), schedule: { at: s, allowWhileIdle: true }, actionTypeId: 'START', extra: extra });
            if (a.remindEnd && pre > now && pre > s) list.push({ id: nid++, title: a.name + ' ends in 10 minutes', body: 'Wrap up whenever you’re ready.', schedule: { at: pre, allowWhileIdle: true }, actionTypeId: 'NEAR_END', extra: extra });
            if (a.askMissed && e > now) list.push({ id: nid++, title: 'Did you finish ' + a.name + '?', body: 'One tap keeps your week accurate.', schedule: { at: e, allowWhileIdle: true }, actionTypeId: 'CHECKIN', extra: extra });
          });
        }
        if (list.length) return LN.schedule({ notifications: list.slice(0, 60) });
      }).catch(function () {});
    }, 300);
  }
  function setupNative() {
    if (!LN) return;
    LN.registerActionTypes({ types: [
      { id: 'START', actions: [{ id: 'start', title: 'Start' }, { id: 'skip', title: 'Skip' }] },
      { id: 'NEAR_END', actions: [{ id: 'done', title: 'Complete' }] },
      { id: 'CHECKIN', actions: [{ id: 'done', title: 'Yes' }, { id: 'partial', title: 'Partially' }, { id: 'skip', title: 'No' }] }
    ] }).catch(function () {});
    LN.addListener('localNotificationActionPerformed', function (r) {
      var ex = (r.notification && r.notification.extra) || {}, a = findAct(ex.actId); if (!a) return;
      var d = ex.date ? new Date(ex.date + 'T12:00:00') : new Date();
      var map = { done: 'done', partial: 'partial', skip: 'skipped' };
      if (map[r.actionId]) setLog(d, a.id, { status: map[r.actionId], at: Math.round(nowMin(new Date())), amount: r.actionId === 'partial' ? 50 : undefined });
      else if (r.actionId === 'tap' && dkey(d) === dkey(new Date())) { state.tab = 'today'; render(true); setTimeout(function () { checkinSheet(a.id); }, 300); return; }
      state.tab = 'today'; render(true);
    });
    notifyReady = true;
    LN.checkPermissions().then(function (p) { if (p.display !== 'granted' && store.settings.notify) LN.requestPermissions().then(scheduleNotifications); else scheduleNotifications(); }).catch(function () {});
    var App = AppPlugin;
    if (App) App.addListener('backButton', function () {
      if (state.sheet) closeLayer(); else if (state.tab !== 'today') { state.tab = 'today'; render(true); } else App.exitApp();
    });
    if (App) App.addListener('appStateChange', function (s) { if (s.isActive) { render(); maybePromptMissed(); } });
  }
  // in-browser fallback: fire simple notifications while the page is open
  var fired = {};
  function webNotifyTick() {
    if (LN || !store.settings.notify || !('Notification' in window) || Notification.permission !== 'granted') return;
    var now = new Date(), nm = nowMin(now), k = dkey(now);
    todayItems(now).forEach(function (i) {
      var a = i.a, pre = i.e - 10;
      var fire = function (tag, title, body) { if (fired[k + tag]) return; fired[k + tag] = 1; try { new Notification(title, { body: body, tag: k + tag }); } catch (e) {} };
      if (a.remindStart && nm >= i.s && nm < i.s + 1.5) fire(a.id + 's', a.name + ' starts now', fmtRange(a));
      if (a.remindEnd && !i.log && nm >= pre && nm < pre + 1.5) fire(a.id + 'p', a.name + ' ends in 10 minutes', 'Wrap up whenever you’re ready.');
      if (a.askMissed && !i.log && nm >= i.e && nm < i.e + 1.5) fire(a.id + 'e', 'Did you finish ' + a.name + '?', 'Open Rhythm to check in.');
    });
  }

  // ---------- boot ----------
  load();
  render(true);
  setupNative();
  setTimeout(maybePromptMissed, 900);
  setInterval(function () {
    if (!state.sheet || state.sheet === 'sheet') { if (!state.sheet) render(); }
    maybePromptMissed(); webNotifyTick();
  }, 30000);
  document.addEventListener('visibilitychange', function () { if (!document.hidden) { if (!state.sheet) render(); maybePromptMissed(); } });
  window.RhythmDebug = { store: function () { return store; }, render: render, loadDemo: loadDemo };
})();
