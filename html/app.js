'use strict';

/* ==========================================================================
   Vanguard Business — panel
   Pages: home (jobs + admin), boss, cook, register, bill. Overlays: progress, placement, toasts.
   Opened in a normal browser it runs a preview with sample data (#home, #boss, #cook, #register, #bill).
   ========================================================================== */

const IS_GAME = typeof GetParentResourceName === 'function';
const RESOURCE = IS_GAME ? GetParentResourceName() : 'vanguard-business';

const state = { page: null, payload: null, bossTab: 'overview', cart: {}, billTimer: null };

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function el(tag, props = {}, ...children) {
    const node = document.createElement(tag);
    for (const [key, value] of Object.entries(props)) {
        if (value === null || value === undefined || value === false) continue;
        if (key === 'class') node.className = value;
        else if (key === 'text') node.textContent = value;
        else if (key.startsWith('on')) node.addEventListener(key.slice(2), value);
        else node.setAttribute(key, value === true ? '' : value);
    }
    node.append(...children.flat().filter((child) => child !== null && child !== undefined && child !== false));
    return node;
}

const money = (value) => {
    const amount = Number(value || 0);
    return `${amount < 0 ? '-' : ''}$${Math.abs(amount).toLocaleString('en-US')}`;
};
const imageUrl = (file) => `../images/${file}`;

function itemImage(file, label) {
    return el('img', { class: 'item-img', src: imageUrl(file), alt: label, onerror: (event) => { event.target.style.visibility = 'hidden'; } });
}

