// Downloads the item pictures (Microsoft Fluent Emoji, MIT) named by `emoji` in shared/types.lua
// into images/vb_<item>.png. Usage: npm run images
'use strict';

const fs = require('fs');
const path = require('path');
const { ROOT, createState, run } = require('./lua');

const BASE = 'https://raw.githubusercontent.com/microsoft/fluentui-emoji/main/assets';

function emojiList() {
    const L = createState();
    run(L, 'Config = {}', 'config');
    run(L, `dofile(ROOT .. '/shared/types.lua')`, 'types');
    const lines = run(L, `
        local out = {}
        for _, list in ipairs({ Ingredients, Products }) do
            for id, item in pairs(list) do out[#out + 1] = item.image .. '\\t' .. item.emoji end
        end
        table.sort(out)
        return table.concat(out, '\\n')`, 'list');
    return lines.split('\n').map((line) => line.split('\t'));
}

async function main() {
    const folder = path.join(ROOT, 'images');
    fs.mkdirSync(folder, { recursive: true });
    let failed = 0;
    for (const [file, emoji] of emojiList()) {
        const slug = emoji.toLowerCase().replace(/ /g, '_');
        const url = `${BASE}/${encodeURIComponent(emoji)}/3D/${slug}_3d.png`;
        const response = await fetch(url);
        if (!response.ok) {
            failed += 1;
            console.error(`MISS ${file} (${emoji}): HTTP ${response.status}`);
            continue;
        }
        fs.writeFileSync(path.join(folder, file), Buffer.from(await response.arrayBuffer()));
        console.log(`ok   ${file}`);
    }
    process.exit(failed ? 1 : 0);
}

main();
