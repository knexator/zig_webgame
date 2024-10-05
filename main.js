const container = document.querySelector("#canvas_container");
const canvas = document.querySelector("#ctx_canvas");
const ctx = canvas.getContext("2d");

canvas.width = canvas.clientWidth;
canvas.height = canvas.clientHeight;

let TILE_SIZE = Math.round(canvas.width / 16);

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

function pathSnakeSegment(i, j, di_in, dj_in, di_out, dj_out) {
    if (di_in == -di_out && dj_in == -dj_out) {
        return pathTile(i, j);
    } else {
        return pathSnakeCorner(i, j, di_in, dj_in, di_out, dj_out);
    }
}

function pathTile(i, j) {
    let region = new Path2D();
    region.rect(i * TILE_SIZE, j * TILE_SIZE, TILE_SIZE, TILE_SIZE);
    return region;
}

function pathSnakeCorner(i, j, di_in, dj_in, di_out, dj_out) {
    let region = new Path2D();
    // region.beginPath();
    const cx = (i + .5) * TILE_SIZE;
    const cy = (j + .5) * TILE_SIZE;
    const dxA = di_in * TILE_SIZE / 2;
    const dyA = dj_in * TILE_SIZE / 2;
    const dxB = di_out * TILE_SIZE / 2;
    const dyB = dj_out * TILE_SIZE / 2;
    region.moveTo(cx - dxB, cy - dyB);
    region.lineTo(cx - dxB + dxA, cy - dyB + dyA);
    region.lineTo(cx + dxB + dxA, cy + dyB + dyA);
    region.lineTo(cx + dxB - dxA, cy + dyB - dyA);
    region.lineTo(cx - dxA, cy - dyA);
    region.arc(cx, cy, TILE_SIZE / 2, atan2(-dyA, -dxA), atan2(-dyB, -dxB), dxA * dyB - dyA * dxB < 0);
    region.closePath();
    return region;
}

function drawSnakeCorner(i, j, di_in, dj_in, di_out, dj_out, r, g, b) {
    ctx.fillStyle = rgbToHex(r,g,b);
    ctx.fill(pathSnakeCorner(i, j, di_in, dj_in, di_out, dj_out));
}

function drawSnakeScarf_first(t, i, j, di_in, dj_in, di_out, dj_out, r, g, b) {
    t = Math.max(t, .5); // hack
    ctx.save();
    ctx.clip(pathSnakeSegment(i, j, di_in, dj_in, di_out, dj_out));
    fillTile(i + di_in * (1-t), j + dj_in * (1-t), r, g, b);
    fillTile(i - di_out * (1-t), j - dj_out * (1-t), r, g, b);
    ctx.restore();
}

function drawSnakeScarf_last(t, i, j, di_in, dj_in, di_out, dj_out, r, g, b) {
    ctx.save();
    ctx.clip(pathSnakeSegment(i, j, di_in, dj_in, di_out, dj_out));
    fillTile(i + di_out * t, j + dj_out * t, r, g, b);
    ctx.restore();
}

// TODO: avoid corner
function drawSnakeHead(i, j, di_in, dj_in, r, g, b) {
    ctx.fillStyle = rgbToHex(r,g,b);
    ctx.beginPath();
    const cx = (i + .5) * TILE_SIZE;
    const cy = (j + .5) * TILE_SIZE;
    const dxA = di_in * TILE_SIZE / 2;
    const dyA = dj_in * TILE_SIZE / 2;
    const dxB = -dyA;
    const dyB = dxA;
    ctx.moveTo(cx - dxB, cy - dyB);
    ctx.lineTo(cx - dxB + dxA, cy - dyB + dyA);
    ctx.lineTo(cx + dxB + dxA, cy + dyB + dyA);
    ctx.lineTo(cx + dxB, cy + dyB);
    ctx.arc(cx, cy, TILE_SIZE / 2, atan2(-dyB, -dxB), atan2(dyB, dxB), true);
    ctx.closePath();
    ctx.fill();
}

function atan2(dy, dx) {
    if (dx > 0) return 0;
    if (dx < 0) return Math.PI;
    if (dy > 0) return Math.PI / 2;
    if (dy < 0) return -Math.PI / 2;
    return 0;
}

const asdf = await WebAssembly.instantiateStreaming(fetch("zig-out/bin/webgame_v0.wasm"), {
    env: {
        consoleLog: (arg) => console.log(arg),
        fillTile_native: fillTile,
        fillTile_float_native: fillTile,
        fillTileWithCircle_native: fillTileWithCircle,
        drawSnakeCorner_native: drawSnakeCorner,
        drawSnakeCorner_float_native: drawSnakeCorner,
        drawSnakeHead_native: drawSnakeHead,
        drawSnakeHead_float_native: drawSnakeHead,
        drawSnakeScarf_first_native: drawSnakeScarf_first,
        drawSnakeScarf_last_native: drawSnakeScarf_last,
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

    ctx.clearRect(0, 0, canvas.width, canvas.height);

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