async function post(endpoint, data = {}) {
    if (!IS_GAME) return Preview.respond(endpoint, data);
    try {
        const response = await fetch(`https://${RESOURCE}/${endpoint}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data),
        });
        return await response.json();
    } catch {
        return { ok: false, message: 'The game did not answer' };
    }
}

const request = (action, data) => post('request', { action, data });

function toast(message, ok = true) {
    if (!message) return;
    const node = el('div', { class: `toast${ok ? '' : ' is-error'}`, role: 'status', text: message });
    document.getElementById('toasts').append(node);
    setTimeout(() => node.classList.add('is-leaving'), 3600);
    setTimeout(() => node.remove(), 4000);
}

/** Runs a server action from a button: disables it, shows the answer, then calls after(result) on success. */
async function act(button, action, data, after) {
    if (button) button.disabled = true;
    const result = await request(action, data);
    if (button) button.disabled = false;
    toast(result.message, result.ok);
    if (result.ok && after) await after(result);
    return result;
}

function numberInput(placeholder, attrs = {}) {
    return el('input', { class: 'input', type: 'number', min: 1, step: 1, inputmode: 'numeric', placeholder, ...attrs });
}

function button(label, onclick, variant = '') {
    return el('button', { class: `btn ${variant}`.trim(), type: 'button', onclick, text: label });
}

function section(title, ...children) {
    return el('section', { class: 'block' }, el('h2', { class: 'block-title', text: title }), ...children);
}

function stat(label, value, variant = '') {
    return el('div', { class: `stat ${variant}`.trim() }, el('small', { text: label }), el('strong', { text: value }));
}

function empty(text) {
    return el('p', { class: 'empty', text });
}

// ---------------------------------------------------------------------------
// Frame
// ---------------------------------------------------------------------------

function applyBrand(brand) {
    if (!brand) return;
    document.getElementById('brand-title').textContent = brand.Title;
    document.getElementById('brand-subtitle').textContent = brand.Subtitle;
    document.getElementById('brand-mark').textContent = (brand.Title || 'V').charAt(0);
    const rgb = /^#([0-9a-f]{6})$/i.exec(brand.Accent || '');
    if (!rgb) return;
    const value = parseInt(rgb[1], 16);
    const [r, g, b] = [value >> 16, (value >> 8) & 255, value & 255];
    const root = document.documentElement.style;
    root.setProperty('--accent', brand.Accent);
    root.setProperty('--accent-soft', `rgba(${r}, ${g}, ${b}, 0.14)`);
    root.setProperty('--accent-line', `rgba(${r}, ${g}, ${b}, 0.5)`);
}

function setTitle(kicker, title) {
    document.getElementById('page-kicker').textContent = kicker;
    document.getElementById('page-title').textContent = title;
}

function open(page, payload) {
    state.page = page;
    state.payload = payload;
    if (page === 'boss') state.cart = {};
    document.getElementById('app').hidden = false;
    document.getElementById('app').dataset.page = page;
    render();
}

function render() {
    clearInterval(state.billTimer);
    const renderer = PAGES[state.page];
    if (!renderer) return;
    document.getElementById('page').replaceChildren(renderer(state.payload));
}

function hide() {
    clearInterval(state.billTimer);
    state.page = null;
    document.getElementById('app').hidden = true;
}

function close() {
    const wasBill = state.page === 'bill' && state.payload;
    hide();
    if (wasBill) request('billAnswer', { billId: wasBill.id, method: 'decline' });
    post('close');
}

// ---------------------------------------------------------------------------
// Home: your jobs, and the admin panel for server admins
// ---------------------------------------------------------------------------

async function refreshHome() {
    const result = await request('home');
    if (result.ok) {
        state.payload = result.data;
        render();
    }
}

function renderHome(p) {
    setTitle(p.admin ? 'ADMIN' : 'STAFF', p.admin ? 'Businesses' : 'Your jobs');
    return el('div', { class: 'stack' },
        section('Your jobs',
            p.jobs.length
                ? el('ul', { class: 'rows' }, p.jobs.map((job) => el('li', { class: 'row' },
                    el('strong', { class: 'row-name', text: job.name }),
                    el('span', { class: 'chip', text: job.rankLabel }),
                    p.duty === job.businessId ? el('span', { class: 'chip is-on', text: 'ON SHIFT' }) : null)))
                : empty('You are not hired anywhere yet. Ask a business owner to hire you.')),
        p.admin ? renderAdmin(p) : null);
}

function renderAdmin(p) {
    const name = el('input', { class: 'input', maxlength: 40, placeholder: 'Business name, e.g. Cat Café' });
    const type = el('select', { class: 'input' }, p.types.map((t) => el('option', { value: t.id, text: t.label })));
    const create = button('Create', () => act(create, 'adminCreate', { name: name.value, type: type.value }, refreshHome), 'is-primary');

    return el('div', { class: 'stack' },
        section('New business', el('div', { class: 'form-row' }, name, type, create),
            el('p', { class: 'hint', text: 'Then press Place, walk inside the building and click where each station goes.' })),
        section(`All businesses (${p.businesses.length})`,
            p.businesses.length ? el('div', { class: 'cards' }, p.businesses.map(renderAdminCard)) : empty('No businesses yet.')));
}

function renderAdminCard(b) {
    const ownerId = numberInput('Server ID', { class: 'input small' });
    const rename = el('input', { class: 'input', maxlength: 40, value: b.name });
    let armed = false;
    const remove = button('Delete', () => {
        if (!armed) {
            armed = true;
            remove.textContent = 'Click again to delete';
            remove.classList.add('is-armed');
            return;
        }
        act(remove, 'adminDelete', { id: b.id }, refreshHome);
    }, 'is-danger');

    return el('article', { class: 'card' },
        el('header', { class: 'card-head' },
            el('div', {}, el('strong', { text: b.name }), el('small', { text: `${b.typeLabel} · #${b.id}` })),
            el('span', { class: 'money', text: money(b.balance) })),
        el('div', { class: 'stats' },
            stat('Owner', b.owner || 'None'),
            stat('Staff', `${b.staff} (${b.onDuty} on shift)`),
            stat('Placed', `${b.stations} stations · ${b.doors} doors`),
            stat('Map icon', b.hasBlip ? 'Yes' : 'No')),
        el('div', { class: 'actions' },
            button('Place stations', () => post('placeStart', { businessId: b.id }), 'is-primary'),
            b.teleport ? button('Teleport', () => post('teleport', b.teleport)) : null),
        el('div', { class: 'form-row' }, ownerId,
            button('Set owner', (event) => act(event.currentTarget, 'adminSetOwner', { id: b.id, target: Number(ownerId.value) }, refreshHome))),
        el('div', { class: 'form-row' }, rename,
            button('Rename', (event) => act(event.currentTarget, 'adminRename', { id: b.id, name: rename.value }, refreshHome)),
            remove));
}

