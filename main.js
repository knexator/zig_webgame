const container = document.querySelector("#canvas_container");
const canvas = document.querySelector("#ctx_canvas");
canvas.style.imageRendering = "pixelated";

const asdf = await WebAssembly.instantiateStreaming(fetch("zig-out/bin/webgame_v0.wasm"));
const wasm_exports = asdf.instance.exports;
const wasm_memory = new Uint8Array(wasm_exports.memory.buffer);

const screen_size = wasm_exports.getScreenSide();
canvas.width = screen_size;
canvas.height = screen_size;

document.addEventListener('resize', _ => {
    // We want to find the biggest scaling possible
    //  that is small enough to fit in the actual screen
    const SCALING_FACTOR = Math.min(
        Math.floor(container.clientWidth / canvas.width),
        Math.floor(container.clientHeight / canvas.height)
    );

    // Set the html canvas size using CSS
    canvas.style.width = `${canvas.width * SCALING_FACTOR}px`;
    canvas.style.height = `${canvas.height * SCALING_FACTOR}px`;
});

const ctx = canvas.getContext("2d");
const ctx_data = ctx.createImageData(canvas.width, canvas.height);

let last_timestamp_millis = 0;
function every_frame(cur_timestamp_millis) {
    const delta_seconds = (cur_timestamp_millis - last_timestamp_millis) / 1000;
    last_timestamp_millis = cur_timestamp_millis;

    wasm_exports.frame(delta_seconds);

    const buffer_offset = wasm_exports.draw();
    ctx_data.data.set(wasm_memory.slice(
        buffer_offset,
        buffer_offset + screen_size * screen_size * 4
    ));
    ctx.putImageData(ctx_data, 0, 0);

    requestAnimationFrame(every_frame);
}

requestAnimationFrame(every_frame);

document.addEventListener("keydown", ev => {
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
