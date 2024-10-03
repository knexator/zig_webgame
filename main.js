const container = document.querySelector("#canvas_container");
const canvas = document.querySelector("#ctx_canvas");
const ctx = canvas.getContext("2d");

canvas.width = canvas.clientWidth;
canvas.height = canvas.clientHeight;

let TILE_SIZE = canvas.width / 16;

function fillTile(i, j, r, g, b) {
    ctx.fillStyle = rgbToHex(r,g,b);
    ctx.fillRect(i * TILE_SIZE, j * TILE_SIZE, TILE_SIZE, TILE_SIZE);
}

function fillTileWithCircle(i, j, r, g, b) {
    ctx.fillStyle = rgbToHex(r,g,b);
    ctx.beginPath();
    ctx.arc((i + .5) * TILE_SIZE, (j + .5) * TILE_SIZE, TILE_SIZE / 2, 0, 2 * Math.PI);
    ctx.fill();
}

const asdf = await WebAssembly.instantiateStreaming(fetch("zig-out/bin/webgame_v0.wasm"), {
    env: {
        consoleLog: (arg) => console.log(arg),
        fillTile_native: fillTile,
        fillTileWithCircle_native: fillTileWithCircle,
    }
});
const wasm_exports = asdf.instance.exports;
const wasm_memory = new Uint8Array(wasm_exports.memory.buffer);

document.addEventListener('resize', _ => {
    if (canvas.width !== canvas.clientWidth || canvas.height !== canvas.clientHeight) {
        canvas.width = canvas.clientWidth;
        canvas.height = canvas.clientHeight;
        TILE_SIZE = canvas.width / 16;
    }
});


let last_timestamp_millis = 0;
function every_frame(cur_timestamp_millis) {
    const delta_seconds = (cur_timestamp_millis - last_timestamp_millis) / 1000;
    last_timestamp_millis = cur_timestamp_millis;

    wasm_exports.frame(delta_seconds);
    wasm_exports.draw();

    requestAnimationFrame(every_frame);
}

requestAnimationFrame(every_frame);

document.addEventListener("keydown", ev => {
    if (ev.repeat) return;
    switch (ev.code) {
        case 'KeyW':
            wasm_exports.keydown(0);
            break;
        case 'KeyS':
            wasm_exports.keydown(1);
            break;
        case 'KeyA':
            wasm_exports.keydown(2);
            break;
        case 'KeyD':
            wasm_exports.keydown(3);
            break;
    
        default:
            break;
    }
});

function rgbToHex(r, g, b) {
    return "#" + [r, g, b].map(num => {
        const hex = num.toString(16);
        return hex.length === 1 ? "0" + hex : hex;
    }).join('');
}