// ---------------------------------------------------------------------------
// Boss desk
// ---------------------------------------------------------------------------

async function refreshBoss() {
    const result = await request('bossData', { stationId: state.payload.stationId });
    if (result.ok) {
        state.payload = result.data;
        render();
    }
}

function renderBoss(p) {
    setTitle(p.business.typeLabel.toUpperCase(), p.business.name);
    const tabs = [['overview', 'Overview'], ['staff', `Staff (${p.staff.length})`]];
    if (p.catalog) tabs.push(['supplier', 'Supplier']);
    if (!tabs.some(([id]) => id === state.bossTab)) state.bossTab = 'overview';

    const body = { overview: renderBossOverview, staff: renderBossStaff, supplier: renderBossSupplier }[state.bossTab](p);
    return el('div', { class: 'stack' },
        el('nav', { class: 'tabs' }, tabs.map(([id, label]) => el('button', {
            class: `tab${state.bossTab === id ? ' is-active' : ''}`, type: 'button', text: label,
            onclick: () => { state.bossTab = id; render(); },
        })),
        p.canPlace ? button('Place stations', () => post('placeStart', { businessId: p.business.id }), 'tab-extra') : null),
        body);
}

function renderBossOverview(p) {
    const amount = numberInput('Amount', { max: p.maxTransaction });
    const deposit = button('Deposit cash', () => act(deposit, 'deposit', { stationId: p.stationId, amount: Number(amount.value) }, refreshBoss), 'is-primary');
    const withdraw = p.permissions.withdraw
        ? button('Withdraw', () => act(withdraw, 'withdraw', { stationId: p.stationId, amount: Number(amount.value) }, refreshBoss))
        : null;

    return el('div', { class: 'stack' },
        el('div', { class: 'stats big' },
            p.business.balance !== undefined && p.business.balance !== null ? stat('Balance', money(p.business.balance), 'is-accent') : null,
            stat('On shift', String(p.onDuty)),
            stat('Your rank', p.ranks[p.rank - 1])),
        section('Business money', el('div', { class: 'form-row' }, amount, deposit, withdraw)),
        p.log ? section('Money log', p.log.length ? renderLog(p.log) : empty('Nothing yet.')) : null);
}

function renderLog(log) {
    return el('div', { class: 'table-wrap' }, el('table', { class: 'table' },
        el('thead', {}, el('tr', {}, ['When', 'What', 'Who', 'Amount'].map((h) => el('th', { text: h })))),
        el('tbody', {}, log.map((entry) => el('tr', {},
            el('td', { text: new Date(entry.time * 1000).toLocaleString() }),
            el('td', { text: entry.note ? `${entry.kind} · ${entry.note}` : entry.kind }),
            el('td', { text: entry.actor }),
            el('td', { class: entry.amount < 0 ? 'neg' : entry.amount > 0 ? 'pos' : '', text: entry.amount ? money(entry.amount) : '—' }))))));
}

function assignableRanks(p) {
    return p.ranks.map((label, index) => ({ value: index + 1, label })).filter((r) => r.value < p.rank && r.value < p.ranks.length);
}

