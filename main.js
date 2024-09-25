const container = document.querySelector("#canvas_container");
const canvas = document.querySelector("#ctx_canvas");
canvas.style.imageRendering = "pixelated";

const asdf = await WebAssembly.instantiateStreaming(fetch("zig-out/bin/webgame_v0.wasm"));
const wasm_exports = asdf.instance.exports;
const wasm_memory = new Uint8Array(wasm_exports.memory.buffer);

// Automatically set canvas size as defined in `checkerboard.zig`
const checkerboardSize = wasm_exports.getCheckerboardSize();
canvas.width = checkerboardSize;
canvas.height = checkerboardSize;

// We want to find the biggest scaling possible
//  that is small enough to fit in the actual screen
const SCALING_FACTOR = Math.min(
    Math.floor(container.clientWidth / canvas.width),
    Math.floor(container.clientHeight / canvas.height)
);

// Set the html canvas size using CSS
canvas.style.width = `${canvas.width * SCALING_FACTOR}px`;
canvas.style.height = `${canvas.height * SCALING_FACTOR}px`;

const context = canvas.getContext("2d");
const imageData = context.createImageData(canvas.width, canvas.height);
context.clearRect(0, 0, canvas.width, canvas.height);

const getDarkValue = () => {
    return Math.floor(Math.random() * 100);
};
const getLightValue = () => {
    return Math.floor(Math.random() * 127) + 127;
};

const drawCheckerboard = () => {
    const buffer_offset = wasm_exports.colorCheckerboard(
        getDarkValue(),
        getDarkValue(),
        getDarkValue(),
        getLightValue(),
        getLightValue(),
        getLightValue()
    );

    const imageDataArray = wasm_memory.slice(
        buffer_offset,
        buffer_offset + checkerboardSize * checkerboardSize * 4
    );

    imageData.data.set(imageDataArray);

    context.clearRect(0, 0, canvas.width, canvas.height);
    context.putImageData(imageData, 0, 0);
};

drawCheckerboard();

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

    drawCheckerboard();
})
