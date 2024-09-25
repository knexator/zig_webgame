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
    wasm_exports.colorCheckerboard(
        getDarkValue(),
        getDarkValue(),
        getDarkValue(),
        getLightValue(),
        getLightValue(),
        getLightValue()
    );

    const bufferOffset = wasm_exports.getCheckerboardBufferPointer();
    const imageDataArray = wasm_memory.slice(
        bufferOffset,
        bufferOffset + checkerboardSize * checkerboardSize * 4
    );
    console.log(bufferOffset);
    console.log(wasm_exports.memory);

    imageData.data.set(imageDataArray);

    context.clearRect(0, 0, canvas.width, canvas.height);
    context.putImageData(imageData, 0, 0);
};

drawCheckerboard();