function renderBossStaff(p) {
    const canHire = p.permissions.hire;
    const ranks = assignableRanks(p);

    const rows = p.staff.map((member) => {
        const manageable = canHire && !member.isMe && member.rank < p.rank;
        const rankControl = manageable
            ? el('select', {
                class: 'input small',
                onchange: (event) => act(null, 'setRank', { stationId: p.stationId, identifier: member.identifier, rank: Number(event.target.value) }, refreshBoss),
            }, ranks.map((r) => el('option', { value: r.value, text: r.label, selected: r.value === member.rank })))
            : el('span', { class: 'chip', text: p.ranks[member.rank - 1] });
        const fire = manageable ? button('Let go', (event) => act(event.currentTarget, 'fire', { stationId: p.stationId, identifier: member.identifier }, refreshBoss), 'is-danger') : null;
        return el('li', { class: 'row' },
            el('span', { class: `dot${member.onDuty ? ' is-on' : member.online ? ' is-online' : ''}`, title: member.onDuty ? 'On shift' : member.online ? 'Online' : 'Offline' }),
            el('strong', { class: 'row-name', text: member.name }),
            member.isMe ? el('span', { class: 'chip is-you', text: 'YOU' }) : null,
            rankControl, fire);
    });

    return el('div', { class: 'stack' },
        section('Team', el('ul', { class: 'rows' }, rows)),
        canHire && ranks.length ? renderHireForm(p, ranks) : null);
}

function renderHireForm(p, ranks) {
    const target = numberInput('Server ID', { class: 'input small' });
    const nearby = el('select', { class: 'input', onchange: (event) => { target.value = event.target.value; } },
        el('option', { value: '', text: 'Nearby players…' }));
    const rank = el('select', { class: 'input small' }, ranks.map((r) => el('option', { value: r.value, text: r.label })));
    const hire = button('Hire', () => act(hire, 'hire', { stationId: p.stationId, target: Number(target.value), rank: Number(rank.value) }, refreshBoss), 'is-primary');
    const scan = button('Find nearby', async () => {
        const result = await act(scan, 'nearbyPlayers', { stationId: p.stationId });
        if (!result.ok) return;
        const players = result.data.players;
        nearby.replaceChildren(el('option', { value: '', text: players.length ? 'Nearby players…' : 'Nobody nearby' }),
            ...players.map((player) => el('option', { value: player.id, text: `[${player.id}] ${player.name}` })));
    });
    return section('Hire', el('div', { class: 'form-row' }, scan, nearby), el('div', { class: 'form-row' }, target, rank, hire));
}

function renderBossSupplier(p) {
    const totalLabel = el('strong', { class: 'money' });
    const orderButton = button('Order', () => {
        const cart = Object.entries(state.cart).filter(([, packs]) => packs > 0).map(([item, packs]) => ({ item, packs }));
        act(orderButton, 'order', { stationId: p.stationId, cart }, async () => { state.cart = {}; await refreshBoss(); });
    }, 'is-primary');

    const updateTotal = () => {
        const total = p.catalog.reduce((sum, entry) => sum + (state.cart[entry.item] || 0) * entry.price, 0);
        totalLabel.textContent = money(total);
        orderButton.disabled = total === 0;
    };

    const rows = p.catalog.map((entry) => {
        const count = el('span', { class: 'count', text: String(state.cart[entry.item] || 0) });
        const change = (delta) => {
            const next = Math.max(0, Math.min(p.maxPacks, (state.cart[entry.item] || 0) + delta));
            state.cart[entry.item] = next;
            count.textContent = String(next);
            updateTotal();
        };
        return el('li', { class: 'row supply' },
            itemImage(entry.image, entry.label),
            el('div', { class: 'row-name' }, el('strong', { text: entry.label }), el('small', { text: `${entry.pack} per pack · ${money(entry.price)}` })),
            el('div', { class: 'stepper' }, button('−', () => change(-1)), count, button('+', () => change(1))));
    });

    updateTotal();
    return el('div', { class: 'stack' },
        section('Order ingredients', el('ul', { class: 'rows' }, rows)),
        el('div', { class: 'checkout' },
            el('div', {}, el('small', { text: 'TOTAL, PAID FROM THE BUSINESS' }), totalLabel),
            el('p', { class: 'hint', text: 'Delivered straight into the fridge.' }), orderButton));
}

// ---------------------------------------------------------------------------
// Cooking
// ---------------------------------------------------------------------------

function renderCook(p) {
    setTitle(p.business.toUpperCase(), p.station);
    if (!p.recipes.length) return empty('Nothing to make here for this business type.');

    return el('div', { class: 'recipes' }, p.recipes.map((recipe) => {
        let quantity = 1;
        const qty = el('span', { class: 'count', text: '1' });
        const needs = el('ul', { class: 'needs' });
        const cook = button('Cook', () => post('cook', { recipe: recipe.id, quantity }), 'is-primary');

        const refresh = () => {
            qty.textContent = String(quantity);
            let ready = true;
            needs.replaceChildren(...Object.entries(recipe.ingredients).map(([item, per]) => {
                const need = per * quantity;
                const have = p.counts[item] || 0;
                if (have < need) ready = false;
                return el('li', { class: have >= need ? 'is-ok' : 'is-short' },
                    el('span', { text: p.labels[item] || item }), el('b', { text: `${have}/${need}` }));
            }));
            cook.disabled = !ready;
            cook.textContent = ready ? `Cook · ${Math.round((recipe.time * quantity) / 1000)}s` : 'Missing ingredients';
        };
        const change = (delta) => { quantity = Math.max(1, Math.min(p.maxQuantity, quantity + delta)); refresh(); };
        refresh();

        return el('article', { class: 'recipe' },
            el('div', { class: 'recipe-art' }, itemImage(recipe.image, recipe.label)),
            el('strong', { class: 'recipe-name', text: recipe.label }),
            needs,
            el('div', { class: 'recipe-foot' }, el('div', { class: 'stepper' }, button('−', () => change(-1)), qty, button('+', () => change(1))), cook));
    }));
}

// ---------------------------------------------------------------------------
// Register and bill
// ---------------------------------------------------------------------------

function renderRegister(p) {
    setTitle('CASH REGISTER', 'New bill');
    const customer = el('select', { class: 'input' },
        el('option', { value: '', text: p.players.length ? 'Pick a customer…' : 'No customer at the register' }),
        p.players.map((player) => el('option', { value: player.id, text: `[${player.id}] ${player.name}` })));
    const amount = numberInput(`Amount (max ${money(p.maxBill)})`, { max: p.maxBill });
    const note = el('input', { class: 'input', maxlength: 60, placeholder: 'What for? e.g. 2 lattes + cookie' });
    const send = button('Send bill', () => act(send, 'billCreate', { stationId: p.stationId, target: Number(customer.value), amount: Number(amount.value), note: note.value }), 'is-primary');
    return el('div', { class: 'stack narrow' },
        section('Customer', customer),
        section('Bill', amount, note),
        send,
        el('p', { class: 'hint', text: 'The customer gets a pop-up and pays with cash or bank. You get a commission on every paid bill.' }));
}

function renderBill(p) {
    setTitle('YOU HAVE A BILL', p.business);
    const countdown = el('span', { class: 'countdown', text: `${p.timeout}s` });
    let left = p.timeout;
    state.billTimer = setInterval(() => {
        left -= 1;
        countdown.textContent = `${Math.max(0, left)}s`;
        if (left <= 0) clearInterval(state.billTimer);
    }, 1000);

    const answer = (method) => async (event) => {
        const result = await act(event.currentTarget, 'billAnswer', { billId: p.id, method });
        if (result.ok || method === 'decline') { hide(); post('close'); }
    };

    return el('div', { class: 'receipt-wrap' },
        el('article', { class: 'receipt' },
            el('header', {}, el('strong', { text: p.business }), el('small', { text: `Served by ${p.from}` })),
            el('div', { class: 'receipt-line' }, el('span', { text: p.note || 'Order' }), el('span', { text: money(p.amount) })),
            el('div', { class: 'receipt-total' }, el('span', { text: 'TOTAL' }), el('strong', { text: money(p.amount) })),
            el('footer', {}, el('small', {}, 'Expires in ', countdown))),
        el('div', { class: 'actions center' },
            button('Pay cash', answer('cash'), 'is-primary'),
            button('Pay by bank', answer('bank'), 'is-primary'),
            button('Decline', answer('decline'), 'is-danger')));
}

const PAGES = { home: renderHome, boss: renderBoss, cook: renderCook, register: renderRegister, bill: renderBill };

// ---------------------------------------------------------------------------
// Overlays
// ---------------------------------------------------------------------------

function showProgress(label, duration) {
    const box = document.getElementById('progress');
    const fill = document.getElementById('progress-fill');
    document.getElementById('progress-label').textContent = label;
    fill.style.transition = 'none';
    fill.style.transform = 'scaleX(0)';
    box.hidden = false;
    void fill.offsetWidth;
    fill.style.transition = `transform ${duration}ms linear`;
    fill.style.transform = 'scaleX(1)';
}

function showPlacement(data) {
    document.getElementById('placement-business').textContent = data.business;
    document.getElementById('placement-kind').textContent = data.kind;
    document.getElementById('placement-count').textContent = `${data.index} / ${data.total}`;
    document.getElementById('placement-pair').hidden = !data.pairing;
    document.getElementById('placement').hidden = false;
}

// ---------------------------------------------------------------------------
// Messages from the game
// ---------------------------------------------------------------------------

window.addEventListener('message', ({ data }) => {
    if (!data || typeof data !== 'object') return;
    switch (data.action) {
        case 'open': applyBrand(data.brand); open(data.page, data.payload); break;
        case 'close': hide(); break;
        case 'toast': toast(data.message, data.ok); break;
        case 'progress': showProgress(data.label, data.duration); break;
        case 'progressEnd': document.getElementById('progress').hidden = true; break;
        case 'placement': showPlacement(data); break;
        case 'placementEnd': document.getElementById('placement').hidden = true; break;
        default: break;
    }
});

document.getElementById('close').addEventListener('click', close);
document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' && state.page) close();
});

// ---------------------------------------------------------------------------
// Browser preview (sample data; does nothing in-game)
// ---------------------------------------------------------------------------

const Preview = {
    home: {
        jobs: [{ businessId: 1, name: 'Cat Café', rank: 4, rankLabel: 'Owner' }, { businessId: 2, name: 'Burger Bar', rank: 2, rankLabel: 'Staff' }],
        duty: 1, admin: true,
        types: [{ id: 'bakery', label: 'Bakery' }, { id: 'bar', label: 'Bar' }, { id: 'burger', label: 'Burger bar' }, { id: 'catcafe', label: 'Cat café' }, { id: 'coffee', label: 'Coffee shop' }, { id: 'pizza', label: 'Pizzeria' }],
        businesses: [
            { id: 1, name: 'Cat Café', typeLabel: 'Cat café', balance: 18450, owner: 'Rover Op', staff: 5, onDuty: 2, stations: 7, doors: 2, hasBlip: true, teleport: { x: 0, y: 0, z: 0 } },
            { id: 2, name: 'Burger Bar', typeLabel: 'Burger bar', balance: 3200, owner: null, staff: 0, onDuty: 0, stations: 0, doors: 0, hasBlip: false },
        ],
    },
    boss: {
        stationId: 3, rank: 4,
        business: { id: 1, name: 'Cat Café', typeLabel: 'Cat café', balance: 18450 },
        permissions: { cook: true, fridge: true, doors: true, register: true, supplier: true, hire: true, log: true, withdraw: true },
        ranks: ['Trainee', 'Staff', 'Manager', 'Owner'], onDuty: 2, canPlace: true, maxPacks: 50, maxTransaction: 1000000,
        staff: [
            { identifier: 'ROV123', name: 'Rover Op', rank: 4, online: true, onDuty: true, isMe: true },
            { identifier: 'MIA555', name: 'Mia Tanaka', rank: 3, online: true, onDuty: true },
            { identifier: 'JAY777', name: 'Jay Park', rank: 1, online: false, onDuty: false },
        ],
        log: [
            { kind: 'sale', amount: 45, actor: 'Mia Tanaka', note: '2 kitty lattes', time: 1790000000 },
            { kind: 'order', amount: -240, actor: 'Rover Op', note: '20x Milk, 10x Coffee Beans', time: 1789990000 },
            { kind: 'hire', amount: 0, actor: 'Rover Op', note: 'Jay Park as Trainee', time: 1789980000 },
        ],
        catalog: [
            { item: 'coffee_beans', label: 'Coffee Beans', price: 40, pack: 10, image: 'vb_coffee_beans.png' },
            { item: 'milk', label: 'Milk', price: 20, pack: 10, image: 'vb_milk.png' },
            { item: 'honey', label: 'Honey', price: 25, pack: 10, image: 'vb_honey.png' },
            { item: 'strawberry', label: 'Strawberries', price: 25, pack: 10, image: 'vb_strawberry.png' },
        ],
    },
    cook: {
        stationId: 4, station: 'Coffee machine', business: 'Cat Café', maxQuantity: 10,
        counts: { coffee_beans: 6, milk: 2, honey: 0, cocoa: 3 },
        labels: { coffee_beans: 'Coffee Beans', milk: 'Milk', honey: 'Honey', cocoa: 'Cocoa Powder' },
        recipes: [
            { id: 'kitty_latte', label: 'Kitty Latte', time: 6000, amount: 1, image: 'vb_kitty_latte.png', ingredients: { coffee_beans: 1, milk: 1, honey: 1 } },
            { id: 'latte', label: 'Latte', time: 5000, amount: 1, image: 'vb_latte.png', ingredients: { coffee_beans: 1, milk: 1 } },
            { id: 'hot_chocolate', label: 'Hot Chocolate', time: 5000, amount: 1, image: 'vb_hot_chocolate.png', ingredients: { cocoa: 1, milk: 1 } },
        ],
    },
    register: { stationId: 5, maxBill: 50000, players: [{ id: 12, name: 'Sam Rivera' }, { id: 31, name: 'Ava Chen' }] },
    bill: { id: 9, business: 'Cat Café', from: 'Mia Tanaka', amount: 45, note: '2 kitty lattes', timeout: 60 },

    respond(endpoint, data) {
        if (endpoint === 'request' && data.action === 'home') return { ok: true, data: Preview.home };
        if (endpoint === 'request' && data.action === 'bossData') return { ok: true, data: Preview.boss };
        if (endpoint === 'request' && data.action === 'nearbyPlayers') return { ok: true, data: { players: Preview.register.players } };
        if (endpoint === 'request') return { ok: true, message: `(preview) ${data.action}` };
        return { ok: true };
    },

    start() {
        document.body.classList.add('is-preview');
        const page = (location.hash || '#home').slice(1);
        if (page === 'progress') return showProgress('Making 2x Kitty Latte', 12000);
        if (page === 'placement') return showPlacement({ business: 'Cat Café', kind: 'Coffee machine', index: 2, total: 9, pairing: true });
        open(PAGES[page] ? page : 'home', Preview[page] || Preview.home);
    },
};

if (!IS_GAME) {
    applyBrand({ Title: 'VANGUARD', Subtitle: 'BUSINESS', Accent: '#f59e0b' });
    Preview.start();
    window.addEventListener('hashchange', () => Preview.start());
}
